//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Export_Set (result) : check
//
// DESCRIPTION
//   DEV ONLY. For __Check_Export: an export's set read back against its
//   manifest and the datafile. Per table: the manifest's records against
//   Records in table and its segments, and the files in its folder. Per
//   segment: its name (the position of its first record), the file's size,
//   the records its framing holds, the cap, and its first and last keys
//   decoded with _Codec. Then every segment's SHA-256 with shasum -a 256 -c.
//
#DECLARE($result : Object) : Object
var $check; $manifest; $entry; $s; $t : Object
var $set; $folder : 4D.Folder
var $sums : 4D.File
var $codec : cs._Codec
var $blob : Blob
var $lines; $out_lines : Collection
var $in; $out; $err; $problem : Text
var $cap : Real
var $position; $o; $len; $last; $k : Integer

$set:=Folder($result.export_set; fk platform path)
$check:={manifest: $set.file("manifest.json").exists; tables: []; problems: []; ok: False}
If (Not($check.manifest))
	return $check
End if
$manifest:=JSON Parse($set.file("manifest.json").getText())
$check.content:={component_version: $manifest.component_version; app_version: $manifest.app_version; started: $manifest.started; ended: $manifest.ended; settings: $manifest.settings; source: $manifest.source; language: $manifest.language; signature: $manifest.signature; structure_tables: $manifest.structure.length; tables: $manifest.tables.length}
$cap:=$manifest.settings.segment_mb*1048576
$lines:=[]
For each ($entry; $manifest.tables)
	$folder:=$set.folder($entry.folder)
	$t:={name: $entry.name; records: $entry.records; in_datafile: Records in table(Table($entry.number)->); sequence_number: $entry.sequence_number; segments: $entry.segments.length; bytes: $entry.segments.sum("bytes"); files: $folder.exists ? $folder.files(fk ignore invisible).length : 0}
	If ($entry.records#$t.in_datafile) | ($entry.segments.sum("records")#$entry.records) | ($t.files#$t.segments) | ($folder.exists#($t.segments>0))
		$check.problems.push("["+$entry.name+"] counts: "+JSON Stringify($t))
	End if
	If ($entry.primary_key#0)
		$codec:=cs._Codec.new($entry)
	End if
	$position:=0
	For each ($s; $entry.segments)
		$blob:=$folder.file($s.file).getContent()
		$o:=0
		$k:=0
		While ($o<BLOB size($blob))
			$len:=BLOB to longint($blob; PC byte ordering; $o)  // moves $o past the length
			$last:=$o
			$o+=$len
			$k+=1
		End while
		Case of
			: ($s.file#(String($position; "000000000000")+".seg"))
				$problem:="named "+$s.file+", not by its position "+String($position)
			: (BLOB size($blob)#$s.bytes)
				$problem:="the file has "+String(BLOB size($blob))+" bytes, not "+String($s.bytes)
			: ($o#BLOB size($blob))
				$problem:="the framing ends at "+String($o)+", not at the end of the file"
			: ($k#$s.records)
				$problem:="the framing holds "+String($k)+" records, not "+String($s.records)
			: ($s.bytes>$cap) & ($s.records>1)
				$problem:="past the cap with "+String($s.records)+" records"
			: (Compare strings(JSON Stringify($codec.key(->$blob; 4).value); JSON Stringify($s.first_key); sk char codes)#0)
				$problem:="first_key "+JSON Stringify($s.first_key)+" but the first record's key is "+JSON Stringify($codec.key(->$blob; 4).value)
			: (Compare strings(JSON Stringify($codec.key(->$blob; $last).value); JSON Stringify($s.last_key); sk char codes)#0)
				$problem:="last_key "+JSON Stringify($s.last_key)+" but the last record's key is "+JSON Stringify($codec.key(->$blob; $last).value)
			Else
				$problem:=""
		End case
		If ($problem#"")
			$check.problems.push("["+$entry.name+"] "+$s.file+": "+$problem)
		End if
		$lines.push($s.sha256+"  "+$folder.file($s.file).path)
		$position+=$s.records
	End for each
	$check.tables.push($t)
End for each

$sums:=Folder(Temporary folder; fk platform path).file("__Check_Export.sha256")
$sums.setText($lines.join("\n")+"\n"; "UTF-8-no-bom"; Document with LF)
LAUNCH EXTERNAL PROCESS("/usr/bin/shasum -a 256 -c "+$sums.path; $in; $out; $err)
$out_lines:=Split string($out; "\n"; sk ignore empty strings)
$check.shasum:={segments: $lines.length; ok: $out_lines.filter(Formula($1.result:=($1.value="@: OK"))).length; not_ok: $out_lines.filter(Formula($1.result:=($1.value#"@: OK"))); error: $err}
$check.ok:=($check.problems.length=0) && ($check.shasum.ok=$lines.length)
return $check
