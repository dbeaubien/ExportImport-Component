//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_AllTables (num_workers{; fields_to_base64}) : export set path
//
// DESCRIPTION
//   A wrapper over ExportPass, every table, empty ones included (spec 12).
//   num_workers 0 means the pass's default (spec 15). fields_to_base64 is
//   ignored. A refused or failed export still returns the set's path: its
//   run report says why.
//
#DECLARE($num_workers : Integer\
; $fields_to_base64 : Collection)->$export_folder_platformPath : Text
// ----------------------------------------------------
$export_folder_platformPath:=cs.ExportPass.new({workers: ($num_workers<=0) ? Null : $num_workers}).run().export_set
