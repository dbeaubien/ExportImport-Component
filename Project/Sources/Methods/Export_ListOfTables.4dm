//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_ListOfTables (num_workers; table_no_list{; fields_to_base64}) : export set path
//
// DESCRIPTION
//   A wrapper over ExportPass, the listed tables (spec 12). num_workers 0
//   means the pass's default (spec 15). fields_to_base64 is ignored. A
//   refused or failed export still returns the set's path: its run report
//   says why.
//
#DECLARE($num_workers : Integer\
; $table_no_list : Collection\
; $fields_to_base64 : Collection)->$export_folder_platformPath : Text
// ----------------------------------------------------
$export_folder_platformPath:=cs.ExportPass.new({workers: ($num_workers<=0) ? Null : $num_workers; tables: $table_no_list}).run().export_set
