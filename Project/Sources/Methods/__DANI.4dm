//%attributes = {}
// Export_Import_Dialog

If (Caps lock down:C547)
	cs:C1710.ExportPass.new({tables: [Table:C252(->[Bench_Small_01:6])]}).run()
End if 

__Spike_Compare_Path


BEEP:C151
ABORT:C156

// TODO: things to do
/*
- export & import the "next sequence #" for each table
  put at same level as the "Data" folder


Could there be a way that the current settings that were user could be saved to a settings file which could then be reused in subsequent usages?
*/


Export_Import_Dialog

BEEP:C151
ABORT:C156