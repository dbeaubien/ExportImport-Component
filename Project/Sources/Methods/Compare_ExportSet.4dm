//%attributes = {"shared":true,"preemptive":"incapable"}
// Compare_ExportSet (export_set{; options}) : result
//
// DESCRIPTION
//   Compares an export set with this datafile (specs 08 and 12): a wrapper
//   over ComparePass. export_set is the set's platform path. Options:
//   workers (4 by default, capped at the core count) and detail_limit
//   (1,000). Returns the result object, whose verdict is exact, notExact,
//   inconclusive, refused or failed.
//
#DECLARE($export_set : Text; $options : Object)->$result : Object
// ----------------------------------------------------
$result:=cs.ComparePass.new($export_set; $options).run()
