// cs.__CodecCost
//
// DEV ONLY (spec ticket 17's probe, throw-away). One variant of the
// per-record encode, timed over the first job.count records of the table in
// key order. job.variant:
//   - "check": each record encoded by _Codec.encode() and by
//     __Spike_Encode_Arrays, counting the buffers that differ (untimed);
//   - "goto": GOTO SELECTED RECORD alone;
//   - "class": GOTO SELECTED RECORD then _Codec.encode();
//   - "arrays": GOTO SELECTED RECORD then __Spike_Encode_Arrays, which reads
//     the field descriptors from arrays filled once here.
// Its row adds records, ms (the timed loop) and differ. Run by
// __Spike_Codec_Cost on _WorkerPool.

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table : Pointer
	var $codec : cs._Codec
	var $a; $b : Blob
	var $f : Object
	var $i; $n; $start; $differ : Integer
	ARRAY POINTER($ptrs; 0)
	ARRAY LONGINT($kinds; 0)
	ARRAY LONGINT($widths; 0)
	ARRAY BOOLEAN($uuids; 0)
	$codec:=cs._Codec.new(This.job.table)
	For each ($f; $codec._fields)
		APPEND TO ARRAY($ptrs; $f.ptr)
		APPEND TO ARRAY($kinds; $f.kind)
		APPEND TO ARRAY($widths; $f.width)
		APPEND TO ARRAY($uuids; $f.uuid)
	End for each
	READ ONLY(Table(This.job.table.number)->)
	$table:=This._range()
	$n:=[Records in selection($table->); This.job.count].min()

	$start:=Milliseconds
	Case of
		: (This.job.variant="check")
			For ($i; 1; $n)
				GOTO SELECTED RECORD($table->; $i)
				$a:=$codec.encode()
				$b:=__Spike_Encode_Arrays(->$ptrs; ->$kinds; ->$widths; ->$uuids)
				If (Generate digest($a; SHA256 digest)#Generate digest($b; SHA256 digest))
					$differ+=1
				End if
			End for
		: (This.job.variant="goto")
			For ($i; 1; $n)
				GOTO SELECTED RECORD($table->; $i)
			End for
		: (This.job.variant="class")
			For ($i; 1; $n)
				GOTO SELECTED RECORD($table->; $i)
				$a:=$codec.encode()
			End for
		Else   // arrays
			For ($i; 1; $n)
				GOTO SELECTED RECORD($table->; $i)
				$a:=__Spike_Encode_Arrays(->$ptrs; ->$kinds; ->$widths; ->$uuids)
			End for
	End case
	This.output.row.ms:=Milliseconds-$start
	This.output.row.records:=$n
	This.output.row.differ:=$differ
