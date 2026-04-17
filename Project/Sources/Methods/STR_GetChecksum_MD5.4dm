//%attributes = {"invisible":true,"preemptive":"capable"}
// STR_GetChecksum_MD5 (Text to Checksum) : checksum
// STR_GetChecksum_MD5 (text) : text
// 
// DESCRIPTION
//   This method returns the checksum for the supplied text.
//   Handle some cross platform issues, converts all EOL chars to a
//   standard platform independent variant.
//
#DECLARE($source : Text)->$checksum : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

// Handle some cross platform issues, converts all to a standard platform independent variant
$source:=Replace string:C233($source; Char:C90(Carriage return:K15:38)+Char:C90(Line feed:K15:40); "<CR>")
$source:=Replace string:C233($source; Char:C90(Line feed:K15:40); "<CR>")
$source:=Replace string:C233($source; Char:C90(Carriage return:K15:38); "<CR>")

$checksum:=Generate digest:C1147($source; MD5 digest:K66:1)

