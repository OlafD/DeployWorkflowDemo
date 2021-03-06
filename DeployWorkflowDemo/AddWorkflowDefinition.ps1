param (
	[Parameter(Mandatory=$true)]
	[string]$Url,
	[Parameter(Mandatory=$true)]
	[string]$WorkflowDefinitionFile,
	[Parameter(Mandatory=$true)]
	[string]$TaskList,
	[Parameter(Mandatory=$true)]
	[string]$HistoryList,
	$Credential
)

#------------------------------------------------------------------------------
#
# functions
#
#------------------------------------------------------------------------------

function EnsureTaskList() 
{
	param (
		[Parameter(Mandatory=$true)]
		[string]$ListName
	)

	$list = Get-SPOList | Where { $_.Title -eq $ListName }

	if ($list -eq $null)
	{
		$list = New-SPOList -Title $ListName -Template Tasks 

		Add-SPOContentTypeToList -List $ListName -ContentType "0x0108003365C4474CAE8C42BCE396314E88E51F"

		Write-Host -ForegroundColor Yellow "Tasklist $ListName created"

		$list = Get-SPOList | Where { $_.Title -eq $ListName }
	}

	return $list
}

function EnsureWorkflowHistoryList() 
{
	param (
		[Parameter(Mandatory=$true)]
		[string]$ListName
	)

	$list = Get-SPOList | Where { $_.Title -eq $ListName }

	if ($list -eq $null)
	{
		$list = New-SPOList -Title $ListName -Template WorkflowHistory

		Write-Host -ForegroundColor Yellow "Workflow History list $ListName created"

		$list = Get-SPOList | Where { $_.Title -eq $ListName }
	}

	return $list
}

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

	$newGuid = GetIdForList($Listname)

	$findString = "`"$oldGuid`""
	$newString = "`"$newGuid`""

	$result = $XamlDef.Replace($findString, $newString)

	return $result
}

function SetMetaInfoValue ()
{
	param (
		[string]$MetaInfo,
		[string]$Key,
		[string]$Value
	)

    $mi_new = ""
	$found = $false
	$searchKey = $Key + ":"

    $MetaInfo -split �`r`n� | ForEach-Object {
        if ( $_.StartsWith($searchKey) -eq $true)
        {
            $mi_new = $mi_new + "`r`n" + $searchKey + $Value

			$found = $true
        }
        else
        {
            $mi_new = $mi_new + "`r`n" + $_
        }
    }

    if ($mi_new.StartsWith("`r`n") -eq $true)
    {
        $mi_new.TrimStart("`r") | Out-Null
        $mi_new.TrimStart("`n") | Out-Null
    }

	if ($found -eq $false)
	{
        $mi_new = $mi_new + "`r`n" + $searchKey + $Value
	}

    return $mi_new
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

# get necessary objects
$workflowTaskList = EnsureTaskList $TaskList
$workflowHistoryList = EnsureWorkflowHistoryList $HistoryList
Write-Host "Got the workflow related lists"

# Prepare the Workflow Definition object
$wfDefinition = New-Object Microsoft.SharePoint.Client.WorkflowServices.WorkflowDefinition -ArgumentList $ctx
$wfDefinition.DisplayName = $displayName
$wfDefinition.Description = $description
$wfDefinition.Xaml = $xaml
$wfDefinition.FormField = $formField
$wfDefinition.RequiresInitiationForm = $requiresInitiationForm

$wfDefinition.SetProperty("TaskListId", "{" + $workflowTaskList.Id.ToString() + "}")
$wfDefinition.SetProperty("HistoryListId", "{" + $workflowHistoryList.Id.ToString() + "}")

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

# Save and publish the Workflow Definition object
$definitionId = $wfDeploymentService.SaveDefinition($wfDefinition)
$ctx.Load($wfDefinition)
$ctx.ExecuteQuery()
Write-Host "Workflow Definition written to web"

if ($false)
{
Start-Sleep 3

# update the properties and MetaInfo
$wfDefPnP = Get-SPOWorkflowDefinition -Name $displayName
$wfDefinition = $wfDeploymentService.GetDefinition([Guid]$wfDefPnP.Id)

$metaInfo = $wfDefinition.Properties["MetaInfo"]

$metaInfo = SetMetaInfoValue $metaInfo "TaskListId" "{" + $workflowTaskList.Id.ToString() + "}"
$metaInfo = SetMetaInfoValue $metaInfo "HistoryListId" "{" + $workflowHistoryList.Id.ToString() + "}"

#$wfDefinition.SetProperty("MetaInfo", $metaInfo)

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


$definitionId = $wfDeploymentService.SaveDefinition($wfDefinition)
$ctx.Load($wfDefinition)
$ctx.ExecuteQuery()
Write-Host "Workflow Definition updated in web"
}

# Publish the Workflow Definition
$wfDeploymentService.PublishDefinition($definitionId.Value)
$ctx.ExecuteQuery()
Write-Host "Workflow Definition published"
