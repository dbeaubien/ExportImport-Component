// cs._RunLog
//
// A run log (spec 13): one "yyyy-mm-dd hh:mm:ss  <text>" line per event,
// local time, UTF-8 with no BOM and LF. Only the coordinator writes it.
// Each line opens the file, appends and lets the handle go, which closes
// the file, so the line is on disk at once and tail -f follows the run.
// The first failed write sets error, and later lines are skipped.

property error : Text  // the first failed write's error, or ""
property _file : 4D.File

Class constructor($file : 4D.File)
	This._file:=$file
	This.error:=""


Function write($text : Text)
	var $bytes : Blob
	If (This.error="")
		Try
			CONVERT FROM TEXT(Date2String(Current date; "yyyy-mm-dd")+" "+Time2String(Current time; "24hh:mm:ss")+"  "+$text+"\n"; "UTF-8"; $bytes)
			This._file.open("append").writeBlob($bytes)
		Catch
			This.error:=Last errors.first().message
		End try
	End if
