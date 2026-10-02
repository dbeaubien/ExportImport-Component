// cs._ScanJob
//
// The health check's scan for signs of damage (spec 09) on one key range of
// one table, as a job. It reads every Alpha and Text value for bad
// characters (STR_GetListOfBadCharacters), and every UUID field outside the
// key for the all-0x20 bytes that "" assigned stores (ticket 01's fact 2).
// It skips the ignored fields. An Alpha or Text key that contains @ is a
// blocker (spec 14), whatever the ignored fields: Position finds it, since it
// reads @ as a plain character.
//
// Adds to the job contract detail_limit and ignore, the field numbers of
// field_ptrs_to_ignore in this table. One finding per value: {table; key;
// field; kind}, plus value (a JSON string of its first 1,000 characters) and
// characters ([{pos; char_code}]) for bad characters. The kinds:
// bad_character, lone_surrogate (a value that holds one, which the export
// refuses: ticket 01's fact 3), key_bad_character (either, in the record
// key, which the fixer leaves), space_uuid and at_in_key. Each job lists at
// most detail_limit findings per kind. The pass caps the table's again.

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table; $key; $p : Pointer
	var $fields; $bad : Collection
	var $field; $f; $finding; $row : Object
	var $type; $value; $key_name; $kind : Text
	var $text_key : Boolean
	var $i; $n : Integer
	$row:=This.output.row
	$row.blockers:=0
	$row.damage:=0
	$row.checks:={}
	$fields:=[]
	For each ($field; This.job.table.fields)
		$type:=String($field.type)  // String(): an unreadable type is a number
		Case of
			: (This.job.ignore.indexOf($field.number)>=0)
			: ($type="STR") | ($type="TEXT")
				$fields.push({name: $field.name; ptr: Field(This.job.table.number; $field.number); uuid: False; key: ($field.number=This.job.table.primary_key)})
			: ($type="UUID") & ($field.number#This.job.table.primary_key)
				$fields.push({name: $field.name; ptr: Field(This.job.table.number; $field.number); uuid: True})
		End case
	End for each
	If (This.job.table.primary_key#0)
		$field:=This.job.table.fields.query("number = :1"; This.job.table.primary_key).first()
		$key:=Field(This.job.table.number; $field.number)
		$key_name:=$field.name
		$text_key:=(String($field.type)="STR") | (String($field.type)="TEXT")
	End if

	READ ONLY(Table(This.job.table.number)->)
	$table:=This._select()
	$n:=Records in selection($table->)
	$row.records:=$n  // for the pool's log line: the pass doesn't add it to the gate's row
	For ($i; 1; $n)
		GOTO SELECTED RECORD($table->; $i)
		If (This.job.table.primary_key#0)
			This._key:=$key->
			If ($text_key) && (Position("@"; This._key; 1; *)>0)
				This._found("at_in_key"; $key_name)
			End if
		End if
		For each ($f; $fields)
			$p:=$f.ptr
			$value:=$p->
			If ($f.uuid)
				If ($value=("20"*16))
					This._found("space_uuid"; $f.name)
				End if
			Else
				$bad:=STR_GetListOfBadCharacters($value)
				If ($bad.length>0)
					Case of
						: ($f.key)
							$kind:="key_bad_character"
						: (Match regex("[\\x{D800}-\\x{DFFF}]"; $value; 1))
							$kind:="lone_surrogate"
						Else
							$kind:="bad_character"
					End case
					$finding:=This._found($kind; $f.name)
					If ($finding#Null)
						$finding.value:=This._shown($value)
						$finding.characters:=$bad
					End if
				End if
			End if
		End for each
		If ($i%1000=0)
			This._tick($i)
		End if
	End for


Function _found($kind : Text; $field : Text) : Object
	// Counts one finding on the row: at_in_key as a blocker, the others as
	// damage. Lists it within detail_limit per kind and returns it, or Null.
	var $finding : Object
	If ($kind="at_in_key")
		This.output.row.blockers+=1
	Else
		This.output.row.damage+=1
	End if
	This.output.row.checks[$kind]:=Num(This.output.row.checks[$kind])+1
	If (This.output.row.checks[$kind]<=This.job.detail_limit)
		$finding:={table: This.job.table.name; key: This._key; field: $field; kind: $kind}
		This.output.findings.push($finding)
	End if
	return $finding


Function _shown($value : Text) : Text
	// The value's first 1,000 characters as a JSON string. JSON Stringify
	// escapes the control characters, and this the other bad ones: UTF-8
	// can't hold a lone surrogate (ticket 01's fact 3).
	var $shown : Text
	var $start; $pos; $len : Integer
	$shown:=JSON Stringify(Substring($value; 1; 1000))
	$start:=1
	While (Match regex("[\\x{D800}-\\x{DFFF}\\x{FFFE}\\x{FFFF}]"; $shown; $start; $pos; $len))
		$shown:=Substring($shown; 1; $pos-1)+"\\u"+Substring(String(Character code($shown[[$pos]]); "&x"); 3)+Substring($shown; $pos+1)
		$start:=$pos+6
	End while
	return $shown
