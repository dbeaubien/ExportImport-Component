// cs._RunReport
//
// A run report (spec 13): "<Pass> yyyy-mm-dd hh.mm.ss" .json and .txt. The
// .json is the result envelope. The .txt is its summary, verdict first, in
// the layout of spec 13, with the table columns and sections the pass
// supplies. UTF-8 with no BOM, LF line endings, local times.
// Each rewrite goes to a .tmp file, then takes the file's name. 4D can't
// rename over a file, so the old one is deleted just before: a crash in
// between leaves the .tmp, never a half-written file.

property name : Text  // the file name without its extension
property path : Text  // the .txt's platform path
property _folder : 4D.Folder
property _pass : Text  // "Health check"
property _started : Text  // the local start time

Class constructor($folder : 4D.Folder; $pass : Text)
	This._folder:=$folder
	This._pass:=$pass
	This._started:=This._now()
	This.name:=$pass+" "+Replace string(This._started; ":"; ".")
	This.path:=$folder.file(This.name+".txt").platformPath


Function write($result : Object; $columns : Collection; $sections : Text) : Text
	// Rewrites both files. Returns "" or the error.
	var $error : Text
	Try
		This._replace(".json"; JSON Stringify($result; *))
		This._replace(".txt"; This._text($result; $columns; $sections))
	Catch
		$error:=Last errors.first().message
	End try
	return $error


Function _replace($extension : Text; $text : Text)
	var $file; $tmp : 4D.File
	$file:=This._folder.file(This.name+$extension)
	$tmp:=This._folder.file(This.name+$extension+".tmp")
	$tmp.setText($text; "UTF-8-no-bom"; Document with LF)
	If ($file.exists)
		$file.delete()
	End if
	$tmp.rename($file.fullName)


Function _text($r : Object; $columns : Collection; $sections : Text) : Text
	var $t; $key; $pad : Text
	var $phase; $row; $error : Object
	var $i; $n : Integer
	var $grid; $cells; $widths; $padded : Collection
	$t:=This._pass+": "+$r.verdict+"\nNext step: "+$r.next_step+"\n\n"
	$t+="Problems:"+This._list($r.problems)+"Cautions:"+This._list($r.cautions)+"\n"
	If ($r.export_set#Null)
		$t+="Export set: "+$r.export_set+"\n"
	End if
	If ($r.set_digest#Null)  // the export's, the import's and Compare's (spec 23)
		$t+="Set digest: "+(($r.set_digest="") ? "none" : $r.set_digest)+"\n"
	End if
	$t+="Datafile:   "+$r.datafile+"\n"
	$t+="Started:    "+This._started+(($r.ended=Null) ? "" : ("   Ended: "+Substring(This._now(); 12)+"   Elapsed: "+This._elapsed($r.started; $r.ended)))+"\n"
	$t+="Component:  "+$r.component_version+"   4D: "+$r.app_version+"\n"
	$t+="Run by:     "+$r.os_user+" on "+$r.machine+"\n"
	$t+="Options:    "+This._options($r.options)+"\n"

	$t+="\nPhases\n"
	For each ($phase; $r.phases)
		$t+="  "+$phase.name+(" "*(18-Length($phase.name)))+(($phase.ended=Null) ? "not ended" : This._elapsed($phase.started; $phase.ended))+"\n"
	End for each

	// One row per table: No and Table, then the pass's columns. Only Table is left-aligned.
	For ($i; 1; Last table number)
		$n+=Num(Is table number valid($i))
	End for
	$t+="\nTables: "+String($r.tables.length)+" of "+String($n)+" in the structure\n"
	$grid:=[["No"; "Table"]]
	For each ($key; $columns)
		$grid[0].push(Uppercase(Substring($key; 1; 1))+Replace string(Substring($key; 2); "_"; " "))
	End for each
	For each ($row; $r.tables)
		$cells:=[String($row.number); $row.name]
		For each ($key; $columns)
			$cells.push(This._cell($key; $row[$key]))
		End for each
		$grid.push($cells)
	End for each
	$widths:=$grid[0].map(Formula($1.result:=Length($1.value)))
	For each ($cells; $grid)
		For ($i; 0; $cells.length-1)
			$widths[$i]:=(Length($cells[$i])>$widths[$i]) ? Length($cells[$i]) : $widths[$i]
		End for
	End for each
	For each ($cells; $grid)
		$padded:=[]
		For ($i; 0; $cells.length-1)
			$pad:=" "*($widths[$i]-Length($cells[$i]))
			$padded.push(($i=1) ? ($cells[$i]+$pad) : ($pad+$cells[$i]))
		End for
		$t+="  "+$padded.join("  ")+"\n"
	End for each

	If ($sections#"")
		$t+="\n"+$sections
	End if
	If ($r.failure#Null)
		$t+="\nFailure\n"
		$t+="  Phase:  "+This._shown($r.failure.phase)+"\n"
		$t+="  Table:  "+This._shown($r.failure.table)+"\n"
		$t+="  Key:    "+This._shown($r.failure.key)+"\n"
		If ($r.failure.reason#Null)
			$t+="  Reason: "+$r.failure.reason+"\n"
		End if
		For each ($error; $r.failure.errors.slice(0; 1))
			$t+="  Error:  "+String($error.errCode)+" "+$error.message+"\n"
		End for each
	End if
	return $t


Function _list($lines : Collection) : Text
	return ($lines.length=0) ? "  (none)\n" : ("\n  - "+$lines.join("\n  - ")+"\n")


Function _options($options : Object) : Text
	// "workers 10; detail_limit 1000"
	var $parts : Collection
	var $key : Text
	$parts:=[]
	For each ($key; $options)
		$parts.push($key+" "+JSON Stringify($options[$key]))
	End for each
	return ($parts.length=0) ? "(defaults)" : $parts.join("; ")


Function _cell($key : Text; $value : Variant) : Text
	// Plain digits; an elapsed time as hh:mm:ss; {kind: count} as "kind count, …".
	var $parts : Collection
	var $kind : Text
	Case of
		: ($key="@elapsed")  // the @ is a wildcard here on purpose: elapsed and index_elapsed
			return String(Time(Round($value; 0)); HH MM SS)
		: (Value type($value)=Is object)
			$parts:=[]
			For each ($kind; $value)
				$parts.push($kind+" "+String($value[$kind]))
			End for each
			return $parts.join(", ")
	End case
	return String($value)


Function _shown($value : Variant) : Text
	return ($value=Null) ? "none" : String($value)


Function _elapsed($from : Text; $to : Text) : Text
	// The time between two Timestamp values (ISO 8601 UTC), as hh:mm:ss.
	return String(Time(Round(This._seconds($to)-This._seconds($from); 0)); HH MM SS)


Function _seconds($iso : Text) : Real
	// Seconds since 1970 of yyyy-mm-ddThh:mm:ss.fffZ, read without Num on a
	// decimal point, which depends on the system's settings.
	var $date : Date
	$date:=Add to date(!00-00-00!; Num(Substring($iso; 1; 4)); Num(Substring($iso; 6; 2)); Num(Substring($iso; 9; 2)))
	return (($date-!1970-01-01!)*86400)+(Num(Substring($iso; 12; 2))*3600)+(Num(Substring($iso; 15; 2))*60)+Num(Substring($iso; 18; 2))+(Num(Substring($iso; 21; 3))/1000)


Function _now() : Text
	// The local time, yyyy-mm-dd hh:mm:ss.
	return Date2String(Current date; "yyyy-mm-dd")+" "+Time2String(Current time; "24hh:mm:ss")
