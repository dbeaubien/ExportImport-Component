//%attributes = {}
// Export_Import_Dialog

var $target_folder : 4D:C1709.Folder
$target_folder:=cs:C1710._Utils.new().Get_Named_Working_Folder("Table Export")

var $exporter : cs:C1710.Table_Exporter
$exporter:=cs:C1710.Table_Exporter.new($target_folder.folder("Data"))
$exporter.Set_File_Max_MB_Size(10)

var $progHdl : Integer
var $manifest : Object
$progHdl:=Progress New()
$manifest:={exports: []}
$manifest.exports.push($exporter.Export_All_Records(Table:C252(->[Table_1:1]); $progHdl))
$manifest.exports.push($exporter.Export_All_Records(Table:C252(->[Table_2:2]); $progHdl))
Progress QUIT($progHdl)
TEXT TO DOCUMENT:C1237($target_folder.file("Export Manifest.json").platformPath; JSON Stringify:C1217($manifest; *); "utf-8")
SHOW ON DISK:C922($target_folder.platformPath)


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