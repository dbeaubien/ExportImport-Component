# Import strategy

Status: open
Type: grilling
Blocked by: 01, 02, 05
Reads: answers to 01, 02 and 05

## Question

How does the import load an export set into the target datafile as fast as possible without changing any value? Decide:

- the write method (ORDA or classic commands) and the batch size,
- whether to use transactions,
- how journaling, indexes and triggers are handled during the load and restored afterwards,
- truncation of existing records,
- restoring each table's sequence number,
- how work is spread across workers,
- how the folder is selected, given the method is flagged Execute on Server,
- the structure-signature check, which refuses to run if the structures differ,
- behaviour when a file is corrupt or missing.
