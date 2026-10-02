//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_HealthCheck_Scan (incoming_options) : run report path
//
// DESCRIPTION
//   A wrapper over HealthCheckPass, or FixerPass when
//   remove_bad_characters is True (spec 12). The old options are
//   translated: num_processes becomes workers (0 means the default),
//   tables_to_scan becomes tables (empty or missing means every table, as
//   before) and field_ptrs_to_ignore stays. Returns the run report's .txt
//   path, or "" when it couldn't be written.
//
#DECLARE($incoming_options : Object)->$report_platformPath : Text
// ----------------------------------------------------
$report_platformPath:=cs[Bool($incoming_options.remove_bad_characters) ? "FixerPass" : "HealthCheckPass"].new({\
workers: (Num($incoming_options.num_processes)<=0) ? Null : $incoming_options.num_processes; \
tables: (Num($incoming_options.tables_to_scan.length)=0) ? Null : $incoming_options.tables_to_scan; \
field_ptrs_to_ignore: $incoming_options.field_ptrs_to_ignore}).run().report
