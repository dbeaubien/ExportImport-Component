//%attributes = {}
// Task 9073 - Export/Import code for datafile rebuilds improvements
/*
Make a few changes/improvements to the export/import process we follow to rebuild datafiles:
- In scan for bad characters, add a check to detect if PK fields are null, 0 or an empty GUID.
- Work out how to add a check for duplicate values on fields marked as unique.
- Dump out record counts into a file as part of the export and post import.
- Could the import process utilized the export's table count file to validate the #s are part of the import?
- Add a check for fields where NULLs don't map to blank.

Perhaps the "bad character" scan is turned into a "health check scan".

Also thinking that the component has a dialog that is shown that gives access to all these tools.
It would need a way to be able to pick tables to export and a way to mark which fields should be base64'd

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
	var $fields_to_base64 : Collection
	$fields_to_base64:=New collection:C1472(->[Table_2:2]Field_2:2; ->[Table_2:2]Field_5:5)
	$export_folder_platformPath:=Export_AllTables(4; $fields_to_base64)
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