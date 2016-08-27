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
$wfDefinition = $wfDeploymentService.GetDefinition($wfDefPnP.Id)

# Set new values in the Workflow Definition object
$wfDefinition.Description = $description
$wfDefinition.Xaml = $xaml
$wfDefinition.FormField = $formField
$wfDefinition.RequiresInitiationForm = $requiresInitiationForm
# we do not set task list or history list to new values

# Save and publish the Workflow Definition object
$definitionId = $wfDeploymentService.SaveDefinition($wfDefinition)
$ctx.Load($wfDefinition)
$ctx.ExecuteQuery()
Write-Host "Workflow Definition updated in web"

# Publish the Workflow Definition
$wfDeploymentService.PublishDefinition($definitionId.Value)
$ctx.ExecuteQuery()
Write-Host "Workflow Definition published"

