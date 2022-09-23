//%attributes = {"invisible":true,"preemptive":"capable"}
// STR_GetChecksum_MD5 (Text to Checksum) : checksum
// STR_GetChecksum_MD5 (text) : text
// 
// DESCRIPTION
//   This method returns the checksum for the supplied text.
//   Handle some cross platform issues, converts all EOL chars to a
//   standard platform independent variant.
//
C_TEXT:C284($1; $vt_srcText)
C_TEXT:C284($0; $checksum_out_t)
// ----------------------------------------------------
// HISTORY
//   NOTE: This method provided by Tim Penner (6/15/2010)
//   Mod by: Dani Beaubien (10/19/2011)
//   Mod: DB (04/12/2017) - Remove reliance on Common Crypto plugin
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$vt_srcText:=$1

// Handle some cross platform issues, converts all to a standard platform independent variant
$vt_srcText:=Replace string:C233($vt_srcText; Char:C90(Carriage return:K15:38)+Char:C90(Line feed:K15:40); "<CR>")
$vt_srcText:=Replace string:C233($vt_srcText; Char:C90(Line feed:K15:40); "<CR>")
$vt_srcText:=Replace string:C233($vt_srcText; Char:C90(Carriage return:K15:38); "<CR>")

$checksum_out_t:=Generate digest:C1147($vt_srcText; MD5 digest:K66:1)

$0:=$checksum_out_t
