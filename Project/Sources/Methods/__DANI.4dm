//%attributes = {}
// Export_Import_Dialog
Progress QUIT(0)

// IMPORT
If (True:C214)
	
	var $importFromFolder_platformPath : Text
	$importFromFolder_platformPath:=Select folder:C670("Select Folder that contains 'Data' Export folder"; 1234)
	If (OK#1)
		return 
	End if 
	
	var $source_folder : 4D:C1709.Folder
	$source_folder:=Folder:C1567($importFromFolder_platformPath; fk platform path:K87:2)\
		.folder("Data")
	If (Not:C34($source_folder.exists))
		ALERT:C41("ABORTING. Cannot find the 'Data' subfolder.")
		return 
	End if 
	
	var $table_no : Integer
	var $mapping_file : 4D:C1709.File
	$table_no:=Table:C252(->[Table_2:2])
	$mapping_file:=$source_folder.file(Table name:C256($table_no)+" - field_mapping.json")
	If (Not:C34($mapping_file.exists))
		ALERT:C41("ABORTING. Cannot find the '"+Table name:C256($table_no)+" - field_mapping.json' file.")
		return 
	End if 
	
	var $source_file_list : Collection
	$source_file_list:=$source_folder\
		.files()\
		.query("fullName=:1"; Table name:C256($table_no)+" - table export@.json")\
		.orderBy("fullName")
	
	var $progress_dialog_id : Integer
	$progress_dialog_id:=Progress New()
	
	cs:C1710.Table_Importer\
		.new($table_no; $mapping_file; $source_file_list)\
		.Use_Progress_Dialog($progress_dialog_id)\
		.Truncate_Before_Import()\
		.Import_Records()
	
	var $num_records_in_table : Integer
	Case of 
		: ($num_records_in_table>100000)
			$records_per_block:=1000
		: ($num_records_in_table>10000)
			$records_per_block:=100
		Else 
			$records_per_block:=10
	End case 
	
	var $pathToChecksumFile : Text
	var $primaryKey_FieldPtr : Pointer
	$primaryKey_FieldPtr:=Table_GetUniqueFieldPtr(Table:C252($table_no))
	$pathToChecksumFile:=Table_GenerateChecksumFile($primaryKey_FieldPtr\
		; $records_per_block\
		; Folder:C1567($importFromFolder_platformPath; fk platform path:K87:2).folder("MD5 - after import").platformPath\
		; $progress_dialog_id)
	
	Progress QUIT($progress_dialog_id)
	
End if 


// EXPORT
If (False:C215)
	var $target_folder : 4D:C1709.Folder
	$target_folder:=cs:C1710._Utils.new().Get_Named_Working_Folder("Table Export")
	
	var $exporter : cs:C1710.Table_Exporter
	$exporter:=cs:C1710.Table_Exporter.new($target_folder.folder("Data"))
	$exporter.Set_File_Max_MB_Size(10)
	
	var $progress_dialog_id : Integer
	var $manifest : Object
	$progress_dialog_id:=Progress New()
	$manifest:={exports: []}
	$manifest.exports.push($exporter.Export_All_Records(Table:C252(->[Table_1:1]); $progress_dialog_id))
	$manifest.exports.push($exporter.Export_All_Records(Table:C252(->[Table_2:2]); $progress_dialog_id))
	Progress QUIT($progress_dialog_id)
	TEXT TO DOCUMENT:C1237($target_folder.file("Export Manifest.json").platformPath; JSON Stringify:C1217($manifest; *); "utf-8")
	SHOW ON DISK:C922($target_folder.platformPath)
End if 


BEEP:C151
ABORT:C156

// TODO: things to do
/*
- export & import the "next sequence #" for each table
  put at same level as the "Data" folder


Could there be a way that the current settings that were user could be saved to a settings file which could then be reused in subsequent usages?
*/


Progress QUIT(0)
Log_OpenDisplayWindow
Export_Import_Dialog


If (False:C215)
	var $options : Object
	$options:=New object:C1471
	$options.num_processes:=3
	$options.field_ptrs_to_ignore:=New collection:C1472(->[Table_2:2]Field_3:3)
	//$options.tables_to_scan:=New collection(Table(->[Table_2]))  // null or empty means all tables
	
	Export_HealthCheck_Scan($options)
	Export_PreCheck_RemoveBadChars($options)
	Export_HealthCheck_Scan($options)
End if 

If (False:C215)  // ## Create test data
	var $i : Integer
	
	// create [Table_1] records
	TRUNCATE TABLE:C1051([Table_1:1])
	For ($i; 1; 8000)
		CREATE RECORD:C68([Table_1:1])
		[Table_1:1]Field_2:2:="text "+String:C10($i)
		[Table_1:1]Field_3:3:="alpha "+String:C10($i)
		[Table_1:1]Field_4:4:=Add to date:C393(!00-00-00!; 2000; 1; $i-1)
		[Table_1:1]Field_5:5:=Time:C179($i)
		[Table_1:1]Field_6:6:=(Mod:C98($i; 2)=0)
		[Table_1:1]Field_7:7:=$i
		[Table_1:1]Field_8:8:=100000+$i
		[Table_1:1]Field_9:9:=100000+$i+($i/1000)
		VARIABLE TO BLOB:C532($i; [Table_1:1]Field_10:10)
		//[Table_1]Field_11:=
		[Table_1:1]Field_12:12:=New object:C1471("i"; $i)
		SAVE RECORD:C53([Table_1:1])
	End for 
	REDUCE SELECTION:C351([Table_1:1]; 0)
	
	// create [Table_2] records
	TRUNCATE TABLE:C1051([Table_2:2])
	For ($i; 1; 6000)
		CREATE RECORD:C68([Table_2:2])
		[Table_2:2]Field_2:2:="alpha "+String:C10($i)
		[Table_2:2]Field_3:3:="alpha "+String:C10($i)
		[Table_2:2]Field_4:4:="alpha "+String:C10($i)
		[Table_2:2]Field_5:5:="text "+String:C10($i)+(" ="*$i)
		SAVE RECORD:C53([Table_2:2])
	End for 
	REDUCE SELECTION:C351([Table_2:2]; 0)
End if 

If (False:C215)
	var $export_folder_platformPath : Text
	$export_folder_platformPath:=Export_ListOfTables(3; New collection:C1472(Table:C252(->[Table_2:2])))
	SHOW ON DISK:C922($export_folder_platformPath)
End if 

If (False:C215)  // ## Export all tables
	var $export_folder_platformPath : Text
	$export_folder_platformPath:=Export_AllTables(4)
	SHOW ON DISK:C922($export_folder_platformPath)
End if 

If (False:C215)  // ## Import exported data
	var $options : Object
	$options:=New object:C1471
	$options.truncation_before_import:=False:C215  // default
	
	var $importFromFolder_platformPath : Text
	$importFromFolder_platformPath:=Import_AllTables(4; $options)
	SHOW ON DISK:C922($importFromFolder_platformPath)
End if 

BEEP:C151
ABORT:C156