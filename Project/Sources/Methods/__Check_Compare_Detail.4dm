//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Compare_Detail
//
// DESCRIPTION
//   DEV ONLY. Ticket 10's check, on the bench datafile (__Bench_Generate),
//   compiled:
//   - damaged: the newest every-table export set next to the datafile
//     (ticket 09's), with one byte of [Bench_Wide]'s middle segment
//     changed and the segment two after it moved away. Compare gives
//     inconclusive: two unverified ranges, each its segment's first_key to
//     last_key with its record count on both sides, those records
//     unverified and every other record matched, and every other table
//     exact. The set is put back after;
//   - values: [Bench_Small_01], [Bench_Small_02] and [Bench_Blob] exported
//     once [Bench_Small_01]'s first record holds an Amount of 0. Then that
//     Amount becomes -0, the second record's Name gains a trailing space,
//     the third record's Note gets a lone surrogate (it can't be encoded),
//     Active flips on all 2,000 records of [Bench_Small_02], and one byte
//     of [Bench_Blob]'s first non-empty Payload changes. Compare gives
//     notExact: 0 against -0 with both slices in hex, the Name as JSON
//     strings with the trailing space and first_difference, the Payload as
//     its length and SHA-256, the third record unverified, and 1000 of
//     [Bench_Small_02]'s 2000 changed records listed, then "1000 more not
//     listed". Every value is put back and the set deleted after;
//   - order: [Spike_Keys] exported, then the two middle records of its
//     segment swapped, and the segment's sha256 in the manifest updated.
//     The order guard breaks at the first of them: an unverified range
//     after the second to the end of the table. The first also reads as
//     extra: the guard only sees the break once the merge has passed it
//     (see the ticket). The set is deleted after.
//   Writes .scratch/exact-copy-v2-build/research/10-__Check_Compare_Detail-<compiled|interpreted>.json,
//   and copies the damaged run's report there as 10-Compare-damaged-<…>.json.
//
var $result; $r; $manifest; $entry; $s; $row; $d; $p; $range; $sum : Object
var $structure : cs._Structure
var $codec : cs._Codec
var $set; $wide; $folder; $research : 4D.Folder
var $file; $moved : 4D.File
var $blob; $b : Blob
var $mode; $path; $name; $note; $sha : Text
var $amount; $zero : Real
var $ids; $planted; $parts; $keys : Collection
var $i; $m; $k; $at; $o; $len; $blob_id : Integer
var $ok : Boolean

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores}
$mode:=Is compiled mode ? "compiled" : "interpreted"
$research:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$structure:=cs._Structure.new()

// ## Damaged: one byte of [Bench_Wide]'s middle segment changed, and the segment two after it moved away
For each ($folder; File(Data file; fk platform path).parent.folders())
	If ($folder.name="Export @") && ($folder.file("manifest.json").exists) && (($set=Null) || ($folder.name>$set.name))
		If (JSON Parse($folder.file("manifest.json").getText()).tables.length=$structure.tables.length)
			$set:=$folder
		End if
	End if
End for each
If ($set=Null)
	ALERT(Current method name+": no export set of every table next to the datafile. Run __Check_Compare first.")
	return
End if
$manifest:=JSON Parse($set.file("manifest.json").getText())
$entry:=$manifest.tables.query("name = :1"; "Bench_Wide").first()
$wide:=$set.folder($entry.folder)
$m:=$entry.segments.length\2
$planted:=[]
For ($i; $m; $m+2; 2)
	$s:=$entry.segments[$i]
	$planted.push({file: $s.file; records: $s.records; first_key: $s.first_key; last_key: $s.last_key})
End for
$file:=$wide.file($entry.segments[$m].file)
$blob:=$file.getContent()
$at:=BLOB size($blob)\2
$blob{$at}:=255-$blob{$at}
$file.setContent($blob)
$moved:=$wide.file($entry.segments[$m+2].file).rename($entry.segments[$m+2].file+".moved")

$r:=cs.ComparePass.new($set.platformPath).run()

