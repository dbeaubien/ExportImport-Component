// cs.HealthChecker

property _tables_to_scan : Collection
property _field_ptrs_to_ignore : Collection
property _utils : cs:C1710._Utils

Class constructor
	This:C1470._tables_to_scan:=[]
	This:C1470._field_ptrs_to_ignore:=[]
	This:C1470._utils:=cs:C1710._Utils.new()
	
	
	//Mark:-************ PUBLIC FUNCTIONS
Function Set_Tables_to_Check($tables_to_scan : Collection) : cs:C1710.HealthChecker
	This:C1470._tables_to_scan:=[]
	If ($tables_to_scan=Null:C1517) || ($tables_to_scan.length=0)
		This:C1470._set_tables_to_all_tables()
	Else 
		var $table_no : Integer
		For each ($table_no; $tables_to_scan)  // build $tables_to_scan
			This:C1470._add_table($table_no)
		End for each 
	End if 
	This:C1470._tables_to_scan:=This:C1470._tables_to_scan.orderBy("num_records desc")  // do biggest tables first
	return This:C1470
	
	
Function Set_Alpha_Field_Ptrs_to_Ignore_Bad_Chars($field_ptrs_to_ignore : Collection) : cs:C1710.HealthChecker
	If ($field_ptrs_to_ignore=Null:C1517)
		This:C1470._field_ptrs_to_ignore:=[]
	Else 
		This:C1470._field_ptrs_to_ignore:=$field_ptrs_to_ignore.copy()
	End if 
	return This:C1470
	
	
Function Get_Target_Folder()->$target_folder : 4D:C1709.Folder
	$target_folder:=This:C1470._utils.Get_Named_Working_Folder("Health Check Scan")
	
	
	
	//Mark:-************ PRIVATE FUNCTIONS
Function _add_table($table_no : Integer)
	If (Is table number valid:C999($table_no) && (Records in table:C83(Table:C252($table_no)->)>0))
		This:C1470._tables_to_scan.push({\
			table_no: $table_no; \
			table_name: Table name:C256($table_no); \
			num_records: Records in table:C83(Table:C252($table_no)->)})
	End if 
	
	
Function _set_tables_to_all_tables()
	var $table_no : Integer
	For ($table_no; 1; Get last table number:C254)
		This:C1470._add_table($table_no)
	End for 
	