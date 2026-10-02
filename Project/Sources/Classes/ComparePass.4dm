// cs.ComparePass
//
// Compare (specs 08 and 10): an export set against this datafile, in one
// phase. check() is the manifest's pre-flight (_Manifest). It allows the
// set's source datafile, so a self-check of an export set works (spec 06).
// The run report and run log go into the set, or next to the datafile when
// there is no set.
//   compare: each table's segment order is checked under this datafile's <
//     (spec 10), then the _CompareJobs, each a run of one table's segments
//     (the planner), with a table out of order as one job. Then each
//     table's record count and sequence number (selector 31, read here: it
//     isn't thread-safe).
// The result adds discrepancies, unverified (target records, {table; kind;
// key; reason}) and unverified_ranges (see _CompareJob), in table and key
// order. Per table, discrepancies and unverified list the first
// detail_limit records in key order between them. Each list then says how
// many more it has, {table; key: Null; not_listed}, and discrepancies end
// with the record count and the sequence number. Once any job of a table
// breaks its order guard, every extra of the table is unverified, except a
// key that contains @ (spec 16): a source key past the break may match it.
// Any discrepancy gives notExact. Otherwise, anything unverified gives
// inconclusive, else exact.
//
// Options: workers (2 by default, spec 15) and detail_limit (spec 12).
// Rows add expected, actual, matched, missing, extra, changed, duplicate,
// unverified, sequence_expected and sequence_actual.

Class extends _Pass

property _manifest : cs._Manifest

Class constructor($path : Text; $options : Object)
	// $path: the export set's platform path.
	Super("compare"; "Compare"; $options)
	This._phase_count:=1
	This._default_workers:=2
	This._manifest:=cs._Manifest.new($path)


Function check() : Object
	var $check; $manifest : Object
	$check:=Super.check()
	$manifest:=This._manifest.check()
	$check.problems.combine($manifest.problems)
	$check.cautions.combine($manifest.cautions)
	return $check


