//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Export_Run
//
// DESCRIPTION
//   DEV ONLY. Ticket 07's interrupted check: an export of every table, to
//   follow with tail -f on its run log and to quit 4D during. The cache is
//   flushed first and the export only reads, so a force quit leaves the
//   datafile as it was. Alerts the verdict and the run report's path if it ends.
//
var $r : Object
FLUSH CACHE
$r:=cs.ExportPass.new({}).run()
ALERT("Export: "+$r.verdict+Char(Carriage return)+$r.report)
