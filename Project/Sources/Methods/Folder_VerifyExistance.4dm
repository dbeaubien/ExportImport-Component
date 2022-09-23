//%attributes = {"invisible":true,"preemptive":"capable"}
// Folder_VerifyExistance (path to folder)
// 
// DESCRIPTION:
//   Creates a folder if it does not exist. If necessary, it will
//   recursively create the parent folders as well.

C_TEXT:C284($1; $pathToFolder)

If (Asserted:C1132(Count parameters:C259=1))
	$pathToFolder:=$1
	
	If ($pathToFolder#"")
		If (Not:C34(Folder_DoesExist($pathToFolder)))
			CREATE FOLDER:C475($pathToFolder; *)
		End if 
	End if 
End if 
