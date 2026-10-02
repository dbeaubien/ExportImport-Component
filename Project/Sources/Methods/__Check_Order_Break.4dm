//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Order_Break
//
// DESCRIPTION
//   DEV ONLY. Ticket 22's check, compiled, on a datafile from
//   __Bench_Generate (ticket 21 runs it on its small datafile):
//   [Bench_Small_01] exported, then the two middle records of its segment
//   swapped, and the segment's sha256 in the manifest updated. The order
//   guard breaks at the second of them: an unverified range after the
//   first to the end of the table. The merge passed the second as extra
//   before the break, so it is unverified too (spec 16): Compare gives
//   inconclusive, with no extra. The set is deleted after.
//   Writes .scratch/exact-copy-v2-build/research/22-__Check_Order_Break-<compiled|interpreted>.json.
//
var $result; $r; $manifest; $entry; $s; $p; $range; $row; $unverified : Object
var $codec : cs._Codec
var $set : 4D.Folder
var $file : 4D.File
var $blob; $b : Blob
var $mode : Text
var $parts; $keys : Collection
var $k; $o; $at; $len : Integer

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode}
$mode:=Is compiled mode ? "compiled" : "interpreted"

$r:=cs.ExportPass.new({tables: [Table(->[Bench_Small_01])]}).run()
$result.export:={verdict: $r.verdict; problems: $r.problems}
If ($r.verdict#"exported")
	ALERT(Current method name+": the export gave "+$r.verdict+": "+JSON Stringify($r.problems))
	return
End if
$set:=Folder($r.export_set; fk platform path)
$manifest:=JSON Parse($set.file("manifest.json").getText())
$entry:=$manifest.tables.first()
$s:=$entry.segments.first()
$result.segments:=$entry.segments.length  // the expectations below take one
$file:=$set.folder($entry.folder).file($s.file)
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
$set.file("manifest.json").setText(JSON Stringify($manifest; *); "UTF-8-no-bom"; Document with LF)

$r:=cs.ComparePass.new($set.platformPath).run()
$result.compare:={verdict: $r.verdict; problems: $r.problems; failure: $r.failure; report: $r.report}
$result.swapped:=[$keys[$k]; $keys[$k-1]]  // in the segment's new order
$result.discrepancies:=$r.discrepancies
$result.ranges:=$r.unverified_ranges
$result.unverified:=$r.unverified.slice(0; 3)
$row:=$r.tables.first()
$result.row:=$row
$range:=$r.unverified_ranges.first()
$result.range_ok:=($range#Null) && ($r.unverified_ranges.length=1) && Not($range.inclusive) && (JSON Stringify($range.from)=JSON Stringify($keys[$k])) && ($range.to=Null) \
 && ($range.source_records=($parts.length-$k)) && ($range.target_records=($parts.length-$k-1)) && (Position("order keys differently"; $range.reason)>0)
$unverified:=$r.unverified.first()
$result.extra_ok:=($unverified#Null) && (JSON Stringify($unverified.key)=JSON Stringify($keys[$k-1])) \
 && ($unverified.reason="a source key after the order guard break in this table may match it")
$result.ok:=($r.verdict="inconclusive") && ($r.discrepancies.length=0) && $result.range_ok && $result.extra_ok \
 && ($row.matched=$k) && ($row.extra=0) && ($row.missing=0) && ($row.unverified=($parts.length-$k)) && ($row.broke=Null) && ($row.extra_at=Null)
$set.delete(Delete with contents)

$result.summary:=$r.verdict+(($result.ok) ? ", the second of the swapped pair unverified, extra 0, the range as before" : ", NOT as expected: range "+String($result.range_ok)+", unverified "+String($result.extra_ok))
$file:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research").file("22-"+Current method name+"-"+$mode+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+$result.summary+Char(Carriage return)+$file.path)
