// cs._Structure
//
// The host's structure, read from inside the component (spec 05): every
// table, its primary-key field number and its fields, skipping deleted
// ones. Also the structure signature and the data language (spec 11).
// Read it in the coordinator: it isn't meant for a preemptive worker.
//
// never_null and UUID come from EXPORT STRUCTURE, which writes never_null
// only when it is true (ticket 01, fact 8). Types are FriendlyFieldType's,
// plus "UUID".
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   5 EXPORT STRUCTURE doesn't describe a field of the structure.

property tables : Collection  // the canonical list: [{number; name; primary_key; fields: [{number; name; type; length; never_null}]}]
property signature : Text  // the SHA-256 of the canonical list as JSON
property language : Text  // the data language

Class constructor()
	var $xml; $block; $element; $key : Text
	var $t; $f; $type; $length; $start; $pos; $len; $field_start; $field_pos; $field_len : Integer
	var $found; $table; $x : Object

	// never_null, UUID and the primary key, by "table.field", from EXPORT STRUCTURE
	EXPORT STRUCTURE($xml)
	$found:={}
	$start:=1
	While (Match regex("(?s)<table [^>]*>.*?</table>"; $xml; $start; $pos; $len))
		$block:=Substring($xml; $pos; $len)
		$t:=Num(This._attribute($block; "id"))  // the <table> element's own id comes first
		$key:=This._attribute($block; "field_uuid")  // only <primary_key> has one
		$field_start:=1
		While (Match regex("<field [^>]*>"; $block; $field_start; $field_pos; $field_len))
			$element:=Substring($block; $field_pos; $field_len)
			$found[String($t)+"."+This._attribute($element; "id")]:={\
				never_null: (This._attribute($element; "never_null")="true"); \
				uuid: (This._attribute($element; "store_as_UUID")="true"); \
				key: ($key#"") && (This._attribute($element; "uuid")=$key)}
			$field_start:=$field_pos+$field_len
		End while
		$start:=$pos+$len
	End while

	// The canonical list: table and field number order, and a fixed property order
	This.tables:=[]
	For ($t; 1; Last table number)
		If (Is table number valid($t))
			$table:={number: $t; name: Table name($t); primary_key: 0; fields: []}
			For ($f; 1; Last field number($t))
				If (Is field number valid($t; $f))
					$x:=$found[String($t)+"."+String($f)]
					If ($x=Null)
						throw({errCode: 5; componentSignature: "ExportImport"; message: "EXPORT STRUCTURE doesn't describe ["+Table name($t)+"]"+Field name($t; $f)})
					End if
					GET FIELD PROPERTIES($t; $f; $type; $length)
					$table.fields.push({\
						number: $f; \
						name: Field name($t; $f); \
						type: $x.uuid ? "UUID" : FriendlyFieldType($type); \
						length: (($type=Is alpha field) && Not($x.uuid)) ? $length : 0; \
						never_null: $x.never_null})
					If ($x.key)
						$table.primary_key:=$f
					End if
				End if
			End for
			This.tables.push($table)
		End if
	End for
	This.signature:=Generate digest(JSON Stringify(This.tables); SHA256 digest)
	This.language:=Get database localization(Internal 4D localization; *)


Function diff($other : Collection) : Collection
	// Each difference between this list and an export set's (its manifest's structure), one line each.
	var $lines : Collection
	var $a; $b; $f; $g : Object
	var $prop : Text
	$lines:=[]
	For each ($a; This.tables)
		$b:=$other.query("number = :1"; $a.number).first()
		If ($b=Null)
			$lines.push("["+$a.name+"] (table "+String($a.number)+") isn't in the export set")
		Else
			For each ($prop; ["name"; "primary_key"])
				If (Not(This._same($a[$prop]; $b[$prop])))
					$lines.push("["+$a.name+"] (table "+String($a.number)+"): "+$prop+" is "+JSON Stringify($a[$prop])+" here and "+JSON Stringify($b[$prop])+" in the export set")
				End if
			End for each
			For each ($f; $a.fields)
				$g:=$b.fields.query("number = :1"; $f.number).first()
				If ($g=Null)
					$lines.push("["+$a.name+"]"+$f.name+" (field "+String($f.number)+") isn't in the export set")
				Else
					For each ($prop; ["name"; "type"; "length"; "never_null"])
						If (Not(This._same($f[$prop]; $g[$prop])))
							$lines.push("["+$a.name+"]"+$f.name+" (field "+String($f.number)+"): "+$prop+" is "+JSON Stringify($f[$prop])+" here and "+JSON Stringify($g[$prop])+" in the export set")
						End if
					End for each
				End if
			End for each
			For each ($g; $b.fields)
				If ($a.fields.query("number = :1"; $g.number).length=0)
					$lines.push("["+$b.name+"]"+$g.name+" (field "+String($g.number)+") is only in the export set")
				End if
			End for each
		End if
	End for each
	For each ($b; $other)
		If (This.tables.query("number = :1"; $b.number).length=0)
			$lines.push("["+$b.name+"] (table "+String($b.number)+") is only in the export set")
		End if
	End for each
	return $lines


Function _same($a : Variant; $b : Variant) : Boolean
	// Exact equality: the 4D = on text ignores case and accents.
	var $x; $y : Text
	$x:=JSON Stringify($a)
	$y:=JSON Stringify($b)
	return (Length($x)=Length($y)) && (Position($x; $y; 1; *)=1)


Function _attribute($element : Text; $name : Text) : Text
	// The first value of the attribute in the XML text, or "". Only ids, uuids
	// and flags are read this way, which XML never escapes.
	ARRAY LONGINT($pos; 0)
	ARRAY LONGINT($len; 0)
	If (Match regex(" "+$name+"=\"([^\"]*)\""; $element; 1; $pos; $len))
		return Substring($element; $pos{1}; $len{1})
	End if
	return ""
