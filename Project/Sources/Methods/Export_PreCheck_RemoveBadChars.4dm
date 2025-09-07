//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_HealthCheck_Scan (incoming_options)
//
// DESCRIPTION
//   Scans all the alpha/text fields in the specified tables
//   for characters that cause XML export/import issue.
//   Any bad characters that are found are removed.
//
#DECLARE($incoming_options : Object)->$export_folder_platformPath : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
ASSERT:C1129($incoming_options#Null:C1517)
$export_folder_platformPath:=""

var $incoming_options_copy : Object
$incoming_options_copy:=OB Copy:C1225($incoming_options)
$incoming_options_copy.remove_bad_characters:=True:C214

Trigger_DISABLE
$export_folder_platformPath:=Export_HealthCheck_Scan($incoming_options_copy)
Trigger_ENABLE