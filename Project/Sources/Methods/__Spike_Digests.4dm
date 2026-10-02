//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Digests (picture; object) : {pic; obj}
//
// DESCRIPTION
//   DEV ONLY. The SHA-256 of each value's VARIABLE TO BLOB bytes,
//   the encoding spec 04 uses for pictures and objects.
//
#DECLARE($pic : Picture; $obj : Object)->$digests : Object
// ----------------------------------------------------
var $pic_blob; $obj_blob : Blob
VARIABLE TO BLOB($pic; $pic_blob)
VARIABLE TO BLOB($obj; $obj_blob)
$digests:={pic: Generate digest($pic_blob; SHA256 digest); obj: Generate digest($obj_blob; SHA256 digest)}
