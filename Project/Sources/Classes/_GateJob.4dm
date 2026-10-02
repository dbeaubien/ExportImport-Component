// cs._GateJob
//
// The health check's blocker gate (spec 09) on one table, as a job: one job
// per table, never split (spec 10). Adds detail_limit to the job contract.
//
// The gate uses structure checks and engine queries only. A record is never
// loaded to find a value, since loading an Auto UUID field that holds null
// makes one up. Keys are never compared with the language = or <, which read
// @ as a wildcard: uniqueness is the engine's distinct(), which compares
// without case or accents, as the index does (ticket 01's fact 5).

Class extends _Job

property _limit : Integer  // detail_limit: the findings listed per table per check

Class constructor($job : Object)
	Super($job)
	This._limit:=(This.job.detail_limit=Null) ? 1000 : This.job.detail_limit


Function _run()
	var $table; $row; $field; $key : Object
	var $class : 4D.DataClass
	var $sel : 4D.EntitySelection
	var $blank : Collection
	var $value : Variant
	$table:=This.job.table
	$row:=This.output.row
	$row.records:=Records in table(Table($table.number)->)
	$row.blockers:=0
	$row.damage:=0
	$row.checks:={}
	For each ($field; $table.fields)
		If (Value type($field.type)#Is text)  // Float or subtable: _Structure names only the types the codec encodes
			This._add("unreadable_field"; 1; [{table: $table.name; key: Null; field: $field.name; kind: "unreadable_field"}])
		End if
	End for each
	Case of
		: ($row.records=0)  // an empty table is exported as its count and sequence number only
		: ($table.primary_key=0)
			This._add("no_primary_key"; 1; [{table: $table.name; key: Null; field: Null; kind: "no_primary_key"}])
		Else
			$class:=ds[$table.name]
			$key:=$table.fields.query("number = :1"; $table.primary_key).first()

			// Null and blank keys. A UUID key whose bytes are all 0x20 is "" assigned (ticket 01's fact 2).
			Case of
				: (String($key.type)="UUID")  // String(): an unreadable type is a number
					$blank:=[Null; "0"*32; "20"*16]
				: ((String($key.type)="STR") || (String($key.type)="TEXT"))
					$blank:=[Null; ""]
				Else
					$blank:=[Null; 0]
			End case
			For each ($value; $blank)
				$sel:=($value=Null) ? $class.query(":1 = null"; $key.name) : $class.query(":1 = :2"; $key.name; $value)
				This._add("blank_key"; $sel.length; [{table: $table.name; key: $value; field: $key.name; kind: "blank_key"; records: $sel.length}])
			End for each
			This._duplicates($class; $key.name; True)

			For each ($field; $table.fields.query("type = :1"; "I64"))  // beyond ±2^53 the language reads a rounded Real, so only the engine sees 2^53+1
				$sel:=$class.query(":1 > :2 OR :1 < :3"; $field.name; 2^53; -(2^53))
				This._add("int64_range"; $sel.length; This._keyed("int64_range"; $field.name; $sel; $key.name))
			End for each
			For each ($field; $table.fields.query("type = :1 AND number # :2"; "UUID"; $table.primary_key))
				If ($class[$field.name].autoFilled)  // Auto UUID
					$sel:=$class.query(":1 = null"; $field.name)
					This._add("null_auto_uuid"; $sel.length; This._keyed("null_auto_uuid"; $field.name; $sel; $key.name))
				End if
			End for each
			For each ($field; $table.fields.query("number # :1"; $table.primary_key))
				If ($class[$field.name].unique)  // ticket 01's fact 13: duplicates loaded here silently break the rebuilt index
					This._duplicates($class; $field.name; False)
				End if
			End for each
	End case


Function _duplicates($class : 4D.DataClass; $field : Text; $is_key : Boolean)
	// The groups of records whose values of a unique field 4D compares as equal.
	var $groups; $findings : Collection
	var $group; $finding : Object
	var $kind : Text
	$kind:=$is_key ? "duplicate_key" : "duplicate_unique"
	$groups:=$class.all().distinct($field; dk count values).query("count > 1")
	$findings:=[]
	For each ($group; $groups.slice(0; This._limit))
		$finding:={table: This.job.table.name; key: Null; field: $field; kind: $kind; records: $group.count}
		If ($is_key)
			$finding.key:=$group.value
		Else
			$finding.value:=$group.value
		End if
		$findings.push($finding)
	End for each
	If ($groups.length>This._limit)
		$findings.push({table: This.job.table.name; key: Null; field: $field; kind: $kind; not_listed: $groups.length-This._limit})
	End if
	This._add($kind; $groups.sum("count"); $findings)


Function _keyed($kind : Text; $field : Text; $sel : 4D.EntitySelection; $pk : Text) : Collection
	// One finding per record, named by its key, up to detail_limit, then how many more.
	var $findings : Collection
	var $key : Variant
	$findings:=[]
	For each ($key; $sel.slice(0; This._limit).extract($pk; ck keep null))
		$findings.push({table: This.job.table.name; key: $key; field: $field; kind: $kind})
	End for each
	If ($sel.length>This._limit)
		$findings.push({table: This.job.table.name; key: Null; field: $field; kind: $kind; not_listed: $sel.length-This._limit})
	End if
	return $findings


Function _add($kind : Text; $count : Integer; $findings : Collection)
	// Counts $count blocked records (or fields) on the row and lists the
	// findings. Called after each check, so it is also where the job ticks.
	If ($count>0)
		This.output.row.blockers+=$count
		This.output.row.checks[$kind]:=Num(This.output.row.checks[$kind])+$count
		This.output.findings.combine($findings)
	End if
	This._tick(0)
