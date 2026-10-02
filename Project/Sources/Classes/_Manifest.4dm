// cs._Manifest
//
// An export set's manifest.json (spec 05): everything import and Compare
// read about the set. The export writes it last, so a set without one is
// incomplete. Import and Compare read it with check(), which is their
// shared pre-flight.
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

Class constructor($path : Text)
	This.path:=$path
	This.content:=Null


Function write($export : Object; $settings : Object; $structure : cs._Structure; $tables : Collection)
	// Under a temporary name first, so a crash never leaves half a manifest.
	var $datafile; $tmp : 4D.File
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
	$tmp:=Folder(This.path; fk platform path).file("manifest.json.tmp")
	$tmp.setText(JSON Stringify(This.content; *); "UTF-8-no-bom"; Document with LF)
	$tmp.rename("manifest.json")


Function check() : Object
	// Reads manifest.json and checks it against this datafile (specs 07, 08
	// and 11): the component version and build, the structure, field by
	// field, and the data language. Returns {problems; cautions}. The
	// caution names the tables the set leaves out (spec 13).
	var $folder : 4D.Folder
	var $structure : cs._Structure
	var $problems; $lines; $left : Collection
	var $line : Text
	var $content : Variant
	This.content:=Null
	$folder:=(This.path="") ? Null : Try(Folder(This.path; fk platform path))
	Case of
		: ($folder=Null) || Not($folder.exists)
			return {problems: ["There is no export set at "+JSON Stringify(This.path)]; cautions: []}
		: (Not($folder.file("manifest.json").exists))
			return {problems: ["This export set has no manifest.json: its export didn't finish, or it isn't an export set. Run the export again."]; cautions: []}
	End case
	$content:=Try(JSON Parse($folder.file("manifest.json").getText()))
	If (Value type($content)#Is object) || (Value type($content.source)#Is object) || (Value type($content.structure)#Is collection) || (Value type($content.tables)#Is collection)
		return {problems: ["This export set's manifest.json can't be read. Run the export again."]; cautions: []}
	End if
	This.content:=$content

	$problems:=[]
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
