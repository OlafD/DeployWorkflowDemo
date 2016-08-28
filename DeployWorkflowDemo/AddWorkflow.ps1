param (
	$Url,
	$Cred
)

.\AddWorkflowDefinition.ps1 -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -TaskList "Workflow Tasks" -HistoryList "Workflow History" -Credential $Cred

.\AddWorkflowSubscription.ps1 -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -TargetList "LibraryA" -TaskList "Workflow Tasks" -HistoryList "Workflow History" -Credential $Cred

.\SetWorkflowDefinition.ps1 -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -Credential $Cred

.\SetWorkflowSubscription.ps1 -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -TargetList "LibraryA" -Credential $Cred
