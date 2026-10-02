//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Read_Facts
//
// DESCRIPTION
//   DEV ONLY. Ticket 01's spike, facts 1–9: the 4D facts about reading
//   records that the exact-copy-v2 spec relies on. Needs the bench data
//   (__Bench_Generate). Truncates and fills the Spike_* tables first.
//   Fact 1 saves 2,000 sampled Bench_Blob and Bench_Wide records unchanged.
//   Writes .scratch/exact-copy-v2-build/research/01-__Spike_Read_Facts-<compiled|interpreted>.json.
//
// ----------------------------------------------------
var $facts; $keys; $spike; $rows; $bad; $sent; $received; $bytes; $b; $errors : Collection
var $f; $s; $rejected; $first; $again; $after; $probe : Object
var $i; $n; $y; $pic_reads; $obj_reads; $pic_saves; $obj_saves; $modified; $save_errors : Integer
var $table; $key; $pic; $obj : Pointer
var $t; $back; $key_value; $lo; $hi; $xml; $element : Text
var $blob : Blob
var $d; $d2 : Date
var $found : Boolean
var $start; $pos; $len : Integer
ARRAY LONGINT($ids; 0)
ARRAY LONGINT($rns; 0)
ARRAY TEXT($sorted; 0)
ARRAY TEXT($all; 0)
$facts:=[]

// ## Fact 1: VARIABLE TO BLOB of a picture or object field is stable
For ($i; 1; 1000)
	APPEND TO ARRAY($ids; $i*1000)  // Bench_Wide has a picture every 1,000 records
