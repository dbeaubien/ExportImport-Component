# ExportImport-Component
Generic Full Data Export-Import Routine

### Component overview
This component is a derivative of a 4D Tech Note (https://kb.4d.com/assetid=41862). The component was built using 4D v19.4.

The component can be used to export all the data from a data file and also to import some previously exported data. Checksums are generated after the export and again after the import. The checksums can then be compared to confirm that the import has correctly imported the data and that the import has not caused any modifications to the data.

#### Code to export all the tables using 6 background pre-emptive capable processes
```4d
var $export_folder_platformPath : Text
$export_folder_platformPath:=Export_AllTables(6)
SHOW ON DISK($export_folder_platformPath)
```
The export will create two subfolders in a new folder that is created beside the datafile.
- "XML" will contain an xml file for each table that has records. There will be only one XML file of it is less than 250MB. Additional segments will be created if the exports XML exceed 250MB with each file be 250MB or less.
- "MD5" this folder contains a file per exported table. The file name includes a hash of the file's contents. Each file contains a list of hashed record blocks (sorted by the table's primary key). Each block has a hash.

#### Code to import exported table data using 4 background pre-emptive capable processes
```4d
var $export_folder_platformPath : Text
$export_folder_platformPath:=Import_AllTables(4)
SHOW ON DISK($export_folder_platformPath)
```
The import will create an additional subfolder in the folder that the import was pointed to.
- "MD5 - after import" this folder contains a file per exported table. The file name includes a hash of the file's contents. Each file contains a list of hashed record blocks (sorted by the table's primary key). Each block has a hash.

The two MD5 folders can be compared. If there are differences then the imported data doesn't match the datafile before the export.
