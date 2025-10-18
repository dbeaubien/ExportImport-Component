// cs.Utils

Class constructor
	This:C1470.version:=1
	
	
	//Mark:-************ PUBLIC FUNCTIONS
Function Get_Named_Working_Folder($folder_name_root : Text)->$folder : 4D:C1709.Folder
	var $folder_name : Text
	$folder_name+="_EXPORT-IMPORT "+$folder_name_root+" "\
		+Date2String(Current date:C33; "yyyy-mm-dd ")\
		+Time2String(Current time:C178; "24hh.mm.ss")
	$folder:=Folder:C1567(fk data folder:K87:12; *).folder($folder_name)
	$folder.create()
	
	
	
	
	//Mark:-************ PRIVATE FUNCTIONS
	