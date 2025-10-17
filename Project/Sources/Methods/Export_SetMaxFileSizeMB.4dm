//%attributes = {}
// Export_SetMaxFileSizeMB (max_size_mb) 
//
#DECLARE($max_size_mb : Integer)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

If (Storage:C1525.export=Null:C1517)
	Use (Storage:C1525)
		Storage:C1525.export:=New shared object:C1526
	End use 
End if 

Use (Storage:C1525.export)
	Storage:C1525.export.max_export_file_size_mb:=$max_size_mb
End use 