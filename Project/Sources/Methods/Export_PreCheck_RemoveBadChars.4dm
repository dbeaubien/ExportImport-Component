//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_PreCheck_RemoveBadChars (incoming_options) : run report path
//
// DESCRIPTION
//   A wrapper over FixerPass, through Export_HealthCheck_Scan with
//   remove_bad_characters (spec 12), which takes the same options. The
//   fixer turns triggers off and back on itself.
//
#DECLARE($incoming_options : Object)->$report_platformPath : Text
// ----------------------------------------------------
$report_platformPath:=Export_HealthCheck_Scan({\
num_processes: $incoming_options.num_processes; \
tables_to_scan: $incoming_options.tables_to_scan; \
field_ptrs_to_ignore: $incoming_options.field_ptrs_to_ignore; \
remove_bad_characters: True})
