//%attributes = {"invisible":true,"preemptive":"capable"}
// Folder_ParentName (folderPath) : parentFolderPath
//
// DESCRIPTION
//   Returns the Parent Name of the file pathname we pass in

C_TEXT:C284($1; $folderPath)
C_TEXT:C284($0; $parentFolderPath)
$parentFolderPath:=""
If (Asserted:C1132(Count parameters:C259=1))
	$folderPath:=$1
	
	If ($folderPath=("@"+Folder separator:K24:12))
		$folderPath:=Substring:C12($folderPath; 1; Length:C16($folderPath)-1)
	End if 
	
	C_COLLECTION:C1488($pathParts)
	$pathParts:=Split string:C1554($folderPath; Folder separator:K24:12)
	
	C_TEXT:C284($ignored)
	$ignored:=$pathParts.pop()
	
	$parentFolderPath:=$pathParts.join(Folder separator:K24:12)
	If ($parentFolderPath#"")
		$parentFolderPath:=$parentFolderPath+Folder separator:K24:12
	End if 
	
End if 
$0:=$parentFolderPath