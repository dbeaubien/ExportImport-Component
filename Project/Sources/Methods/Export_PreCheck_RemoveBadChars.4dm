//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_PreCheck_FindBadChars (incoming_options)
//
// DESCRIPTION
//   Scans all the alpha/text fields in the specified tables
//   for characters that cause XML export/import issue.
//   Any bad characters that are found are removed.
//
#DECLARE($incoming_options : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
ASSERT:C1129($incoming_options#Null:C1517)

var $incoming_options_copy : Object
$incoming_options_copy:=OB Copy:C1225($incoming_options)
$incoming_options_copy.remove_bad_characters:=True:C214

Trigger_DISABLE
Export_PreCheck_FindBadChars($incoming_options_copy)
Trigger_ENABLE