Function run() : Object
	var $set : 4D.Folder
	$set:=(This._manifest.path="") ? Null : Try(Folder(This._manifest.path; fk platform path))
	If ($set#Null) && ($set.exists)
		This._folder:=$set
	End if
	return Super.run()


Function _envelope() : Object
	var $result : Object
	$result:=Super._envelope()
	$result.export_set:=This._manifest.path
	$result.discrepancies:=[]
	$result.unverified:=[]
	$result.unverified_ranges:=[]
	return $result


Function _columns() : Collection
	return ["expected"; "actual"; "matched"; "missing"; "extra"; "changed"; "duplicate"; "unverified"; "sequence_expected"; "sequence_actual"; "elapsed"]


Function _sections() : Text
	// The unverified ranges, counts only (spec 13).
	var $r : Object
	var $keys; $text : Text
	For each ($r; This.result.unverified_ranges)
		If ($r.inclusive)
			$keys:=JSON Stringify($r.from)+" to "+JSON Stringify($r.to)
		Else
			$keys:=(($r.from=Null) ? "from the start" : ("after "+JSON Stringify($r.from)))+(($r.to=Null) ? " to the end" : (", before "+JSON Stringify($r.to)))
		End if
		$text+="  ["+$r.table+"]  keys "+$keys+", "+String($r.source_records)+" in the set and "+String($r.target_records)+" in this datafile: "+$r.reason+"\n"
	End for each
	return ($text="") ? "" : ("Unverified ranges\n"+$text)


Function _failed_step() : Text
	return "See the failure, then run Compare again. If it fails again, treat the target as unusable."


Function _run()
	var $jobs; $ordered; $whole; $found; $listed; $records : Collection
	var $set : 4D.Folder
	var $entry; $job; $out; $row; $extra : Object
	var $count; $n : Integer
	This._phase("compare"; "Run Compare again.")
	$set:=Folder(This._manifest.path; fk platform path)
	$ordered:=[]
	$whole:=[]
	For each ($entry; This._manifest.content.tables)
		If (This._in_order($entry.segments))
			$ordered.push($entry)
		Else   // one job, whose order guard finds the break (spec 10)
			$whole.push($entry)
		End if
	End for each
	$jobs:=cs._Planner.new(This._workers()).segments($ordered).combine(cs._Planner.new(1).segments($whole))
	For each ($job; $jobs)
		$job.folder:=$set.folder($job.table.folder).platformPath
		$job.detail_limit:=This._limit()
	End for each
	$out:=This._jobs("_CompareJob"; $jobs)
	For each ($entry; This._manifest.content.tables)
		$row:=$out.tables.query("number = :1"; $entry.number).first()
		$found:=$out.findings.query("table = :1"; $entry.name)
		If ($row.broke>0)  // spec 16: the extras become unverified, those whose key contains @ aside
			$n:=$row.extra-$row.extra_at
			$row.extra-=$n
			$row.found-=$n
			$row.unverified+=$n
			For each ($extra; $found.query("kind = :1"; "extra"))
				If (Value type($extra.key)#Is text) || (Position("@"; $extra.key; 1; *)=0)
					$extra.kind:="unverified"
					$extra.reason:="a source key after the order guard break in this table may match it"
				End if
			End for each
		End if
		This.result.unverified_ranges.combine($found.query("kind = :1"; "range"))
		$listed:=$found.query("kind # :1"; "range").slice(0; This._limit())  // the table's first records in key order, of both lists
		$records:=$listed.query("kind = :1"; "unverified")
		This.result.unverified.combine($records)
		If ($row.unverified>$records.length)
			This.result.unverified.push({table: $entry.name; key: Null; not_listed: $row.unverified-$records.length})
		End if
		$records:=$listed.query("kind # :1"; "unverified")
		This.result.discrepancies.combine($records)
		If ($row.found>$records.length)
			This.result.discrepancies.push({table: $entry.name; key: Null; not_listed: $row.found-$records.length})
		End if
		OB REMOVE($row; "records")
		OB REMOVE($row; "found")
		OB REMOVE($row; "broke")
		OB REMOVE($row; "extra_at")
		$row.expected:=$entry.records
		$row.actual:=Records in table(Table($entry.number)->)
		$row.sequence_expected:=$entry.sequence_number  // after the pool: it would add up a table's jobs
		$row.sequence_actual:=Get database parameter(Table($entry.number)->; Table sequence number)
		$count+=$row.missing+$row.extra+$row.changed+$row.duplicate
		If ($row.actual#$row.expected)
			This.result.discrepancies.push({table: $entry.name; kind: "record_count"; expected: $row.expected; actual: $row.actual})
			$count+=1
		End if
		If ($row.sequence_actual#$row.sequence_expected)
			This.result.discrepancies.push({table: $entry.name; kind: "sequence_number"; expected: $row.sequence_expected; actual: $row.sequence_actual})
			$count+=1
		End if
	End for each
	This.result.tables:=$out.tables
	Case of
		: ($count>0)
			This.result.verdict:="notExact"
			This.result.next_step:="The target is unusable. Recreate it, then run the import again."
		: (This.result.unverified_ranges.length>0) || (This.result.tables.sum("unverified")>0)
			This.result.verdict:="inconclusive"
			This.result.next_step:="Some records are unverified: see the unverified ranges and records. Fix their cause (a damaged export set, keys that the two datafiles order differently, or target records that can't be read), then run Compare again."
		Else
			This.result.verdict:="exact"
			This.result.next_step:="The copy is verified. Make a full backup and turn the log file back on."
	End case


Function _in_order($segments : Collection) : Boolean
	// Spec 10's check before dispatch, under this datafile's <: each
	// segment's first_key <= its last_key < the next one's first_key. No key
	// contains @, which < reads as a wildcard: the export refuses one.
	var $i : Integer
	For ($i; 0; $segments.length-1)
		If ($segments[$i].last_key<$segments[$i].first_key) || (($i>0) && Not($segments[$i-1].last_key<$segments[$i].first_key))
			return False
		End if
	End for
	return True
