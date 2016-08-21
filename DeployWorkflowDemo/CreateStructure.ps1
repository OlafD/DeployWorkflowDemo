param (
    [string]$Url
)

Connect-SPOnline -Url $Url

Write-Host "Connected to $Url"

New-SPOList -Title "LibraryA" -Template DocumentLibrary

Add-SPOField -List "LibraryA" -InternalName "FieldA" -DisplayName "FieldA" -Type Text 
Add-SPOField -List "LibraryA" -InternalName "FieldB" -DisplayName "FieldB" -Type Text 

Write-Host "LibraryA created"

New-SPOList -Title "LibraryB" -Template DocumentLibrary

Add-SPOField -List "LibraryB" -InternalName "FieldA" -DisplayName "FieldA" -Type Text 
Add-SPOField -List "LibraryB" -InternalName "FieldC" -DisplayName "FieldC" -Type Text 

Write-Host "LibraryB created"
