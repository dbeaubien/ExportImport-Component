//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Bench_Picture (index) : picture
//
// DESCRIPTION
//   DEV ONLY. A small picture that differs per index, kept as
//   SVG, or converted to PNG or JPEG (so the formats vary).
//
#DECLARE($i : Integer)->$picture : Picture
// ----------------------------------------------------
var $svg : Text
$svg:="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"96\" height=\"64\">"\
+"<rect width=\"96\" height=\"64\" fill=\"rgb("+String(Mod($i; 256))+","+String(Mod($i*7; 256))+","+String(Mod($i*13; 256))+")\"/>"\
+"<text x=\"4\" y=\"36\" font-size=\"14\">"+String($i)+"</text></svg>"

var $blob : Blob
TEXT TO BLOB($svg; $blob; UTF8 text without length)
BLOB TO PICTURE($blob; $picture; ".svg")

Case of
	: (Mod($i; 3)=1)
		CONVERT PICTURE($picture; ".png")
	: (Mod($i; 3)=2)
		CONVERT PICTURE($picture; ".jpg")
End case