End for
$f:={fact: 1; spec: "04"; expected: "the same VARIABLE TO BLOB bytes for each picture and object field, read twice, then after an untouched SAVE RECORD and reload"; pass: True; actual: {}}
Try
	For each ($s; [{name: "Bench_Blob"; table: ->[Bench_Blob]; pic: ->[Bench_Blob]Image; obj: ->[Bench_Blob]Meta; key: ->[Bench_Blob]ID}; {name: "Bench_Wide"; table: ->[Bench_Wide]; pic: ->[Bench_Wide]F_Picture; obj: ->[Bench_Wide]F_Object; key: ->[Bench_Wide]ID}])
		$table:=$s.table
		$pic:=$s.pic
		$obj:=$s.obj
		$key:=$s.key
		If ($s.name="Bench_Blob")
			QUERY([Bench_Blob]; [Bench_Blob]ID<=1000)
		Else
			QUERY WITH ARRAY([Bench_Wide]ID; $ids)
		End if
		SELECTION TO ARRAY($table->; $rns)
		$pic_reads:=0
		$obj_reads:=0
		$pic_saves:=0
		$obj_saves:=0
		$modified:=0
		$save_errors:=0
		For ($i; 1; Size of array($rns))
			GOTO RECORD($table->; $rns{$i})
			$first:=__Spike_Digests($pic->; $obj->)
			$again:=__Spike_Digests($pic->; $obj->)
			$key->:=$key->  // untouched: only the key is assigned, to its own value
			$modified:=$modified+Num(Modified($key->))
			$errors:=__Spike_Save($table)
			$save_errors:=$save_errors+$errors.length
			UNLOAD RECORD($table->)
			GOTO RECORD($table->; $rns{$i})
			$after:=__Spike_Digests($pic->; $obj->)
			$pic_reads:=$pic_reads+Num($first.pic#$again.pic)
			$obj_reads:=$obj_reads+Num($first.obj#$again.obj)
			$pic_saves:=$pic_saves+Num($first.pic#$after.pic)
			$obj_saves:=$obj_saves+Num($first.obj#$after.obj)
		End for
		UNLOAD RECORD($table->)
		$f.actual[$s.name]:={records: Size of array($rns); pic_reads_differ: $pic_reads; obj_reads_differ: $obj_reads; pic_differs_after_save: $pic_saves; obj_differs_after_save: $obj_saves; saves_with_key_modified: $modified; save_errors: $save_errors}
		$f.pass:=$f.pass & (Size of array($rns)>0) & (($pic_reads+$obj_reads+$pic_saves+$obj_saves+$save_errors)=0)
	End for each
Catch
	$f.pass:=False
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 2: a null UUID and an all-zero UUID read differently
$f:={fact: 2; spec: "04"; expected: "a null UUID field and an all-zero UUID field read differently"; pass: False}
Try
	READ ONLY([Bench_Wide])  // the all-zero value is assigned in memory only
	QUERY WITH ARRAY([Bench_Wide]ID; $ids)
	$found:=False
	While (Not(End selection([Bench_Wide])) & Not($found))
		$found:=Is field value Null([Bench_Wide]F_UUID)
		If (Not($found))
			NEXT RECORD([Bench_Wide])
		End if
	End while
	If ($found)
		$f.actual:={record_id: [Bench_Wide]ID; null_reads_as: [Bench_Wide]F_UUID}
		[Bench_Wide]F_UUID:="00000000000000000000000000000000"
		$f.actual.zero_reads_as:=[Bench_Wide]F_UUID
		$f.actual.zero_is_null:=Is field value Null([Bench_Wide]F_UUID)
		[Bench_Wide]F_UUID:=""
		$f.actual.empty_string_reads_as:=[Bench_Wide]F_UUID
		$f.pass:=($f.actual.null_reads_as#$f.actual.zero_reads_as)
	Else
		$f.actual:="no sampled Bench_Wide record has a null F_UUID"
	End if
Catch
	$f.error:=Last errors
End try
UNLOAD RECORD([Bench_Wide])
READ WRITE([Bench_Wide])
$facts.push($f)

// ## Fact 3: a lone surrogate survives UTF-8
$f:={fact: 3; spec: "09"; expected: "a lone U+D800 comes back unchanged from CONVERT FROM TEXT and Convert to text with UTF-8"; pass: False}
Try
	$t:="a"+Char(55296)+"b"  // 55296 = U+D800
	CONVERT FROM TEXT($t; "UTF-8"; $blob)
	$back:=Convert to text($blob; "UTF-8")
	$sent:=[]
	For ($i; 1; Length($t))
		$sent.push(Character code($t[[$i]]))
	End for
	$received:=[]
	For ($i; 1; Length($back))
		$received.push(Character code($back[[$i]]))
	End for
	$bytes:=[]
	For ($i; 0; BLOB size($blob)-1)
		$bytes.push($blob{$i})
	End for
	$f.actual:={sent: $sent; utf8_bytes: $bytes; received: $received}
	$f.pass:=(JSON Stringify($sent)=JSON Stringify($received))
Catch
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fill the spike tables (facts 4–7)
TRUNCATE TABLE([Spike_Keys])
TRUNCATE TABLE([Spike_TextKey])
SET DATABASE PARAMETER([Spike_Keys]; Table sequence number; 0)
// case variants, accents, @, trailing and leading spaces, digits. Keys equal under 4D's comparison are rejected as duplicates
$keys:=["a"; "A1"; "a2"; "a10"; "B"; "b1"; "c"; "e"; "é"; "f"; "u"; "ü"; "ss"; "ß"; "ae"; "æ"; "@"; "a@"; "@b"; "a@b"; "a "; "a  "; " a"; "ab"; "a-b"; "-a"; "_a"; "1"; "2"; "10"; "Z"; "z1"]
$rejected:={Spike_Keys: []; Spike_TextKey: []}
$i:=0
For each ($key_value; $keys)
	$i:=$i+1
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:=$key_value
	[Spike_Keys]Alt_Code:="k"+String($i)
	$errors:=__Spike_Save(->[Spike_Keys])
	If ($errors.length>0)
		$rejected.Spike_Keys.push($key_value)
	End if
	CREATE RECORD([Spike_TextKey])
	[Spike_TextKey]PK:=$key_value
	$errors:=__Spike_Save(->[Spike_TextKey])
	If ($errors.length>0)
		$rejected.Spike_TextKey.push($key_value)
	End if
End for each
For each ($y; [0; 1; 50; 99; 100; 9999; 10000; 32767])  // 0 is the blank date
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:="date_"+String($y)
	[Spike_Keys]Alt_Code:="date_"+String($y)
	[Spike_Keys]F_Date:=($y=0) ? !00-00-00! : Add to date(!00-00-00!; $y; 6; 15)
	__Spike_Save(->[Spike_Keys])
End for each
CREATE RECORD([Spike_Keys])
[Spike_Keys]PK:="null_uuid"
[Spike_Keys]Alt_Code:="null_uuid"
__Spike_Save(->[Spike_Keys])
UNLOAD RECORD([Spike_Keys])
UNLOAD RECORD([Spike_TextKey])
$spike:=[{name: "Spike_Keys"; table: ->[Spike_Keys]; key: ->[Spike_Keys]PK}; {name: "Spike_TextKey"; table: ->[Spike_TextKey]; key: ->[Spike_TextKey]PK}]

// ## Fact 4: dates survive yyyymmdd as a 4-byte integer
$f:={fact: 4; spec: "09"; expected: "each stored date, including years 1–99 and over 9999, comes back the same through yyyymmdd as a 4-byte integer"; pass: True; actual: []}
Try
	QUERY([Spike_Keys]; [Spike_Keys]PK="date_@")
	While (Not(End selection([Spike_Keys])))
		$d:=[Spike_Keys]F_Date
		$n:=(Year of($d)*10000)+(Month of($d)*100)+Day of($d)
		LONGINT TO BLOB($n; $blob; PC byte ordering)
		$n:=BLOB to longint($blob; PC byte ordering)
		$d2:=Add to date(!00-00-00!; $n\10000; ($n\100)%100; $n%100)
		$f.actual.push({key: [Spike_Keys]PK; stored: String(Year of($d))+"-"+String(Month of($d))+"-"+String(Day of($d)); yyyymmdd: $n; round_trip: ($d2=$d)})
		$f.pass:=$f.pass & ($d2=$d)
		NEXT RECORD([Spike_Keys])
	End while
	UNLOAD RECORD([Spike_Keys])
Catch
	$f.pass:=False
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 5: the < operator orders keys as ORDER BY on the primary-key index does
$f:={fact: 5; spec: "08"; expected: "walking each table in ORDER BY order on its primary key, each key is < the next"; pass: True; actual: {rejected_as_duplicates: $rejected}}
Try
	For each ($s; $spike.concat([{name: "Bench_Text"; table: ->[Bench_Text]; key: ->[Bench_Text]ID}]))
		$table:=$s.table
		$key:=$s.key
		ALL RECORDS($table->)
		ORDER BY($table->; $key->; >)
		SELECTION TO ARRAY($key->; $sorted)
		UNLOAD RECORD($table->)
		$bad:=[]
		For ($i; 1; Size of array($sorted)-1)
			If (Not($sorted{$i}<$sorted{$i+1}))
				$bad.push([$sorted{$i}; $sorted{$i+1}])
			End if
		End for
		$f.actual[$s.name]:={keys: Size of array($sorted); not_in_order: $bad.length; first_pairs_not_in_order: $bad.slice(0; 20)}
		If ($s.name#"Bench_Text")
			$rows:=[]
			ARRAY TO COLLECTION($rows; $sorted)
			$f.actual[$s.name].order_by:=$rows
		End if
		$f.pass:=$f.pass & (Size of array($sorted)>0) & ($bad.length=0)
	End for each
Catch
	$f.pass:=False
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 6: QUERY with >= and < doesn't treat @ in an Alpha key as a wildcard
$f:={fact: 6; spec: "10"; expected: "QUERY key >= from & key < to counts the same records as a scan with <, when the keys and bounds contain @"; pass: True; actual: []}
Try
	For each ($s; $spike)
		$table:=$s.table
		$key:=$s.key
		ALL RECORDS($table->)
		SELECTION TO ARRAY($key->; $all)
		For each ($b; [["@"; "b"]; ["a@"; "b"]; ["a"; "a@b"]; ["0"; "@b"]; ["a@"; "a@b"]])
			$lo:=$b[0]
			$hi:=$b[1]
			QUERY($table->; $key->>=$lo; *)
			QUERY($table->; & ; $key-><$hi)
			$n:=0
			For ($i; 1; Size of array($all))
				If (Not($all{$i}<$lo) & ($all{$i}<$hi))
					$n:=$n+1
				End if
			End for
			$f.actual.push({table: $s.name; from: $lo; to: $hi; query: Records in selection($table->); scan: $n})
			$f.pass:=$f.pass & (Records in selection($table->)=$n)
		End for each
		UNLOAD RECORD($table->)
	End for each
Catch
	$f.pass:=False
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 7: an engine query finds a null Auto UUID without generating one; loading generates one
$f:={fact: 7; spec: "09"; expected: "the ORDA and SQL queries find the null Auto UUID, and loading the record reads a generated UUID"; pass: False; actual: {}}
Try
	Begin SQL
		UPDATE Spike_Keys SET Auto_UUID = NULL WHERE PK = 'null_uuid';
	End SQL
	$f.actual.orda_query:=ds.Spike_Keys.query("Auto_UUID = null").length
	Begin SQL
		SELECT COUNT(*) FROM Spike_Keys WHERE Auto_UUID IS NULL INTO :$n;
	End SQL
	$f.actual.sql_query_after_orda:=$n
	QUERY([Spike_Keys]; [Spike_Keys]PK="null_uuid")
	$f.actual.loaded_reads_as:=[Spike_Keys]Auto_UUID
	UNLOAD RECORD([Spike_Keys])
	$f.actual.orda_query_after_load:=ds.Spike_Keys.query("Auto_UUID = null").length
	$f.pass:=($f.actual.orda_query=1) & ($f.actual.sql_query_after_orda=1) & ($f.actual.loaded_reads_as#"") & ($f.actual.loaded_reads_as#"00000000000000000000000000000000")
Catch
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 8: EXPORT STRUCTURE writes never_null on every field, or doesn't
$f:={fact: 8; spec: "05"; expected: "every <field> element of EXPORT STRUCTURE has a never_null attribute"; pass: False; actual: {fields: 0; with_never_null: 0}}
Try
	EXPORT STRUCTURE($xml)
	$start:=1
	While (Match regex("<field [^>]*>"; $xml; $start; $pos; $len))
		$element:=Substring($xml; $pos; $len)
		$f.actual.fields:=$f.actual.fields+1
		$f.actual.with_never_null:=$f.actual.with_never_null+Num(Position("never_null="; $element)>0)
		If (Position("name=\"F_Bool\""; $element)>0)
			$f.actual.bench_wide_f_bool:=$element  // never_null off in the catalog
		End if
		$start:=$pos+$len
	End while
	$f.pass:=($f.actual.fields>0) & ($f.actual.with_never_null=$f.actual.fields)
Catch
	$f.error:=Last errors
End try
$facts.push($f)

// ## Fact 9: a class instance passed through CALL WORKER keeps its class
$f:={fact: 9; spec: "12"; expected: "in the worker, OB Instance of(job; cs.__SpikeProbe) is True and job.hello() works"; pass: False}
Try
	$probe:=cs.__SpikeProbe.new("fact 9")
	$f.actual:=__Spike_Call_Worker("probe"; $probe)
	$f.pass:=($f.actual.instance_of=True) & ($f.actual.hello="hello fact 9")
Catch
	$f.error:=Last errors
End try
KILL WORKER("__Spike")
$facts.push($f)

__Spike_Save_Result(Current method name; $facts)
