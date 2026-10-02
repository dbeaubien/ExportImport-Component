// cs._Planner
//
// Cuts each table into jobs for _WorkerPool (spec 10), in the coordinator.
// The cut rule lives here and only here. A table's cost is its record count
// (spec 19), and the target job size is the run's total records ÷ the worker
// count. A table gets the smallest of ceil(records ÷ target), floor(records
// ÷ 50,000), the worker count and, for import and Compare, its segment
// count, and at least 1 job. Its records are shared out as evenly as possible.
//
// A job is a plain object: {table; low; high; start; expected}, plus
// segments for import and Compare. table is the table's _Structure entry (or
// manifest entry). low and high bound the keys, low <= key < high, and Null
// is an open end. start is the position of the job's first record in key
// order, and expected its record count. The pool queues jobs by expected.

property workers : Integer
property minimum : Integer  // records per job: 50,000. A constant, not an option

Class constructor($workers : Integer)
	This.workers:=$workers
	This.minimum:=50000


Function counts($sizes : Collection) : Collection
	// The job count of each table, from [{records; segments}], where segments
	// is the segment count, for import and Compare only.
	var $size : Object
	var $counts; $n : Collection
	var $total : Real
	$total:=$sizes.sum("records")
	$counts:=[]
	For each ($size; $sizes)
		$n:=[This.workers; Int($size.records/This.minimum)]
		If ($total>0)
			$n.push(-Int(-($size.records*This.workers/$total)))  // ceil(records ÷ target)
		End if
		If ($size.segments#Null)
			$n.push($size.segments)
		End if
		$counts.push([1; $n.min()].max())
	End for each
	return $counts


Function whole($tables : Collection) : Collection
	// One job per table, never split: the blocker gate (spec 10).
	var $table : Object
	var $jobs : Collection
	var $records : Integer
	$jobs:=[]
	For each ($table; $tables)
		$records:=Records in table(Table($table.number)->)
		$jobs.push({table: $table; low: Null; high: Null; start: 0; expected: $records})
	End for each
	return $jobs


Function source($tables : Collection) : Collection
	// Scan, fixer and export: each table cut into key ranges. The table is
	// sorted on its key once, and the key at each cut position bounds two
	// jobs. A table runs as one job if a cut key contains @, which QUERY reads
	// as a wildcard in a bound (spec 14), or if it has no primary key.
	var $table : Object
	var $jobs; $sizes; $counts; $keys : Collection
	var $sel : 4D.EntitySelection
	var $key : Text
	var $t; $i; $n; $records; $start; $end : Integer
	$sizes:=$tables.map(Formula($1.result:={records: Records in table(Table($1.value.number)->)}))
	$counts:=This.counts($sizes)
	$jobs:=[]
	For ($t; 0; $tables.length-1)
		$table:=$tables[$t]
		$records:=$sizes[$t].records
		$n:=($table.primary_key=0) ? 1 : $counts[$t]
		$keys:=[]
		If ($n>1)
			$key:=$table.fields.query("number = :1"; $table.primary_key).first().name
			$sel:=ds[$table.name].all().orderBy([{propertyPath: $key; descending: False}])  // ORDA: the host's current selection is left alone
			For ($i; 1; $n-1)
				$keys.push($sel[Int($i*$records/$n)][$key])
			End for
			If ($keys.some(Formula($1.result:=(Value type($1.value)=Is text) && (Position("@"; $1.value; 1; *)>0))))
				$n:=1
			End if
		End if
		For ($i; 0; $n-1)
			$start:=Int($i*$records/$n)
			$end:=Int(($i+1)*$records/$n)
			$jobs.push({table: $table; low: ($i=0) ? Null : $keys[$i-1]; high: ($i=($n-1)) ? Null : $keys[$i]; start: $start; expected: $end-$start})
		End for
	End for
	return $jobs


Function segments($tables : Collection) : Collection
	// Import and Compare: each table's segments, from its manifest entry,
	// shared out by record count into runs of consecutive segments. A job's
	// low and high are the first_key of its first segment and of the next
	// job's: Compare's key range. A table with no segments is one job.
	var $table; $segment; $run : Object
	var $jobs; $sizes; $counts; $runs : Collection
	var $t; $i; $n; $records; $done; $last : Integer
	$sizes:=$tables.map(Formula($1.result:={records: $1.value.segments.sum("records"); segments: $1.value.segments.length}))
	$counts:=This.counts($sizes)
	$jobs:=[]
	For ($t; 0; $tables.length-1)
		$table:=$tables[$t]
		$records:=$sizes[$t].records
		$n:=$counts[$t]
		$runs:=[]
		$done:=0
		$last:=-1
		For each ($segment; $table.segments)
			$i:=($records=0) ? 0 : [$n-1; Int(($done+($segment.records/2))*$n/$records)].min()  // the job holding the segment's middle record
			If ($i#$last)
				$runs.push({segments: []; start: $done})
				$last:=$i
			End if
			$runs[$runs.length-1].segments.push($segment)
			$done+=$segment.records
		End for each
		If ($runs.length=0)  // no segments: still one job, so Compare counts the target's records
			$runs.push({segments: []; start: 0})
		End if
		For ($i; 0; $runs.length-1)
			$run:=$runs[$i]
			$records:=$run.segments.sum("records")
			$jobs.push({table: $table; segments: $run.segments; low: ($i=0) ? Null : $run.segments[0].first_key; high: ($i=($runs.length-1)) ? Null : $runs[$i+1].segments[0].first_key; start: $run.start; expected: $records})
		End for
	End for
	return $jobs