$blob{$at}:=255-$blob{$at}
$file.setContent($blob)
$moved.rename($entry.segments[$m+2].file)
$result.damaged:=__Check_Pass_Files($r)
$result.damaged.export_set:=$set.name
$result.damaged.planted:=$planted
$result.damaged.ranges:=$r.unverified_ranges
$result.damaged.unverified:=$r.unverified.slice(0; 3).combine($r.unverified.query("not_listed > 0"))
$result.damaged.discrepancies:=$r.discrepancies.slice(0; 50)
$row:=$r.tables.query("name = :1"; "Bench_Wide").first()
$result.damaged.row:=$row
$ok:=($r.verdict="inconclusive") && ($r.discrepancies.length=0) && ($r.unverified_ranges.length=2) && ($row#Null) \
 && ($row.unverified=$planted.sum("records")) && ($row.matched=($row.expected-$row.unverified)) && ($row.actual=$row.expected) \
 && ($r.unverified.length=1001) && (Num($r.unverified[1000].not_listed)=($row.unverified-1000)) \
 && ($r.tables.query("unverified = 0 AND missing = 0 AND extra = 0 AND changed = 0 AND duplicate = 0").length=($r.tables.length-1)) \
 && ($r.tables.sum("matched")=($r.tables.sum("expected")-$row.unverified))
For ($i; 0; [$r.unverified_ranges.length; 2].min()-1)
	$range:=$r.unverified_ranges[$i]
	$ok:=$ok && ($range.table="Bench_Wide") && $range.inclusive && ($range.source_records=$planted[$i].records) && ($range.target_records=$planted[$i].records) \
	 && (JSON Stringify($range.from)=JSON Stringify($planted[$i].first_key)) && (JSON Stringify($range.to)=JSON Stringify($planted[$i].last_key)) \
	 && (Position(($i=0) ? "doesn't match its SHA-256" : "is missing"; $range.reason)>0)
End for
$result.damaged.ok:=$ok
If ($r.report#"")
	$file:=File($r.report; fk platform path)
	$file.parent.file($file.name+".json").copyTo($research; "10-Compare-damaged-"+$mode+".json"; fk overwrite)
End if

// ## Values: -0, a trailing space, a BLOB, a record that can't be encoded, and 2000 changed records
READ WRITE([Bench_Small_01])
READ WRITE([Bench_Small_02])
READ WRITE([Bench_Blob])
ALL RECORDS([Bench_Small_01])
ORDER BY([Bench_Small_01]; [Bench_Small_01]ID; >)
$ids:=[]
For ($i; 1; 3)
	GOTO SELECTED RECORD([Bench_Small_01]; $i)
	$ids.push([Bench_Small_01]ID)
End for
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[0])
$amount:=[Bench_Small_01]Amount
[Bench_Small_01]Amount:=0
SAVE RECORD([Bench_Small_01])
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[1])
$name:=[Bench_Small_01]Name
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[2])
$note:=[Bench_Small_01]Note
UNLOAD RECORD([Bench_Small_01])
ALL RECORDS([Bench_Blob])
ORDER BY([Bench_Blob]; [Bench_Blob]ID; >)
$i:=1
GOTO SELECTED RECORD([Bench_Blob]; $i)
While (BLOB size([Bench_Blob]Payload)=0)
	$i+=1
	GOTO SELECTED RECORD([Bench_Blob]; $i)
End while
$blob_id:=[Bench_Blob]ID
$blob:=[Bench_Blob]Payload
$sha:=Generate digest($blob; SHA256 digest)
UNLOAD RECORD([Bench_Blob])

$r:=cs.ExportPass.new({tables: [Table(->[Bench_Small_01]); Table(->[Bench_Small_02]); Table(->[Bench_Blob])]}).run()
$result.values:={export: $r.verdict; problems: $r.problems; ids: $ids; blob_id: $blob_id}
$path:=$r.export_set

QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[0])
$zero:=0
[Bench_Small_01]Amount:=-1*$zero
SAVE RECORD([Bench_Small_01])
UNLOAD RECORD([Bench_Small_01])
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[0])
SET BLOB SIZE($b; 0)
REAL TO BLOB([Bench_Small_01]Amount; $b; PC double real format)
$result.values.minus_zero_kept:=($b{7}=128)
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[1])
[Bench_Small_01]Name:=$name+" "
SAVE RECORD([Bench_Small_01])
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[2])
[Bench_Small_01]Note:="a"+Char(55296)+"b"
SAVE RECORD([Bench_Small_01])
UNLOAD RECORD([Bench_Small_01])
ALL RECORDS([Bench_Small_02])
APPLY TO SELECTION([Bench_Small_02]; [Bench_Small_02]Active:=Not([Bench_Small_02]Active))
UNLOAD RECORD([Bench_Small_02])
QUERY([Bench_Blob]; [Bench_Blob]ID=$blob_id)
$b:=$blob
$b{0}:=255-$b{0}
[Bench_Blob]Payload:=$b
SAVE RECORD([Bench_Blob])
UNLOAD RECORD([Bench_Blob])

$r:=cs.ComparePass.new($path).run()
$result.values.compare:=__Check_Pass_Files($r)
$result.values.discrepancies:=$r.discrepancies.query("table # :1"; "Bench_Small_02").combine($r.discrepancies.query("table = :1"; "Bench_Small_02").slice(0; 2)).combine($r.discrepancies.query("not_listed > 0"))
$result.values.unverified:=$r.unverified
$result.values.rows:=$r.tables
$sum:={}
$d:=$r.discrepancies.query("table = :1 AND key = :2"; "Bench_Small_01"; $ids[0]).first()
$sum.minus_zero:=($d#Null) && ($d.fields.length=1) && ($d.fields[0].name="Amount") && ($d.fields[0].source_hex="0000000000000000") && ($d.fields[0].target_hex="0000000000000080")
$d:=$r.discrepancies.query("table = :1 AND key = :2"; "Bench_Small_01"; $ids[1]).first()
$sum.trailing_space:=($d#Null) && ($d.fields.length=1) && ($d.fields[0].name="Name") && (Compare strings($d.fields[0].target; $name+" "; sk char codes)=0) \
 && ($d.fields[0].target_length=(Length($name)+1)) && ($d.fields[0].first_difference=(Length($name)+1)) && ($d.fields[0].source_hex=Null)
$d:=$r.discrepancies.query("table = :1 AND key = :2"; "Bench_Blob"; $blob_id).first()
$sum.blob:=($d#Null) && ($d.fields.length=1) && ($d.fields[0].name="Payload") && ($d.fields[0].source.bytes=BLOB size($blob)) && ($d.fields[0].target.bytes=BLOB size($blob)) \
 && ($d.fields[0].source.sha256=$sha) && ($d.fields[0].target.sha256#$sha)
$sum.unreadable:=($r.unverified.length=1) && ($r.unverified[0].table="Bench_Small_01") && ($r.unverified[0].key=$ids[2]) && (Position("lone surrogate"; $r.unverified[0].reason)>0) \
 && ($r.unverified_ranges.length=0)
$row:=$r.tables.query("name = :1"; "Bench_Small_02").first()
$sum.cap:=($row#Null) && ($row.changed=2000) && ($r.discrepancies.query("table = :1 AND kind = :2"; "Bench_Small_02"; "changed").length=1000) \
 && ($r.discrepancies.query("table = :1 AND not_listed = :2"; "Bench_Small_02"; 1000).length=1)
$result.values.checks:=$sum
$result.values.ok:=($r.verdict="notExact") && $sum.minus_zero && $sum.trailing_space && $sum.blob && $sum.unreadable && $sum.cap

QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[0])
[Bench_Small_01]Amount:=$amount
SAVE RECORD([Bench_Small_01])
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[1])
[Bench_Small_01]Name:=$name
SAVE RECORD([Bench_Small_01])
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[2])
[Bench_Small_01]Note:=$note
SAVE RECORD([Bench_Small_01])
UNLOAD RECORD([Bench_Small_01])
ALL RECORDS([Bench_Small_02])
APPLY TO SELECTION([Bench_Small_02]; [Bench_Small_02]Active:=Not([Bench_Small_02]Active))
UNLOAD RECORD([Bench_Small_02])
QUERY([Bench_Blob]; [Bench_Blob]ID=$blob_id)
[Bench_Blob]Payload:=$blob
SAVE RECORD([Bench_Blob])
UNLOAD RECORD([Bench_Blob])
Folder($path; fk platform path).delete(Delete with contents)
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[0])
$ok:=([Bench_Small_01]Amount=$amount)
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[1])
$ok:=$ok && (Compare strings([Bench_Small_01]Name; $name; sk char codes)=0)
QUERY([Bench_Small_01]; [Bench_Small_01]ID=$ids[2])
$ok:=$ok && (Compare strings([Bench_Small_01]Note; $note; sk char codes)=0)
QUERY([Bench_Blob]; [Bench_Blob]ID=$blob_id)
$result.values.restored:=$ok && (Generate digest([Bench_Blob]Payload; SHA256 digest)=$sha)
UNLOAD RECORD([Bench_Small_01])
UNLOAD RECORD([Bench_Blob])

