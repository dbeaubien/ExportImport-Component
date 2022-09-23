//%attributes = {"invisible":true,"preemptive":"capable"}
// Export_OneTable (tableNo; folderToExportTo ; next_table_sequence_number) : errMsg
// 
// DESCRIPTION
//   Exports a single table to disk as an XML file.
//
#DECLARE($table_no : Integer\
; $exportToFolder_platformPath : Text\
; $next_table_sequence_number : Integer\
; $progHdl : Integer)->$result : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=4)
$result:=""

var ExportImport_Stop : Boolean
Case of 
	: (Not:C34(Is table number valid:C999($table_no)))  // bad table?
	: (Records in table:C83(Table:C252($table_no)->)=0)  // no records?
	Else 
		
		var $MaxExportSize : Integer
		$MaxExportSize:=250*1024*1024  // 250MB- used to segment created XML files
		//$MaxExportSize:=1*1024*1024  // 1MB - used to segment created XML files
		
		var $segment : Integer
		$segment:=1
		
		var $table_ptr : Pointer
		var $num_records_in_table : Integer
		var $table_was_in_read_write : Boolean
		$table_ptr:=Table:C252($table_no)
		$table_was_in_read_write:=Read only state:C362($table_ptr->)
		READ ONLY:C145($table_ptr->)
		ALL RECORDS:C47($table_ptr->)
		$num_records_in_table:=Records in selection:C76($table_ptr->)
		
		var $table_name : Text
		$table_name:=Table name:C256($table_no)
		$table_name:=Replace string:C233($table_name; " "; "_")
		
		var $exportFile_platformPath : Text
		If ($exportToFolder_platformPath#("@"+Folder separator:K24:12))
			$exportToFolder_platformPath:=$exportToFolder_platformPath+Folder separator:K24:12
		End if 
		Folder_VerifyExistance($exportToFolder_platformPath)
		$exportFile_platformPath:=$exportToFolder_platformPath+$table_name+".xml"
		File_Delete($exportFile_platformPath)
		
		var $fileRef : Time
		$fileRef:=Create document:C266($exportFile_platformPath)
		SAX SET XML DECLARATION:C858($fileRef; "UTF-8"; True:C214)
		
		// Output table parameters
		var $value1; $value2 : Text
		$value1:=String:C10($next_table_sequence_number)
		$value2:=String:C10($num_records_in_table)
		If ($value1="")
			$value1:="0"
		End if 
		Log_INFO("$table_name="+$table_name)
		SAX OPEN XML ELEMENT:C853($fileRef; "Table_"+$table_name\
			; "Sequenceno"; $value1\
			; "Total"; $value2)
		
		
		var $i; $j; $ms : Integer
		Progress_Set_Title_ALT($progHdl; "Exporting ["+Table name:C256($table_no)+"] records...")
		For ($i; 1; $num_records_in_table)  // for every record in the table
			If ($ms<Milliseconds:C459)
				Progress_Set_Progress_ALT($progHdl; $i/$num_records_in_table; "exported "+String:C10($i; "###,###,###,##0")+" of "+String:C10($num_records_in_table; "###,###,###,##0"))
				$ms:=Milliseconds:C459+300  // next update
			End if 
			
			If (($i%100)=1)  // check to see if it is time to create a new segment
				If (Get document position:C481($fileRef)>$MaxExportSize)
					$segment:=$segment+1
					CLOSE DOCUMENT:C267($fileRef)
					
					$exportFile_platformPath:=$exportToFolder_platformPath+$table_name+"-"+String:C10($segment)+".xml"
					File_Delete($exportFile_platformPath)
					
					$fileRef:=Create document:C266($exportFile_platformPath)
					SAX SET XML DECLARATION:C858($fileRef; "UTF-8"; True:C214)
					SAX OPEN XML ELEMENT:C853($fileRef; "Table_"+$table_name; "Total"; String:C10(Records in table:C83($table_ptr->)))
				End if 
			End if 
			
			// now loop through all fields
			C_TEXT:C284($result2)
			C_POINTER:C301($fieldptr)
			SAX OPEN XML ELEMENT:C853($fileRef; "T_"+$table_name)
			For ($j; 1; Get last field number:C255($table_ptr))  // for every field on the record
				If (Is field number valid:C1000($table_no; $j))
					$fieldptr:=Field:C253($table_no; $j)
					$result2:=ExportImport_ExportField("ExportField"; ""; $fieldptr; $fileRef+0)
					If ($result2#"")
						ExportImport_Stop:=True:C214
						$result:=$result2
					End if 
					If (ExportImport_Stop)
						$j:=Get last field number:C255($table_ptr)+1
					End if 
				End if 
			End for 
			SAX CLOSE XML ELEMENT:C854($fileRef)
			
			If (Process aborted:C672)
				ExportImport_Stop:=True:C214
			End if 
			If (ExportImport_Stop)
				$i:=$num_records_in_table+1
			End if 
			NEXT RECORD:C51($table_ptr->)
		End for 
		
		SAX CLOSE XML ELEMENT:C854($fileRef)
		REDUCE SELECTION:C351($table_ptr->; 0)
		
		CLOSE DOCUMENT:C267($fileRef)
		
		If (Not:C34($table_was_in_read_write))
			READ WRITE:C146($table_ptr->)
		End if 
End case 


