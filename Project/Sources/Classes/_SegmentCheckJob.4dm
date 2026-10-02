// cs._SegmentCheckJob
//
// The import's first phase (spec 07) on one run of a table's segments, as a
// job: each segment is there, with the manifest's byte size and SHA-256.
// Files the manifest doesn't list are ignored, and nothing is written.
//
// Adds to the job contract folder, the platform path of the table's folder
// in the set. One finding per damaged segment: the problem, as text. Its
// row adds records, for the pool's log line.

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $file : 4D.File
	var $segment : Blob
	var $s : Object
	var $problem : Text
	This.output.row.records:=0
	For each ($s; This.job.segments)
		This._tick(This.output.row.records)
		$file:=Folder(This.job.folder; fk platform path).file($s.file)
		Case of
			: (Not($file.exists))
				$problem:="is missing"
			: ($file.size#$s.bytes)
				$problem:="has "+String($file.size)+" bytes, not "+String($s.bytes)
			Else
				$segment:=$file.getContent()
				$problem:=(Generate digest($segment; SHA256 digest)=$s.sha256) ? "" : "doesn't match its SHA-256"
		End case
		If ($problem#"")
			This.output.findings.push("The export set is damaged: ["+This.job.table.name+"] segment "+$s.file+" "+$problem)
		End if
		This.output.row.records+=$s.records
	End for each
