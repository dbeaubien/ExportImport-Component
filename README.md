# ExportImport-Component
Generic Full Data Export-Import Routine

### Component overview
This component is a derivative of a 4D Tech Note (https://kb.4d.com/assetid=41862). The component was built using 4D v19.4.

The component can be used to export all the data from a data file and also to import some previously exported data. Checksums are generated after the export and again after the import. The checksums can then be compared to confirm that the import has correctly imported the data and that the import has not caused any modifications to the data.

#### Code to export all the tables using 4 background processes
```4d
var $export_folder_platformPath : Text
$export_folder_platformPath:=Export_AllTables(4)
SHOW ON DISK($export_folder_platformPath)
```

#### Code to import exported table data using 4 background processes
```4d
var $export_folder_platformPath : Text
$export_folder_platformPath:=Import_AllTables(4)
SHOW ON DISK($export_folder_platformPath)
```
