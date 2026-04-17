//%attributes = {"invisible":true,"preemptive":"capable"}
// File_Delete (path to file)
// File_Delete (text)
// 
// DESCRIPTION
//   Deletes the document pass to it.
//
#DECLARE($file_name : Text)
// ----------------------------------------------------

If (File_DoesExist($file_name))
	DELETE DOCUMENT:C159($file_name)
End if 