// ## Order: the two middle records of [Spike_Keys]'s segment swapped
$r:=cs.ExportPass.new({tables: [Table(->[Spike_Keys])]}).run()
$result.order:={export: $r.verdict; problems: $r.problems}
$path:=$r.export_set
$manifest:=JSON Parse(Folder($path; fk platform path).file("manifest.json").getText())
$entry:=$manifest.tables.first()
$s:=$entry.segments.first()
$file:=Folder($path; fk platform path).folder($entry.folder).file($s.file)
$blob:=$file.getContent()
$parts:=[]  // each record: its offset and size, its length included
$o:=0
While ($o<BLOB size($blob))
	$at:=$o
	$len:=BLOB to longint($blob; PC byte ordering; $o)
	$parts.push({at: $at; size: 4+$len})
	$o+=$len
End while
$codec:=cs._Codec.new($entry)
$keys:=[]
For each ($p; $parts)
	$keys.push($codec.key(->$blob; $p.at+4).value)
End for each
$k:=$parts.length\2
$p:=$parts[$k]
$parts[$k]:=$parts[$k-1]
$parts[$k-1]:=$p
SET BLOB SIZE($b; BLOB size($blob))
$o:=0
For each ($p; $parts)
	COPY BLOB($blob; $b; $p.at; $o; $p.size)
	$o+=$p.size
End for each
$file.setContent($b)
$s.sha256:=Generate digest($b; SHA256 digest)
Folder($path; fk platform path).file("manifest.json").setText(JSON Stringify($manifest; *); "UTF-8-no-bom"; Document with LF)

$r:=cs.ComparePass.new($path).run()
$result.order.compare:=__Check_Pass_Files($r)
$result.order.swapped:=[$keys[$k-1]; $keys[$k]]
$result.order.discrepancies:=$r.discrepancies
$result.order.ranges:=$r.unverified_ranges
$row:=$r.tables.first()
$result.order.row:=$row
$range:=$r.unverified_ranges.first()
$result.order.ok:=($range#Null) && ($r.unverified_ranges.length=1) && Not($range.inclusive) && (JSON Stringify($range.from)=JSON Stringify($keys[$k])) && ($range.to=Null) \
 && ($range.source_records=($parts.length-$k)) && ($range.target_records=($parts.length-$k-1)) && (Position("order keys differently"; $range.reason)>0) \
 && ($row.matched=$k) && ($row.unverified=($parts.length-$k-1)) && ($row.missing=0)
$result.order.false_extra:=($r.verdict="notExact") && ($row.extra=1) && (JSON Stringify($r.discrepancies.query("kind = :1"; "extra").first().key)=JSON Stringify($keys[$k-1]))
Folder($path; fk platform path).delete(Delete with contents)

$result.summary:={\
damaged: $result.damaged.verdict+(($result.damaged.ok) ? ", two ranges of [Bench_Wide], the rest matched" : ", NOT as expected"); \
values: $result.values.compare.verdict+(($result.values.ok) ? ", -0 in hex, trailing space, BLOB, unreadable record and the cap as expected" : ", NOT as expected: "+JSON Stringify($result.values.checks))+((Bool($result.values.minus_zero_kept)) ? "" : ", -0 NOT kept by 4D"); \
order: $result.order.compare.verdict+(($result.order.ok) ? ", the range after the swapped pair as expected" : ", NOT as expected")+(($result.order.false_extra) ? ", with the false extra" : ""); \
restored: $result.values.restored}
$file:=$research.file("10-"+Current method name+"-"+$mode+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+JSON Stringify($result.summary)+Char(Carriage return)+$file.path)
