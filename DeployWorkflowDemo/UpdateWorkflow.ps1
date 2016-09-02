param (
	[Parameter(Mandatory=$true)]
	$Url,
	[Parameter(Mandatory=$true)]
	$Cred
)

$currentPath = Split-Path -Parent $PSCommandPath
$workflowDefinition = "$currentPath\Copy to LibraryB.xml"

.\SetWorkflowDefinition -Url $Url -WorkflowDefinitionFile $workflowDefinition -Credential $Cred

.\SetWorkflowSubscription -Url $Url -WorkflowDefinitionFile $workflowDefinition -TargetList "LibraryA" -Credential $Cred
