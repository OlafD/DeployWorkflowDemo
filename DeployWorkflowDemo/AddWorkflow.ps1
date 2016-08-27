param (
	$Url,
	$Cred
)

.\AddWorkflowDefinition -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -TaskList "Workflow Tasks" -HistoryList "Workflow History" -Credential $Cred

.\AddWorkflowSubscription -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -TargetList "LibraryA" -TaskList "Workflow Tasks" -HistoryList "Workflow History" -Credential $Cred
