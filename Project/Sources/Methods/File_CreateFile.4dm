//%attributes = {"invisible":true,"preemptive":"capable"}
// File_CreateFile
// 
// DESCRIPTION
//   A generic method to create a file and properly set the
//   creator types. By default the file is set as a text file.
//
#DECLARE($path_to_create_file_at : Text; $file_type : Text)->$doc_ref : Time
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259<=2)

If (Count parameters:C259<2)
	$file_type:=File_DeriveFileTypeFromName($path_to_create_file_at)
	If ($file_type="")
		$file_type:=(Is Windows:C1573) ? "TXT" : "TEXT"
	End if 
End if 

var $doc_actually_created : Text
$doc_ref:=Create document:C266($path_to_create_file_at; $file_type)
If (OK=1)
	$doc_actually_created:=Document
	CLOSE DOCUMENT:C267($doc_ref)
	
	// Make sure that the name we specified (if any) is the name of the created file
	If ($path_to_create_file_at#"") && ($path_to_create_file_at#$doc_actually_created)
		MOVE DOCUMENT:C540($doc_actually_created; $path_to_create_file_at)
		$doc_actually_created:=$path_to_create_file_at
	End if 
	
	$doc_ref:=Open document:C264($doc_actually_created)
Else 
	$doc_ref:=-1
End if 
