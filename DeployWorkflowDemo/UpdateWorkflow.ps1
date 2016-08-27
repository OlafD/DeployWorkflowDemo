param (
	$Url,
	$Cred
)

.\SetWorkflowDefinition -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -Credential $Cred

.\SetWorkflowSubscription -Url $Url -WorkflowDefinitionFile "C:\Temp\Copy to LibraryB.xml" -TargetList "LibraryA" -Credential $Cred
