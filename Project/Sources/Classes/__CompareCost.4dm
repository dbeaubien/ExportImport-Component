// cs.__CompareCost
//
// DEV ONLY (ticket 09's speed probe, throw-away). Times each per-record step
// of _CompareJob alone, each in its own loop over the first job.count
// records of the table and of its first segment. One finding per job:
// {table; n; preemptive; us: {step: µs per record}}. Run by
// __Spike_Compare_Cost, cooperative or on _WorkerPool.

Class extends _Job

property _codec : cs._Codec

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table : Pointer
	var $codec : cs._Codec
	var $segment; $target; $slice; $bytes : Blob
	var $key; $ms; $us : Object
	var $text; $a; $b : Text
	var $less : Boolean
	var $step : Text
	var $n; $i; $o; $len; $start; $x : Integer
	$codec:=cs._Codec.new(This.job.table)
	This._codec:=$codec
	READ ONLY(Table(This.job.table.number)->)
	$table:=This._range()
	$segment:=Folder(This.job.folder; fk platform path).file(This.job.segments[0].file).getContent()
	$n:=[Records in selection($table->); This.job.segments[0].records; This.job.count].min()
	GOTO SELECTED RECORD($table->; 1)
	$target:=$codec.encode()
	SET BLOB SIZE($bytes; 4)
	$a:=Generate UUID
	$b:=Generate UUID
	$ms:={}

	$start:=Milliseconds
	For ($i; 1; $n)
		GOTO SELECTED RECORD($table->; $i)
	End for
	$ms.goto:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		GOTO SELECTED RECORD($table->; $i)
		$target:=$codec.encode()
	End for
	$ms.goto_encode:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		GOTO SELECTED RECORD($table->; $i)
		$target:=This._codec.encode()
	End for
	$ms.goto_encode_property:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		$key:=$codec.key(->$target; 0)
	End for
	$ms.key_target:=Milliseconds-$start

	$start:=Milliseconds
	$o:=0
	For ($i; 1; $n)
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		$o+=$len
	End for
	$ms.walk:=Milliseconds-$start

	$start:=Milliseconds
	$o:=0
	For ($i; 1; $n)
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		$key:=$codec.key(->$segment; $o)
		$o+=$len
	End for
	$ms.walk_key_source:=Milliseconds-$start

	$start:=Milliseconds
	$o:=0
	For ($i; 1; $n)
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		SET BLOB SIZE($slice; $len)
		COPY BLOB($segment; $slice; $o; 0; $len)
		$o+=$len
	End for
	$ms.walk_copy:=Milliseconds-$start

	$start:=Milliseconds
	$o:=0
	For ($i; 1; $n)
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		SET BLOB SIZE($slice; $len)
		COPY BLOB($segment; $slice; $o; 0; $len)
		$text:=Generate digest($slice; SHA256 digest)
		$o+=$len
	End for
	$ms.walk_copy_sha256:=Milliseconds-$start

	$start:=Milliseconds
	$o:=0
	For ($i; 1; $n)
		$len:=BLOB to longint($segment; PC byte ordering; $o)
		SET BLOB SIZE($slice; $len)
		COPY BLOB($segment; $slice; $o; 0; $len)
		$text:=Generate digest($slice; MD5 digest)
		$o+=$len
	End for
	$ms.walk_copy_md5:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		BASE64 ENCODE($bytes; $text)
	End for
	$ms.base64:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		This._noop()
	End for
	$ms.class_call:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		This.output.row.probe:=Num(This.output.row.probe)+1
	End for
	$ms.row_counter:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		$x:=Records in selection($table->)
	End for
	$ms.records_in_selection:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		$less:=($a<$b)
	End for
	$ms.less_text:=Milliseconds-$start

	$start:=Milliseconds
	For ($i; 1; $n)
		$x:=Position($a; $b; 1; *)
	End for
	$ms.position:=Milliseconds-$start

	$us:={}
	For each ($step; $ms)
		$us[$step]:=Round($ms[$step]*1000/$n; 1)
	End for each
	This.output.findings.push({table: This.job.table.name; n: $n; preemptive: This.output.preemptive; us: $us})


Function _noop()
