// cs._FixJob
//
// The fixer's work (spec 09) on one key range of one table, as a job. It
// walks the job's records in key order READ WRITE, deletes each bad
// character (STR_GetListOfBadCharacters) of its Alpha and Text values, and
// saves the record. It never finds a record by its key, which may contain @
// (spec 14). It skips the ignored fields and the record key: a new key
// would cut the record off from the records that point at it, so a bad
// character there stays a key_bad_character finding of the scan.
//
// Adds to the job contract detail_limit and ignore, as _ScanJob. Its row
// adds characters_removed and records_saved. One finding per saved record,
// at most detail_limit, which the pass lists as a removal: {table; key;
// characters: [{field; pos; char_code}]}.
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   9 a record to fix is locked by another process: SAVE RECORD would leave
//   it as it is.

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table; $key; $p : Pointer
	var $fields; $bad; $removed : Collection
	var $field; $f; $c; $row : Object
	var $value : Text
	var $i; $n : Integer
	$row:=This.output.row
	$row.characters_removed:=0
	$row.records_saved:=0
	$fields:=[]
	For each ($field; This.job.table.fields)
		Case of
			: (This.job.ignore.indexOf($field.number)>=0)
			: ($field.number=This.job.table.primary_key)
			: (String($field.type)="STR") | (String($field.type)="TEXT")  // String(): an unreadable type is a number
				$fields.push({name: $field.name; ptr: Field(This.job.table.number; $field.number)})
		End case
	End for each
	If (This.job.table.primary_key#0)
		$key:=Field(This.job.table.number; This.job.table.primary_key)
	End if

	READ WRITE(Table(This.job.table.number)->)
	$table:=This._select()
	$n:=Records in selection($table->)
	$row.records:=$n  // for the pool's log line: the pass doesn't add it to the gate's row
	For ($i; 1; $n)
		GOTO SELECTED RECORD($table->; $i)
		If (This.job.table.primary_key#0)
			This._key:=$key->
		End if
		$removed:=[]
		For each ($f; $fields)
			$p:=$f.ptr
			$value:=$p->
			$bad:=STR_GetListOfBadCharacters($value)
			If ($bad.length>0)
				For each ($c; $bad.reverse())  // from the end, so each pos still holds: pos counts UTF-16 code units, as Delete string does
					$value:=Delete string($value; $c.pos; 1)
				End for each
				$p->:=$value
				For each ($c; $bad)
					$removed.push({field: $f.name; pos: $c.pos; char_code: $c.char_code})
				End for each
			End if
		End for each
		If ($removed.length>0)
			If (Locked($table->))
				throw({errCode: 9; componentSignature: "ExportImport"; message: "the record is locked by another process, so its bad characters can't be removed"})
			End if
			SAVE RECORD($table->)
			$row.characters_removed+=$removed.length
			$row.records_saved+=1
			If ($row.records_saved<=This.job.detail_limit)
				This.output.findings.push({table: This.job.table.name; key: This._key; characters: $removed})
			End if
		End if
		If ($i%1000=0)
			This._tick($i)
		End if
	End for
	UNLOAD RECORD($table->)
