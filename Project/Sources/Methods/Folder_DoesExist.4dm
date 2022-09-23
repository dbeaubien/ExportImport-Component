//%attributes = {"invisible":true,"preemptive":"capable"}
// Folder_DoesExist (path to folder) : doesExist
// 
// DESCRIPTION:
//   Returns true if the folder exists

C_TEXT:C284($1; $pathToFolder)
C_BOOLEAN:C305($0; $doesExist)

$doesExist:=False:C215
If (Asserted:C1132(Count parameters:C259=1))
	$pathToFolder:=$1
	
	If ($pathToFolder#"")
		$doesExist:=(Test path name:C476($pathToFolder)=Is a folder:K24:2)
	End if 
End if 
$0:=$doesExist