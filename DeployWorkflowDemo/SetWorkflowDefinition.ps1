param (
	[Parameter(Mandatory=$true)]
	[string]$Url,
	[Parameter(Mandatory=$true)]
	[string]$WorkflowDefinitionFile,
	$Credential
)

#------------------------------------------------------------------------------
#
# functions
#
#------------------------------------------------------------------------------

function GetIdForList()
{
	param (
		[Parameter(Mandatory=$true)]
		[string]$ListName
	)

	$result = ""

	$list = Get-SPOList | Where { $_.Title -eq $ListName }

	if ($list -ne $null)
	{
		$result = $list.Id
	}

	return $result
}

function PatchXaml()
{
	param (
		[string]$XamlDef,
		[string]$oldGuid,
		[string]$Listname
	)

	$result = $XamlDef

	$newGuid = GetIdForList($Listname)

	if ($newGuid -eq "")
	{
		Write-Host -ForegroundColor Red "The list $Listname does not exist"
	}
	else
	{
		$findString = "`"$oldGuid`""
		$newString = "`"$newGuid`""

		$result = $XamlDef.Replace($findString, $newString)
	}

	return $result
}

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

# Create a WorkflowServicesManager instance
$wfm = New-Object Microsoft.SharePoint.Client.WorkflowServices.WorkflowServicesManager -ArgumentList $ctx,$web

# Get a reference to the Workflow Deployment Service
$wfDeploymentService = $wfm.GetWorkflowDeploymentService()

Write-Host "Connected to the WorkflowServices"

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

$usedResources = $xmlDoc.DocumentElement.SelectSingleNode("//UsedResources")

foreach ($node in $usedResources.ChildNodes)
{
	$guid = $node.Attributes["Id"].Value
	$listName = $node.Attributes["Title"].Value

	$xaml = PatchXaml $xaml $guid $listName
}

Write-Host "Got the content of the workflow definition file"

$wfDefPnP = Get-SPOWorkflowDefinition -Name $displayName
$definitionId = [Guid]$wfDefPnP.Id
$wfDefinition = $wfDeploymentService.GetDefinition($definitionId)

# Set new values in the Workflow Definition object
$wfDefinition.Description = $description
$wfDefinition.Xaml = $xaml
$wfDefinition.FormField = $formField
$wfDefinition.RequiresInitiationForm = $requiresInitiationForm
# we do not set task list or history list to new values

$wfDefinition.SetProperty("AutosetStatusToStageName", "true")
$wfDefinition.SetProperty("IsProjectMode", "false")
$wfDefinition.SetProperty("isReusable", "false")
$wfDefinition.SetProperty("SPDConfig.LastEditMode", "TextBased")

# WorkflowStart => SPDConfig.StartManually:SW|true
if ($eventTypesValue.Contains("WorkflowStart") -eq $true)
{
	$wfDefinition.SetProperty("SPDConfig.StartManually", "true")
}
else
{
	$wfDefinition.SetProperty("SPDConfig.StartManually", "false")
}

# ItemAdded => SPDConfig.StartOnCreate:SW|false
if ($eventTypesValue.Contains("ItemAdded") -eq $true)
{
	$wfDefinition.SetProperty("SPDConfig.StartOnCreate", "true")
}
else
{
	$wfDefinition.SetProperty("SPDConfig.StartOnCreate", "false")
}

# ItemUpdated => SPDConfig.StartOnChange:SW|false
if ($eventTypesValue.Contains("ItemUpdated") -eq $true)
{
	$wfDefinition.SetProperty("SPDConfig.StartOnChange", "true")
}
else
{
	$wfDefinition.SetProperty("SPDConfig.StartOnChange", "false")
}

$subscription = Get-SPOWorkflowSubscription -Name $displayName

if ($subscription -ne $null)
{
	$wfDefinition.SetProperty("RestrictToScope", $subscription.EventSourceId)
	$wfDefinition.SetProperty("RestrictToType", "List")

	$wfDefinition.SetProperty("SubscriptionId", $subscription.Id)
	$wfDefinition.SetProperty("SubscriptionName", $displayName)

	Write-Host "Subscription information added to workflow definition"
}

# Save and publish the Workflow Definition object
$definitionId = $wfDeploymentService.SaveDefinition($wfDefinition)
$ctx.Load($wfDefinition)
$ctx.ExecuteQuery()
Write-Host "Workflow Definition updated in web"

# Publish the Workflow Definition
$wfDeploymentService.PublishDefinition($definitionId.Value)
$ctx.ExecuteQuery()
Write-Host "Workflow Definition published"

