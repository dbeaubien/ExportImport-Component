//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Bench_Generate ({scale})
//
// DESCRIPTION
//   DEV ONLY. Fills the Bench_* tables with repeatable generated data.
//   Every value derives from the record index, so two runs with the
//   same scale produce the same data (except UUIDs).
//   scale 1.0 ≈ 5 GB, 8.0 ≈ 40 GB. Truncates the Bench_* tables first.
//
#DECLARE($scale : Real)
// ----------------------------------------------------
If ($scale<=0)
	$scale:=1
End if 

var $CR; $LF; $CRLF : Text
$CR:=Char:C90(Carriage return:K15:38)
$LF:=Char:C90(Line feed:K15:40)
$CRLF:=$CR+$LF

var $reals : Collection  // extreme or tricky reals
$reals:=[0; -0; 0.1+0.2; 1/3; Pi:K30:1; 1e+308; -1e+308; 4.450147717014e-308; 5.059232213414e-321; 123456789012300; 9.007199254741e+15; 0.0000000001]

var $progress : Integer
$progress:=Progress New
var $ms : Integer
$ms:=Milliseconds:C459

var $t; $i; $n; $k; $f : Integer
var $u : Real
var $table : Pointer

// Truncate and reset the sequence of every Bench_* table
For ($t; 1; Last table number:C254)
	If (Is table number valid:C999($t))
		If (Table name:C256($t)="Bench_@")
			TRUNCATE TABLE:C1051(Table:C252($t)->)
			SET DATABASE PARAMETER:C642(Table:C252($t)->; Table sequence number:K37:31; 0)
		End if 
	End if 
End for 

// A 512 KB block of pseudo-random bytes, sliced into the BLOBs
var $chunk : Blob
var $seed; $offset : Integer
$seed:=12345
For ($i; 1; 131072)
	$seed:=Mod:C98(($seed*1103)+12345; 2147483647)
	LONGINT TO BLOB:C550($seed; $chunk; Native byte ordering:K22:1; *)
End for 

// ## Bench_Wide: every field type, ~5% nulls per field, gaps in the sequence
$n:=Round:C94(2000000*$scale; 0)
Progress SET TITLE($progress; "Bench_Wide")
For ($i; 1; $n)
	$u:=Dec:C9($i*0.6180339887499)
	CREATE RECORD:C68([Bench_Wide:3])
	[Bench_Wide:3]F_Bool:2:=($u<0.5)
	[Bench_Wide:3]F_Int:3:=Mod:C98($i; 65536)-32768
	[Bench_Wide:3]F_Long:4:=Choose:C955(Mod:C98($i; 97)=0; MAXLONG:K35:2; Round:C94(($u-0.5)*2000000000; 0))
	[Bench_Wide:3]F_Int64:5:=Round:C94(($u-0.5)*9.007199254741e+15; 0)
	[Bench_Wide:3]F_Real:6:=Choose:C955(Mod:C98($i; 50)=0; $reals[Mod:C98($i/50; $reals.length)]; ($u-0.5)*1000000)
	[Bench_Wide:3]F_Date:7:=Choose:C955(Mod:C98($i; 101)=0; !00-00-00!; Add to date:C393(!00-00-00!; 1+Mod:C98($i; 9999); 1+Mod:C98($i; 12); 1+Mod:C98($i; 28)))
	[Bench_Wide:3]F_Time:8:=Time:C179(Mod:C98($i*37; 200000))  // up to ~55 hours
	[Bench_Wide:3]F_Alpha:9:=Substring:C12("alpha "+String:C10($i)+" éü中😀:\t"+("x"*Mod:C98($i; 80)); 1; 80)
	[Bench_Wide:3]F_Text:10:=Choose:C955(Mod:C98($i; 33)=0; ""; "line "+String:C10($i)+$CR+"lf"+$LF+"crlf"+$CRLF+"name:value"+$CR+("ipsum "*Mod:C98($i; 40)))
	VARIABLE TO BLOB:C532($i; [Bench_Wide:3]F_Blob:11)
	If (Mod:C98($i; 1000)=0)
		[Bench_Wide:3]F_Picture:12:=__Bench_Picture($i)
	End if 
	[Bench_Wide:3]F_Object:13:={i: $i; s: "rec "+String:C10($i)+$CRLF; r: $u; b: ($u>0.3); n: Null:C1517; tags: ["a"; "b"; $i]; nested: {deep: {x: [1; 2; {y: Null:C1517; z: $CR}]}}}
	[Bench_Wide:3]F_UUID:14:=Generate UUID:C1066
	For ($f; 2; Last field number:C255(->[Bench_Wide:3]))  // ~5% nulls, per field
		If (Dec:C9($i*0.7548776662467+($f*0.1))<0.05)
			SET FIELD VALUE NULL:C965(Field:C253(Table:C252(->[Bench_Wide:3]); $f)->)
		End if 
	End for 
	SAVE RECORD:C53([Bench_Wide:3])
	If (Mod:C98($i; 997)=0)  // gaps: sequence number > record count
		DELETE RECORD:C58([Bench_Wide:3])
	End if 
	If (Mod:C98($i; 5000)=0)
		Progress SET PROGRESS($progress; $i/$n)
	End if 
End for 
UNLOAD RECORD:C212([Bench_Wide:3])

