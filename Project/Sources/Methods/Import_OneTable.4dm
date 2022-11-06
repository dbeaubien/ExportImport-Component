//%attributes = {"invisible":true,"preemptive":"capable"}
// Import_OneTable (tableNo; folderToExportTo ; next_table_sequence_number) : errMsg
// 
// DESCRIPTION
//   Exports a single table to disk as an XML file.
//
#DECLARE($table_no : Integer\
; $importFromFolder_platformPath : Text\
; $progHdl : Integer)->$result : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=3)
$result:=""

var ExportImport_Stop : Boolean

C_BLOB:C604($blob)
C_TIME:C306($ref)
C_TEXT:C284($result2; $value)
C_LONGINT:C283($xmllevel; $newseqnumber; $findpos; $total; $reccounter)
C_LONGINT:C283($loopfields; $fieldtyp; $MyEvent)
C_POINTER:C301($fieldptr)
C_PICTURE:C286($pictvariable)
var $textVariable : Text

var $import_file_list : Collection
If (Is table number valid:C999($table_no))  // Work out the files that are there to import
	var $segment_file_number : Integer
	var $table_filename_root; $table_filename : Text
	$table_filename_root:=Replace string:C233(Table name:C256($table_no); " "; "_")
	$table_filename:=$table_filename_root+".xml"
	$import_file_list:=New collection:C1472()
	$segment_file_number:=1
	While (File_DoesExist($importFromFolder_platformPath+$table_filename))
		$import_file_list.push($importFromFolder_platformPath+$table_filename)
		$segment_file_number:=$segment_file_number+1
		$table_filename:=$table_filename_root+"-"+String:C10($segment_file_number)+".xml"
	End while 
End if 

If ($import_file_list.length>0)
	TRUNCATE TABLE:C1051(Table:C252($table_no)->)
End if 

If ($import_file_list.length>0)
	var $field_no : Integer
	ARRAY TEXT:C222($cleansed_fieldNames; Get last field number:C255($table_no))
	For ($field_no; 1; Get last field number:C255($table_no))
		$cleansed_fieldNames{$field_no}:=ExportImport_ReplaceChar("ReplaceChar"; Field name:C257($table_no; $field_no); Field:C253($table_no; $field_no); 1)
	End for 
End if 

If ($import_file_list.length>0)
	var $ms; $file_no : Integer
	var $file_to_import_platformPath : Text
	For each ($file_to_import_platformPath; $import_file_list)
		$file_no:=$file_no+1
		DELAY PROCESS:C323(Current process:C322; 60)  // give time for the progress bar to display
		Progress_Set_Title_ALT($progHdl; "Importing ["+Table name:C256($table_no)+"] records from file #"+String:C10($file_no)+"...")
		
		$ref:=Open document:C264($file_to_import_platformPath; "TEXT"; Read mode:K24:5)
		Repeat 
			$MyEvent:=SAX Get XML node:C860($ref)
			Case of 
				: ($MyEvent=XML start document:K45:7)
					// nothing?
					
				: ($MyEvent=XML start element:K45:10)
					ARRAY TEXT:C222($attrName; 0)
					ARRAY TEXT:C222($attrvalue; 0)
					var $vPrefix; $vName : Text
					SAX GET XML ELEMENT:C876($ref; $vName; $vPrefix; $attrName; $attrvalue)
					Case of 
						: ($xmllevel=0)  // start of XML file, main level
							If ($vName#("table_"+$table_filename_root))
								$result:="Wrong main content "+$vName+" - Table_"+$table_filename_root
								ExportImport_Stop:=True:C214
							Else 
								$xmllevel:=1
								$NewSeqNumber:=0
								$findpos:=Find in array:C230($attrName; "Sequenceno")
								If ($findpos>0)
									$NewSeqNumber:=Num:C11($attrvalue{$findpos})
								End if 
								$findpos:=Find in array:C230($attrName; "Total")
								If ($findpos>0)
									$total:=Num:C11($attrvalue{$findpos})
								End if 
							End if 
							
						: ($xmllevel=1)  // start of new record, check table name
							If ($vName#("T_"+$table_filename_root))
								$result:="Wrong table name "+$vName+" T_"+$table_filename_root
								ExportImport_Stop:=True:C214
							Else 
								$xmllevel:=2
								CREATE RECORD:C68(Table:C252($table_no)->)
								$Reccounter:=$Reccounter+1
								
								If ($ms<Milliseconds:C459)
									Progress_Set_Progress_ALT($progHdl; $Reccounter/$total; "imported "+String:C10($Reccounter; "###,###,###,##0")+" of "+String:C10($total; "###,###,###,##0"))
									$ms:=Milliseconds:C459+300  // next update
								End if 
							End if 
							
						: ($xmllevel>=2)  // subtable?
							$xmllevel:=$xmllevel+1
					End case   // $MyEvent=XML Start Element 
					
				: ($MyEvent=XML CDATA:K45:13)
					If ($xmllevel=3)
						$loopfields:=Find in array:C230($cleansed_fieldNames; $vName)
						If ($loopfields>0)
							SAX GET XML CDATA:C878($ref; $blob)
							If (OK=1)
								BASE64 DECODE:C896($blob)
								$fieldptr:=Field:C253($table_no; $loopfields)
								$Fieldtyp:=Type:C295($fieldptr->)
								Case of 
									: ($Fieldtyp=Is alpha field:K8:1) | ($Fieldtyp=Is text:K8:3)
										BLOB TO VARIABLE:C533($blob; $textVariable)
										$fieldptr->:=$textVariable
									: ($Fieldtyp=Is BLOB:K8:12)
										$fieldptr->:=$blob
										SET BLOB SIZE:C606($blob; 0)
									: ($Fieldtyp=Is picture:K8:10)
										BLOB TO VARIABLE:C533($blob; $pictVariable)
										SET BLOB SIZE:C606($blob; 0)  // to free up memory
										$fieldptr->:=$pictVariable
								End case 
							End if 
						End if 
					End if 
					
				: ($MyEvent=XML DATA:K45:12)
					Case of 
						: ($xmllevel=3)
							// Name of element is already in $vName
							$loopfields:=Find in array:C230($cleansed_fieldNames; $vName)
							If ($loopfields>0)
								// known field, get field value and assign
								$result2:=ExportImport_ImportField("ImportField"; $value; Field:C253($table_no; $loopfields); $ref+0)
								If ($result2#"")
									ExportImport_Stop:=True:C214
									$result:=$result2
								End if 
							End if 
							
						: ($xmllevel=4)  // subtable
							// NOP
					End case 
					
				: ($MyEvent=XML end element:K45:11)
					$xmllevel:=$xmllevel-1
					Case of 
						: ($xmllevel=1)
							SAVE RECORD:C53(Table:C252($table_no)->)
						: ($xmllevel=0)  // table ready
							If ($NewSeqNumber#0)
								CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_SetDatabaseParameter"; $table_no; $NewSeqNumber)
							End if 
					End case 
			End case 
			If (Process aborted:C672)
				ExportImport_Stop:=True:C214
			End if 
		Until (($MyEvent=XML end document:K45:15) | (ExportImport_Stop))
		
		CLOSE DOCUMENT:C267($ref)
		
	End for each 
	
	If ($result#"")
		ALERT:C41($result)
		Log_INFO($result)
	End if 
End if 