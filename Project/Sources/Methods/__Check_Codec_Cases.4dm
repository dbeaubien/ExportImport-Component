//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Codec_Cases : cases
//
// DESCRIPTION
//   DEV ONLY. __Check_Codec's edge cases, on new unsaved Spike_Keys records,
//   for values the bench data may not hold: texts that must come back
//   exactly, lone surrogates the encoder refuses (ticket 01's fact 3), two
//   spellings of é that must differ, extreme dates, and the all-zero UUID.
//
#DECLARE()->$cases : Collection
// ----------------------------------------------------
var $codec : cs._Codec
var $case : Object
var $errors : Collection
var $a; $b : Blob
var $back : Text
var $y : Integer
$codec:=cs._Codec.new(cs._Structure.new().tables.query("name = :1"; "Spike_Keys").first())
$cases:=[]

// Texts that come back exactly, in the same bytes
For each ($case; [\
{case: "surrogate pair U+1F600"; text: "a"+Char(55357)+Char(56832)+"b"}; \
{case: "starts with U+FEFF"; text: Char(65279)+"a"}; \
{case: "CR, LF, CRLF and a trailing space"; text: "a"+Char(Carriage return)+"b"+Char(Line feed)+"c"+Char(Carriage return)+Char(Line feed)+"d "}])
	Try
		CREATE RECORD([Spike_Keys])
		[Spike_Keys]PK:="case"
		[Spike_Keys]F_Text:=$case.text
		$a:=$codec.encode()
		$case.slice_size:=$codec.slices(->$a; 0)[4].size  // F_Text is field 5
		CREATE RECORD([Spike_Keys])
		$codec.decode(->$a; 0)
		$back:=[Spike_Keys]F_Text
		$b:=$codec.encode()
		$case.pass:=(Length($back)=Length($case.text)) && (Position($back; $case.text; 1; *)=1) && (Generate digest($a; SHA256 digest)=Generate digest($b; SHA256 digest))
	Catch
		$case.pass:=False
		$case.errors:=Last errors
	End try
	$cases.push($case)
End for each

// A lone surrogate is refused
For each ($case; [{case: "lone surrogate U+D800, then b"; code: 55296; after: "b"}; {case: "lone surrogate U+DC00 at the end"; code: 56320; after: ""}])
	$case.expected:="errCode 3"
	$case.pass:=False
	Try
		CREATE RECORD([Spike_Keys])
		[Spike_Keys]PK:="case"
		[Spike_Keys]F_Text:="a"+Char($case.code)+$case.after
		$codec.encode()
	Catch
		$errors:=Last errors
		$case.pass:=($errors.query("componentSignature = :1 AND errCode = :2"; "ExportImport"; 3).length>0)
		$case.errors:=$errors
	End try
	$cases.push($case)
End for each

// Composed and decomposed é encode differently
$case:={case: "é composed and decomposed"; expected: "different bytes"}
Try
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:="case"
	[Spike_Keys]F_Text:=Char(233)
	$a:=$codec.encode()
	[Spike_Keys]F_Text:="e"+Char(769)
	$b:=$codec.encode()
	$case.pass:=(Generate digest($a; SHA256 digest)#Generate digest($b; SHA256 digest))
Catch
	$case.pass:=False
	$case.errors:=Last errors
End try
$cases.push($case)

// Dates before year 100 and after 9999 come back
For each ($y; [1; 99; 10000; 32767])
	$case:={case: "date in year "+String($y)}
	Try
		CREATE RECORD([Spike_Keys])
		[Spike_Keys]PK:="case"
		[Spike_Keys]F_Date:=Add to date(!00-00-00!; $y; 6; 15)
		$a:=$codec.encode()
		CREATE RECORD([Spike_Keys])
		$codec.decode(->$a; 0)
		$b:=$codec.encode()  // Generate digest takes a variable, not an expression, when interpreted
		$case.pass:=([Spike_Keys]F_Date=Add to date(!00-00-00!; $y; 6; 15)) && (Generate digest($a; SHA256 digest)=Generate digest($b; SHA256 digest))
	Catch
		$case.pass:=False
		$case.errors:=Last errors
	End try
	$cases.push($case)
End for each

// An all-zero Auto UUID encodes as empty and decodes as all-zero. A null one
// can't be built in memory (reading it generates a value), and the null
// F_UUID values of Bench_Wide cover that path.
$case:={case: "all-zero Auto UUID"}
Try
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:="case"
	[Spike_Keys]Auto_UUID:="00000000000000000000000000000000"
	$a:=$codec.encode()
	$case.slice_size:=$codec.slices(->$a; 0)[2].size  // Auto_UUID is field 3; 4 = empty
	CREATE RECORD([Spike_Keys])
	$codec.decode(->$a; 0)
	$case.decoded_as:=[Spike_Keys]Auto_UUID
	$b:=$codec.encode()
	$case.pass:=($case.slice_size=4) && ($case.decoded_as="00000000000000000000000000000000") && (Generate digest($a; SHA256 digest)=Generate digest($b; SHA256 digest))
Catch
	$case.pass:=False
	$case.errors:=Last errors
End try
$cases.push($case)
REDUCE SELECTION([Spike_Keys]; 0)
