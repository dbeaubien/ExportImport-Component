var $options : Object
$options:=New object:C1471
$options.num_processes:=Form:C1466.num_worker_processes
$options.tables_to_scan:=[]
$options.fields_to_ignore:=[]

Export_PreCheck_FindBadChars($options)