// Int64 values at the edge of ±2^53, which the gate allows, only settable exactly through SQL
Begin SQL
	UPDATE Bench_Wide SET F_Int64 = 9007199254740992 WHERE ID = 1;
	UPDATE Bench_Wide SET F_Int64 = -9007199254740992 WHERE ID = 2;
	UPDATE Bench_Wide SET F_Int64 = 9007199254740991 WHERE ID = 3;
	UPDATE Bench_Wide SET F_Int64 = 9007199254740992 WHERE ID = 4;
End SQL

// ## Bench_Text: UUID key, ~1.5 KB multi-line text with mixed line endings
$n:=Round:C94(1000000*$scale; 0)
Progress SET TITLE($progress; "Bench_Text")
For ($i; 1; $n)
	$u:=Dec:C9($i*0.6180339887499)
	CREATE RECORD:C68([Bench_Text:4])
	[Bench_Text:4]Title:2:="Title "+String:C10($i)+" – Ünïcödé 中文 😀"
	[Bench_Text:4]Body:3:=("Paragraph "+String:C10($i)+$CR+"second line"+$LF+"third line"+$CRLF+"tab\tcolon:semi;"+$CR)*(5+Mod:C98($i; 15))
	[Bench_Text:4]Notes:4:=Choose:C955($u<0.2; ""; "note "+String:C10($u)+$LF)
	[Bench_Text:4]Created:5:=Add to date:C393(!00-00-00!; 1990+Mod:C98($i; 40); 1+Mod:C98($i; 12); 1+Mod:C98($i; 28))
	SAVE RECORD:C53([Bench_Text:4])
	If (Mod:C98($i; 5000)=0)
		Progress SET PROGRESS($progress; $i/$n)
	End if 
End for 
UNLOAD RECORD:C212([Bench_Text:4])

// ## Bench_Blob: 50–350 KB BLOBs (some compressed or empty) and SVG/PNG/JPEG pictures
$n:=Round:C94(10000*$scale; 0)
Progress SET TITLE($progress; "Bench_Blob")
For ($i; 1; $n)
	$u:=Dec:C9($i*0.6180339887499)
	CREATE RECORD:C68([Bench_Blob:5])
	[Bench_Blob:5]Label:2:="blob "+String:C10($i)
	Case of 
		: (Mod:C98($i; 25)=0)  // empty
		Else 
			COPY BLOB:C558($chunk; [Bench_Blob:5]Payload:3; Mod:C98($i*4; 65536); 0; 50000+Round:C94($u*300000; 0))
			$offset:=0
			LONGINT TO BLOB:C550($i; [Bench_Blob:5]Payload:3; Native byte ordering:K22:1; $offset)
			If (Mod:C98($i; 10)=0)
				COMPRESS BLOB:C534([Bench_Blob:5]Payload:3; GZIP best compression mode:K22:18)
			End if 
	End case 
	[Bench_Blob:5]Image:4:=__Bench_Picture($i)
	[Bench_Blob:5]Meta:5:={i: $i; size: BLOB size:C605([Bench_Blob:5]Payload:3); list: [{a: 1}; {b: [$u; Null:C1517]}]}
	SAVE RECORD:C53([Bench_Blob:5])
	If (Mod:C98($i; 100)=0)
		Progress SET PROGRESS($progress; $i/$n)
	End if 
End for 
UNLOAD RECORD:C212([Bench_Blob:5])

// ## Bench_Small_01..20: many small tables, 1000×k×scale records each
For ($t; 1; Last table number:C254)
	If (Is table number valid:C999($t))
		If (Table name:C256($t)="Bench_Small_@")
			$k:=Num:C11(Substring:C12(Table name:C256($t); 13))
			$table:=Table:C252($t)
			If ($k=7)  // sequence starts far from 1
				SET DATABASE PARAMETER:C642($table->; Table sequence number:K37:31; 1000000)
			End if 
			$n:=Round:C94(1000*$k*$scale; 0)
			Progress SET TITLE($progress; Table name:C256($t))
			For ($i; 1; $n)
				CREATE RECORD:C68($table->)
				Field:C253($t; 2)->:="C"+String:C10($i)
				Field:C253($t; 3)->:="Name "+String:C10($i)+" "+Table name:C256($t)
				Field:C253($t; 4)->:=Round:C94(Dec:C9($i*0.6180339887499)*100000; 2)
				Field:C253($t; 5)->:=Add to date:C393(!00-00-00!; 2000+Mod:C98($i; 25); 1+Mod:C98($i; 12); 1+Mod:C98($i; 28))
				Field:C253($t; 6)->:=(Mod:C98($i; 3)=0)
				Field:C253($t; 7)->:=Choose:C955(Mod:C98($i; 4)=0; ""; "note"+$CRLF+String:C10($i))
				SAVE RECORD:C53($table->)
			End for 
			UNLOAD RECORD:C212($table->)
			Progress SET PROGRESS($progress; $k/20)
		End if 
	End if 
End for 

Progress QUIT($progress)
File(Data file; fk platform path).parent.file("Bench Generate.json")\
.setText(JSON Stringify({when: Timestamp; scale: $scale; compiled: Is compiled mode; generate_ms: Milliseconds-$ms}; *))  // picked up by __Bench_Baseline
ALERT:C41("Bench data generated (scale "+String:C10($scale)+") in "+String:C10((Milliseconds:C459-$ms)/60000; "###,##0.0")+" min.")
