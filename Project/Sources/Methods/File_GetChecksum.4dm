//%attributes = {"invisible":true,"preemptive":"capable"}
// File_GetChecksum (filePath; hashAlgorithm) : checksum
// File_GetChecksum (text; text) : text
// 
// DESCRIPTION
//   This method returns the checksum for a file.
//   Supported hash algorithms of "mdf5" or "sha1",
//    everything else resolves to "md5"
//   NOTE: The file is loaded into memory.
//
#DECLARE($file_path : Text; $hash_algorithm : Text)->$checksum : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

If (Not:C34(File_DoesExist($file_path)))
	return 
End if 

OnErr_Install_Handler("OnErr_GENERIC")

var $first_blob : Blob
var $doc_ref : Time
$doc_ref:=Open document:C264($file_path; "*"; Read mode:K24:5)
If (OK=1)  // If a document is selected
	DOCUMENT TO BLOB:C525(Document; $first_blob)  // Load document
	If (OK=1)
		Case of 
			: ($hash_algorithm="md5")
				$checksum:=Generate digest:C1147($first_blob; MD5 digest:K66:1)
			: ($hash_algorithm="sha1")
				$checksum:=Generate digest:C1147($first_blob; SHA1 digest:K66:2)
			Else 
				$checksum:=Generate digest:C1147($first_blob; MD5 digest:K66:1)
		End case 
	End if 
	
	CLOSE DOCUMENT:C267($doc_ref)
End if 
SET BLOB SIZE:C606($first_blob; 0)

OnErr_Install_Handler
