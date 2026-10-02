// cs._Manifest
//
// An export set's manifest.json (spec 05): everything import and Compare
// read about the set. The export writes it last, as manifest.json.tmp, and
// its self-check reads that file. complete() renames it manifest.json once
// the self-check is exact (spec 23), so a set without one is incomplete or
// unproven. Import and Compare read it with check(), which is their shared
// pre-flight. The set digest is the SHA-256 of its bytes, in hex.
//
// content:
//   component_version, app_version: as in the export's result envelope
//   started, ended: the export's, ISO 8601 UTC
//   settings: {segment_mb; tables: the table numbers, or null for every table}
//   source: {datafile: its platform path; size; modified, ISO 8601 UTC; structure: its name}
//   language: the data language (spec 11)
//   signature, structure: the whole structure's signature and canonical
//     list, even on a subset run (_Structure's signature and tables)
//   tables: one per exported table, its _Structure entry plus folder (the
//     table's folder in the set), sequence_number, records and segments:
//     [{file; records; bytes; sha256; first_key; last_key}] in key order

property path : Text  // the export set's platform path
property content : Object  // as written, or as check() read it; Null before, or when unreadable
property name : Text  // the file check() reads: manifest.json, or manifest.json.tmp from write() until complete()
property set_digest : Text  // the set digest of the file check() read, or ""

Class constructor($path : Text)
	This.path:=$path
	This.content:=Null
	This.name:="manifest.json"
	This.set_digest:=""


Function write($export : Object; $settings : Object; $structure : cs._Structure; $tables : Collection)
	// As manifest.json.tmp, which check() then reads: the set stays
	// incomplete until complete().
	var $datafile : 4D.File
	$datafile:=File($export.datafile; fk platform path)
	This.content:={\
		component_version: $export.component_version; \
		app_version: $export.app_version; \
		started: $export.started; \
		ended: Timestamp; \
		settings: $settings; \
		source: {\
		datafile: $export.datafile; \
		size: $datafile.size; \
		modified: String($datafile.modificationDate; ISO date GMT; $datafile.modificationTime); \
		structure: File(Structure file(*); fk platform path).name}; \
		language: $structure.language; \
		signature: $structure.signature; \
		structure: $structure.tables; \
		tables: $tables}
	This.name:="manifest.json.tmp"
	Folder(This.path; fk platform path).file(This.name).setText(JSON Stringify(This.content; *); "UTF-8-no-bom"; Document with LF)


Function complete() : Text
	// Once the export's self-check is exact: manifest.json.tmp becomes
	// manifest.json, which is never rewritten. Returns its set digest.
	var $bytes : Blob
	This.name:="manifest.json"
	$bytes:=Folder(This.path; fk platform path).file("manifest.json.tmp").rename(This.name).getContent()
	return Generate digest($bytes; SHA256 digest)


Function check($set_digest : Text) : Object
	// Reads the manifest and checks it against this datafile (specs 07, 08
	// and 11): the component version and build, the structure, field by
	// field, and the data language, and its set digest against $set_digest
	// unless it is "" (spec 23). Returns {problems; cautions}. The caution
	// names the tables the set leaves out (spec 13).
	var $folder : 4D.Folder
	var $structure : cs._Structure
	var $problems; $lines; $left : Collection
	var $line : Text
	var $content : Variant
	var $bytes : Blob
	This.content:=Null
	This.set_digest:=""
	$folder:=(This.path="") ? Null : Try(Folder(This.path; fk platform path))
	Case of
		: ($folder=Null) || Not($folder.exists)
			return {problems: ["There is no export set at "+JSON Stringify(This.path)]; cautions: []}
		: (Not($folder.file(This.name).exists))
			return {problems: ["This export set has no manifest.json: its export didn't finish or its self-check wasn't exact, or it isn't an export set. Run the export again."]; cautions: []}
	End case
	$bytes:=$folder.file(This.name).getContent()  // read once: the digest and the content are of the same bytes
	This.set_digest:=Generate digest($bytes; SHA256 digest)
	$content:=Try(JSON Parse(Convert to text($bytes; "UTF-8")))
	If (Value type($content)#Is object) || (Value type($content.source)#Is object) || (Value type($content.structure)#Is collection) || (Value type($content.tables)#Is collection)
		return {problems: ["This export set's manifest.json can't be read. Run the export again."]; cautions: []}
	End if
	This.content:=$content

	$problems:=[]
	If ($set_digest#"") && ($set_digest#This.set_digest)  // $set_digest on the left: on the right, an @ in it would be a wildcard
		$problems.push("This export set's digest is "+This.set_digest+", not "+$set_digest+": the set has changed since its export, or it is another set.")
	End if
	If (String(This.content.component_version)#ExpImpComp_GetBuildNo().versionLong)
		$problems.push("This export set was written by ExportImport "+String(This.content.component_version)+", and this is "+ExpImpComp_GetBuildNo().versionLong+". Import and Compare need the same version and build: use that one, or export again with this one.")
	End if
	$structure:=cs._Structure.new()
	$lines:=$structure.diff(This.content.structure)
	If ($lines.length=0) && (String(This.content.signature)#$structure.signature)
		$lines.push("its signature differs, though no table or field does")
	End if
	For each ($line; $lines)
		$problems.push("The structure differs: "+$line)
	End for each
	If (String(This.content.language)#$structure.language)
		$problems.push("The data language is "+JSON Stringify($structure.language)+" here and "+JSON Stringify(String(This.content.language))+" in the export set, so keys would sort differently. Set it to "+JSON Stringify(String(This.content.language))+" in 4D Preferences ▸ General, then create a new target datafile.")
	End if
	$left:=This.content.structure.filter(Formula($1.result:=($2.indexOf($1.value.number)<0)); This.content.tables.extract("number")).extract("name")
	return {problems: $problems; cautions: ($left.length=0) ? [] : [String($left.length)+" tables not in this export set: ["+$left.join("], [")+"]"]}
