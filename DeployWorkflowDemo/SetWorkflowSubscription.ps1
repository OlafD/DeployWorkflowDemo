param (
	[Parameter(Mandatory=$true)]
	[string]$Url,
	[Parameter(Mandatory=$true)]
	[string]$WorkflowDefinitionFile,
	[Parameter(Mandatory=$true)]
	[string]$TargetList,
	$Credential
)

#------------------------------------------------------------------------------
#
# functions
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#
# main
#
#------------------------------------------------------------------------------

# Load the Microsoft.SharePoint.Client.WorkflowServices.dll
Write-Host "Loading Microsoft.SharePoint.Client.WorkflowServices.dll"

$localAppData = Get-Item env:LOCALAPPDATA
$localAppDataPath = $localAppData.Value
$assemblyPath = $localAppDataPath + "\Apps\SharePointPnPPowerShellOnline\Modules\SharePointPnPPowerShellOnline\Microsoft.SharePoint.Client.WorkflowServices.dll"
$loadedAssembly = $null

Try
{
	$loadedAssembly = [System.Reflection.Assembly]::LoadFile($assemblyPath)
}
Catch
{
}

if ($loadedAssembly -ne $null)
{
	Write-Host "Loading done."
}
else
{
	Write-Host -ForegroundColor Red "Cannot load Microsoft.SharePoint.Client.WorkflowServices.dll"

	Return
}

# check and get credentials
if ($Credential -eq $null)
{
	$Credential = Get-Credential
}

# connect to the web in SharePoint Online
Connect-SPOnline -Url $Url -Credentials $Credential
Write-Host "Connected to web site $Url"

# Init context variables
$web = Get-SPOWeb
$ctx = $web.Context
Write-Host "Got the context variables"

# Load the workflow definition from xml
$xmlDoc = New-Object System.Xml.XmlDocument

$xmlDoc.Load($WorkflowDefinitionFile)

$displayNameNode = $xmlDoc.DocumentElement.SelectSingleNode("//DisplayName")
$displayName = $displayNameNode.InnerText

$descriptionNode = $xmlDoc.DocumentElement.SelectSingleNode("//Description")
$description = $descriptionNode.InnerText

$xamlNode = $xmlDoc.DocumentElement.SelectSingleNode("//Xaml")
$xaml = $xamlNode.InnerXml.ToString()

$formFieldNode = $xmlDoc.DocumentElement.SelectSingleNode("//FormField")
$formField = $formFieldNode.InnerXml.ToString()

$requiresInitiationFormNode = $xmlDoc.DocumentElement.SelectSingleNode("//RequiresInitiationForm")
if (($requiresInitiationFormNode).InnerText.ToUpper() -eq "TRUE")
{
	$requiresInitiationForm = $true
}
else
{
	$requiresInitiationForm = $false
}

$eventTypes = $xmlDoc.DocumentElement.SelectSingleNode("//EventTypes")
$eventTypesValue = New-Object System.Collections.Generic.List[String]

foreach ($node in $eventTypes)
{
    $eventTypesValue.Add($node.InnerText)
}

Write-Host "Got the content of the workflow definition file"

# get necessary objects
$eventSourceList = Get-SPOList | Where { $_.Title -eq $TargetList }

if ($eventSourceList -eq $null)
{
	Write-Host -ForegroundColor Red "The target list $TargetList does not exist."

	break
}

Write-Host "Got the workflow related lists"

# do the work
$wfDefinition = Get-SPOWorkflowDefinition -Name $displayName

if ($wfDefinition -eq $null)
{
	Write-Host -ForegroundColor Red "The workflow definition $displayName does not exist."
}
else
{
	Write-Host "Workflow Definition $displayName found in the web site"

	$wfSubPnP = Get-SPOWorkflowSubscription -Name $displayName

	# Create a WorkflowServicesManager instance
	$wfm = New-Object Microsoft.SharePoint.Client.WorkflowServices.WorkflowServicesManager -ArgumentList $ctx,$web

	# Associate the Workflow Definition to a target list/library
	$wfSubscriptionService = $wfm.GetWorkflowSubscriptionService()

	$wfSubscription = $wfSubscriptionService.GetSubscription($wfSubPnP.Id)

	if ($wfSubscription -eq $null)
	{
		Write-Host -ForegroundColor Red "Cannot find a workflow subscription named $displayName for list $eventSourceList"
	}
	else
	{
		# Configure the Workflow Subscription
		$wfSubscription.DefinitionId = $wfDefinition.Id
		$wfSubscription.Name = $wfDefinition.DisplayName
	
		$wfSubscription.Enabled = $true
		$wfSubscription.EventTypes = $eventTypesValue

		$wfSubscription.EventSourceId = $eventSourceList.Id.ToString()

		# Publish the Workflow Subscription
		$wfSubscriptionService.PublishSubscriptionForList($wfSubscription, $eventSourceList.Id)
		$ctx.ExecuteQuery()
		Write-Host "Workflow Subscription published"
	}
}
