//%attributes = {"invisible":true,"preemptive":"capable"}
// WorkerPool_Log (log; text)
//
// DESCRIPTION
//   Appends "<Timestamp>  <text>" to the worker log (finer-job-cut ticket
//   02), from the coordinator or a worker. log is the shared object
//   {path} that _WorkerPool passes to its workers: the line is written
//   inside Use of it, so lines from several processes never interleave.
//   Each line opens the file, appends and lets the handle go, as in
//   _RunLog. A failed write is ignored: it never fails or hangs a job.
//
#DECLARE($log : Object; $text : Text)
// ----------------------------------------------------
var $bytes : Blob
CONVERT FROM TEXT(Timestamp+"  "+$text+"\n"; "UTF-8"; $bytes)
Use ($log)
	Try
		File($log.path; fk platform path).open("append").writeBlob($bytes)
	Catch
	End try
End use
