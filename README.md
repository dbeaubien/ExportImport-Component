# ExportImport-Component
This component is a derivative of a 4D Tech Note (https://kb.4d.com/assetid=41862). The component was built using 4D v19.4.

The component was developed to be able to transport data from one datafile to another with confidence that the data has been transported without modification. It is particularly useful when a datafile must be rebuilt due to some data issue/corruption.

Checksums are generated after the export and again after the import. The checksums can then be compared to confirm that the import has correctly imported the data and that the import has not caused any modifications to the data.

### Exporting tables
There are two functions that can be used to export tables:
- `Export_AllTables` - exports all the tables that have at least 1 record.
- `Export_ListOfTables` - exports a sublist of tables that have at least 1 record.

The export will create two subfolders in a new folder that is created beside the datafile.
- "XML" will contain an xml file for each table that has records. There will be only one XML file of it is less than 250MB. Additional segments will be created if the exports XML exceed 250MB with each file be 250MB or less.
- "MD5" this folder contains a file per exported table. The file name includes a hash of the file's contents. Each file contains a list of hashed record blocks (sorted by the table's primary key). Each block has a hash.

##### Example 1: Export all tables using 6 background pre-emptive capable processes
```4d
var $export_folder_platformPath : Text
$export_folder_platformPath:=Export_AllTables(6)
SHOW ON DISK($export_folder_platformPath)
```

##### Example 2: Export all tables using 6 background pre-emptive capable processes and do some special handling of a some text fields that contain non-standard characters
```4d
var $fields_to_base64 : Collection
var $export_folder_platformPath : Text
$fields_to_base64:=New collection(->[Users]password_hash; ->[Table_2]Field_5)
$export_folder_platformPath:=Export_AllTables(6; $fields_to_base64)
SHOW ON DISK($export_folder_platformPath)
```

##### Example 3: Export a subset of tables using 2 background pre-emptive capable processes
```4d
var $table_no_list : Collection
var $export_folder_platformPath : Text
$table_no_list:=New collection(Table(->[Table_2]))
$export_folder_platformPath:=Export_ListOfTables(2; $table_no_list)
SHOW ON DISK($export_folder_platformPath)
```

There is an optional 3rd parameter that is a collection of fields to do some special handling on like in example 2 above.


### Importing tables
The import will ask for the folder that contains the "XML" folder that was created by the export. The import will load all the files contained within the "XML" folder.

**NOTE**: By default, triggers are disabled during the importing of table records. This can be controled using the optional 2nd parameter. See the example.

The import will create an additional subfolder in the folder that the import was pointed to.
- "MD5 - after import" this folder contains a file per exported table. The file name includes a hash of the file's contents. Each file contains a list of hashed record blocks (sorted by the table's primary key). Each block has a hash.

The two MD5 folders can be compared. If there are differences then the imported data doesn't match the datafile before the export.


##### Example: Import exported table data using 4 background pre-emptive capable processes
```4d
var $options : Object
$options:=New object
$options.truncation_before_import:=True  // default

var $importFromFolder_platformPath : Text
$importFromFolder_platformPath:=Import_AllTables(4; $options)
SHOW ON DISK($importFromFolder_platformPath)
```

**Note**: Both parameters are optional.