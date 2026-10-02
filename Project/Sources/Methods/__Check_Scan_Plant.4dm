//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Scan_Plant : planted
//
// DESCRIPTION
//   DEV ONLY. For __Check_Scan and __Check_Fixer: plants the c05_ records in
//   [Spike_Keys], in place of an earlier run's, and returns them: {key;
//   field; value; kind; pos}, where pos lists the bad characters' positions.
//
#DECLARE() : Collection
var $planted : Collection
var $plant; $ptrs : Object
var $p : Pointer
var $bytes : Blob
var $fffe; $ffff : Text

// pos counts characters as Length does: 😀 is a surrogate pair, two characters.
// Char() gives "" for U+FFFE and U+FFFF (first run), so those two are decoded from UTF-8.
BASE64 DECODE("Ye+/vmI="; $bytes)  // 61 EF BF BE 62: a, U+FFFE, b
$fffe:=Convert to text($bytes; "UTF-8")
BASE64 DECODE("Ye+/vw=="; $bytes)  // 61 EF BF BF: a, U+FFFF
$ffff:=Convert to text($bytes; "UTF-8")
$planted:=[\
{key: "c05_control"; field: "F_Text"; value: "a"+Char(1)+"b"; kind: "bad_character"; pos: [2]}; \
{key: "c05_fffe"; field: "F_Text"; value: $fffe; kind: "bad_character"; pos: [2]}; \
{key: "c05_ffff"; field: "F_Text"; value: $ffff; kind: "bad_character"; pos: [2]}; \
{key: "c05_high"; field: "F_Text"; value: "a"+Char(55296)+"b"; kind: "lone_surrogate"; pos: [2]}; \
{key: "c05_low"; field: "F_Text"; value: "a"+Char(56320)+"b"; kind: "lone_surrogate"; pos: [2]}; \
{key: "c05_after_pair"; field: "F_Text"; value: "😀"+Char(31)+"x"+Char(11); kind: "bad_character"; pos: [3; 5]}; \
{key: "c05_alpha"; field: "Alt_Code"; value: "c05_alpha"+Char(27); kind: "bad_character"; pos: [10]}; \
{key: "c05_space_uuid"; field: "Auto_UUID"; value: ""; kind: "space_uuid"; pos: []}; \
{key: "c05_clean"; field: "F_Text"; value: "tab\tlf\ncr\r😀é"+Char(65533); kind: Null; pos: []}]
QUERY([Spike_Keys]; [Spike_Keys]PK="c05_@")  // the @ is a wildcard here on purpose: an earlier run's keys
DELETE SELECTION([Spike_Keys])
$ptrs:={F_Text: (->[Spike_Keys]F_Text); Alt_Code: (->[Spike_Keys]Alt_Code); Auto_UUID: (->[Spike_Keys]Auto_UUID)}
For each ($plant; $planted)
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:=$plant.key
	[Spike_Keys]Alt_Code:=$plant.key
	$p:=$ptrs[$plant.field]
	$p->:=$plant.value  // "" in a UUID field stores 0x20 bytes (ticket 01's fact 2)
	SAVE RECORD([Spike_Keys])
End for each
UNLOAD RECORD([Spike_Keys])
return $planted
