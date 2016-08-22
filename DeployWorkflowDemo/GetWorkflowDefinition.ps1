param (
	[Parameter(Mandatory=$true)]
	[string]$Url,
	[Parameter(Mandatory=$true)]
	[string]$WorkflowDefinitionName,
	[Parameter(Mandatory=$true)]
	[string]$DefinitionFile,
	$Cred
)

#------------------------------------------------------------------------------
#
# functions
#
#------------------------------------------------------------------------------

function GetListFromId ()
{
	param (
		[string]$id
	)

	$result = ""

	$list = Get-SPOList -Identity $id

	if ($list -ne $null)
	{
		$result = $list.Title
	}

	return $result
}

#------------------------------------------------------------------------------
#
# main
#
#------------------------------------------------------------------------------

Connect-SPOnline -Url $Url -Credentials $Cred

$workflowDefinition = Get-SPOWorkflowDefinition -Name $WorkflowDefinitionName
$workflowSubscription = Get-SPOWorkflowSubscription -Name $WorkflowDefinitionName

if ($workflowDefinition -eq $null -or $workflowSubscription -eq $null)
{
	Write-Host -ForegroundColor Red "Cannot find workflow definition $WorkflowDefinitionName"
}
else
{
	$xml = New-Object System.Xml.XmlDocument
	$xml.LoadXml("<?xml version=`"1.0`" encoding=`"utf-8`"?><WorkflowDefinition></WorkflowDefinition>")

	# display name
	$displayNameElement = $xml.CreateElement("DisplayName")
	$displayNameElement.InnerText = $workflowDefinition.DisplayName
	$xml.LastChild.AppendChild($displayNameElement)

	# description
	$descriptionElement = $xml.CreateElement("Description")
	$descriptionElement.InnerText = $workflowDefinition.Description
	$xml.LastChild.AppendChild($descriptionElement)

	# xaml
	$xamlElement = $xml.CreateElement("Xaml")
	$xamlElement.InnerXml = $workflowDefinition.Xaml
	$xml.LastChild.AppendChild($xamlElement)

	# initiation form fields and flag
	$formFieldElement = $xml.CreateElement("FormField")
	$formFieldElement.InnerXml = $workflowDefinition.FormField
	$xml.LastChild.AppendChild($formFieldElement)

	$requiresInitiationForm = $xml.CreateElement("RequiresInitiationForm")
	$requiresInitiationForm.InnerText = $workflowDefinition.RequiresInitiationForm
	$xml.LastChild.AppendChild($requiresInitiationForm)

	# event types
	$eventTypes = $xml.CreateElement("EventTypes")

	foreach ($et in $workflowSubscription.EventTypes)
	{
		$eventType = $xml.CreateElement("EventType")
		$eventType.InnerText = $et

		$eventTypes.AppendChild($eventType)
	}

	$xml.LastChild.AppendChild($eventTypes)

	# used resources
	$usedResourcesElement = $xml.CreateElement("UsedResources")

	$guidList = New-Object System.Collections.Hashtable

	# not the best solution: find all "real" guids in the xaml of the workflow
	$mi = Select-String -InputObject $workflowDefinition.Xaml -Pattern '(\"){1}(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}(\"){1}' -AllMatches

	for ($i=0; $i -lt $mi.Matches.Count; $i++)
	{
	    [string]$guid = $mi.Matches[$i].Value

		$guid = $guid.Replace("`"", "")

		if ($guidList.ContainsKey($guid) -eq $false)
		{
			$usedResourceElement = $xml.CreateElement("UsedResource")

			$idAttribute = $xml.CreateAttribute("Id")
			$idAttribute.Value = $guid
			$usedResourceElement.Attributes.Append($idAttribute)

			$listTitle = GetListFromId $guid

			$idListTitle = $xml.CreateAttribute("Title")
			$idListTitle.Value = $listTitle
			$usedResourceElement.Attributes.Append($idListTitle)
		
			$usedResourcesElement.AppendChild($usedResourceElement)

			$guidList.Add($guid, $listTitle)
		}
	}

	$xml.LastChild.AppendChild($usedResourcesElement)

	# write file to the file system
	$xml.Save($DefinitionFile)

	Write-Host "Definition written to $DefinitionFile"
}

Write-Host "Done."
