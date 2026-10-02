// cs._ImportJob
//
// The import's load (specs 07 and 10) of one run of a table's segments, as
// a job. It reads each segment whole into a Blob and decodes it record by
// record (_Codec) into a new record, saved with SAVE RECORD. The pass has
// emptied the table, paused its indexes and turned triggers and
// constraints off, so each record is saved with its values as decoded.
// Each segment must load the manifest's record count.
//
// Adds to the job contract folder, the platform path of the table's folder
// in the set. Its row adds records, the records loaded.
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   14 a segment holds another record count than the manifest's.

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table; $key : Pointer
	var $codec : cs._Codec
	var $segment : Blob
	var $s : Object
	var $o; $len; $n; $done : Integer
	$codec:=cs._Codec.new(This.job.table)
	$table:=Table(This.job.table.number)
	If (This.job.table.primary_key#0)  // a table with records has one: the gate refuses a table without
		$key:=Field(This.job.table.number; This.job.table.primary_key)
	End if

	READ WRITE($table->)
	For each ($s; This.job.segments)
		This._tick($done)
		$segment:=Folder(This.job.folder; fk platform path).file($s.file).getContent()
		$o:=0
		$n:=0
		While ($o<BLOB size($segment))
			$len:=BLOB to longint($segment; PC byte ordering; $o)  // moves $o past the length
			CREATE RECORD($table->)
			$codec.decode(->$segment; $o)
			This._key:=$key->
			SAVE RECORD($table->)
			$o+=$len
			$n+=1
			$done+=1
			If ($done%1000=0)
				This._tick($done)
			End if
		End while
		If ($n#$s.records)
			throw({errCode: 14; componentSignature: "ExportImport"; message: "["+This.job.table.name+"] the segment "+$s.file+" holds "+String($n)+" records, not the manifest's "+String($s.records)})
		End if
	End for each
	UNLOAD RECORD($table->)
	This.output.row.records:=$done
