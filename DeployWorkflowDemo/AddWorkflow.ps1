param (
	[Parameter(Mandatory=$true)]
	[string]$Url,
	[Parameter(Mandatory=$true)]
	$Cred
)

$currentPath = Split-Path -Parent $PSCommandPath
$workflowDefinition = "$currentPath\Copy to LibraryB.xml"

.\AddWorkflowDefinition.ps1 -Url $Url -WorkflowDefinitionFile $workflowDefinition -TaskList "Workflow Tasks" -HistoryList "Workflow History" -Credential $Cred

.\AddWorkflowSubscription.ps1 -Url $Url -WorkflowDefinitionFile $workflowDefinition -TargetList "LibraryA" -TaskList "Workflow Tasks" -HistoryList "Workflow History" -Credential $Cred

.\SetWorkflowDefinition.ps1 -Url $Url -WorkflowDefinitionFile $workflowDefinition -Credential $Cred

.\SetWorkflowSubscription.ps1 -Url $Url -WorkflowDefinitionFile $workflowDefinition -TargetList "LibraryA" -Credential $Cred
