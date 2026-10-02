// cs._ExportJob
//
// The export (spec 05) of one key range of one table, as a job. It walks the
// job's records in key order, encodes each one (_Codec) behind its 4-byte
// little-endian length, and writes them into segments of at most segment_mb:
// a record that would pass the cap starts the next segment, and a record
// bigger than the cap gets one of its own. A segment is named by the 12-digit
// position of its first record in the table's key order, so the jobs of one
// table name theirs without coordination (spec 10).
//
// Adds to the job contract segment_mb and folder, the platform path of the
// table's folder in the export set, which the coordinator creates. Its row
// adds segments and bytes. One finding per segment, which the pass puts in
// the manifest: {table; file; records; bytes; sha256; first_key; last_key}.
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   10 an Alpha or Text record key contains @, which QUERY and the language
//   read as a wildcard, so import and Compare couldn't match it (spec 14).
//   The pass refuses on it, as on the codec's lone surrogate (3).

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table; $key : Pointer
	var $codec : cs._Codec
	var $segment; $record : Blob
	var $row; $s : Object
	var $cap; $size; $need : Real
	var $i; $n; $used : Integer
	$row:=This.output.row
	$row.segments:=0
	$row.bytes:=0
	$codec:=cs._Codec.new(This.job.table)
	$cap:=This.job.segment_mb*1048576
	If (This.job.table.primary_key#0)
		$key:=Field(This.job.table.number; This.job.table.primary_key)
	End if

	READ ONLY(Table(This.job.table.number)->)
	$table:=This._select()
	$n:=Records in selection($table->)
	$row.records:=$n
	For ($i; 1; $n)
		GOTO SELECTED RECORD($table->; $i)
		If (This.job.table.primary_key#0)
			This._key:=$key->
			If (Value type(This._key)=Is text) && (Position("@"; This._key; 1; *)>0)
				throw({errCode: 10; componentSignature: "ExportImport"; message: "["+This.job.table.name+"]"+This.job.table.fields.query("number = :1"; This.job.table.primary_key).first().name+": the record key "+JSON Stringify(This._key)+" contains @, which import and Compare can't match"})
			End if
		End if
		$record:=$codec.encode()
		$size:=BLOB size($record)  // a Real, so the sums below can't overflow
		If ($used>0) && (($used+4+$size)>$cap)
			This._write(->$segment; $used; $s)
			$used:=0
		End if
		If ($used=0)
			$s:={table: This.job.table.name; file: String(This.job.start+$i-1; "000000000000")+".seg"; records: 0; bytes: 0; sha256: ""; first_key: This._key; last_key: Null}
		End if
		$need:=$used+4+$size
		If (BLOB size($segment)<$need)  // grows by doubling, up to the cap, so a small table never holds a whole cap
			SET BLOB SIZE($segment; [[$need*2; $cap].min(); $need].max())
		End if
		LONGINT TO BLOB($size; $segment; PC byte ordering; $used)
		COPY BLOB($record; $segment; 0; $used; $size)
		$used+=$size
		$s.records+=1
		$s.last_key:=This._key
		If ($i%1000=0)
			This._tick($i)
		End if
	End for
	If ($used>0)
		This._write(->$segment; $used; $s)
	End if


Function _write($segment : Pointer; $used : Integer; $s : Object)
	// Writes the segment's first $used bytes to its file, and lists it.
	SET BLOB SIZE($segment->; $used)
	$s.bytes:=$used
	$s.sha256:=Generate digest($segment->; SHA256 digest)
	Folder(This.job.folder; fk platform path).file($s.file).setContent($segment->)
	This.output.findings.push($s)
	This.output.row.segments+=1
	This.output.row.bytes+=$used
