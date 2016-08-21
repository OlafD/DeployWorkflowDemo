param (
	[Parameter(Mandatory=$true)]
	[string]$Url,
	[Parameter(Mandatory=$true)]
	[string]$WorkflowDefinitionName,
	[Parameter(Mandatory=$true)]
	[string]$DefinitionFile,
	$Cred
)

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

	$displayNameElement = $xml.CreateElement("DisplayName")
	$displayNameElement.InnerText = $workflowDefinition.DisplayName
	$xml.LastChild.AppendChild($displayNameElement)

	$descriptionElement = $xml.CreateElement("Description")
	$descriptionElement.InnerText = $workflowDefinition.Description
	$xml.LastChild.AppendChild($descriptionElement)

	$xamlElement = $xml.CreateElement("Xaml")
	$xamlElement.InnerXml = $workflowDefinition.Xaml
	$xml.LastChild.AppendChild($xamlElement)

	$formFieldElement = $xml.CreateElement("FormField")
	$formFieldElement.InnerXml = $workflowDefinition.FormField
	$xml.LastChild.AppendChild($formFieldElement)

	$requiresInitiationForm = $xml.CreateElement("RequiresInitiationForm")
	$requiresInitiationForm.InnerText = $workflowDefinition.RequiresInitiationForm
	$xml.LastChild.AppendChild($requiresInitiationForm)

	$eventTypes = $xml.CreateElement("EventTypes")

	foreach ($et in $workflowSubscription.EventTypes)
	{
		$eventType = $xml.CreateElement("EventType")
		$eventType.InnerText = $et

		$eventTypes.AppendChild($eventType)
	}

	$xml.LastChild.AppendChild($eventTypes)

	$xml.Save($DefinitionFile)

	Write-Host "Definition written to $DefinitionFile"
}

Write-Host "Done."
