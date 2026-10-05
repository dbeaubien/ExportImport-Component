# ExportImport overview

ExportImport is a 4D component that moves every record from one datafile into a newly created
datafile, then proves that the new datafile holds exactly the same records with exactly the same
data.

You use it when a datafile has to be rebuilt, for example after corruption or damage. The component
reads the **source datafile** and writes its records into a folder of files, the **export set**. 4D then switches to a new, empty **target datafile**, and the component loads the export set into it. Last, it reads every target record back and compares it with the export set. A record that differs is named down to its table, its **record key** and its field.

The whole process can run on every table or on a chosen subset. Terms in bold are defined in the
[glossary](../GLOSSARY.md).

## What a run looks like

Five steps take a datafile from the source to a verified target. The [guided dialog](../README.md#the-guided-dialog) shows them as a step list, and each step can also run from code.

1. **Health check** (optional, recommended). Scan a copy of the source datafile for **blockers**,
   which the export refuses, and for signs of damage, which the export copies as they are. If you
   choose, the fixer then removes the **bad characters**.
2. **Export.** Write the export set next to the source datafile: the records, in binary **segments**, and a **manifest** that describes them. The export ends with a **self-check**, a comparison of the new set with the source, and gives the **set digest**.
3. **Switch to target.** 4D closes the source datafile and opens a new, empty target datafile.
4. **Import.** Empty the exported tables of the target, load the segments, rebuild the indexes,
   set each table's sequence number, then compare.
5. **Compare.** Read every target record and compare it with the export set. You can run Compare
   again after you reopen the target.

Each step writes a **run report** and a **run log**, so you can follow a run as it goes and read
what happened afterwards.

## The goals behind the design

### Prove the copy, don't assume it

A copy that looks fine isn't enough when the source was damaged. The main goal is a verdict that means something: `exact` says that every target record equals its source record under one **equality rule**. Every stored field value must be exactly the same. Case, accents, line endings, the bits of a real, and the stored bytes of a BLOB, picture or object all count. A null value equals a blank one, because the 4D language reads them the same way.

The proof is a chain of four checks, and the chain trusts no link that it doesn't check:

1. The export's self-check compares the new export set with the source. Only an exact self-check
   completes the set.
2. The set digest, kept outside the set, shows that the set hasn't changed since the export.
3. The import checks the SHA-256 of every segment against the manifest before it writes anything.
4. The import's Compare checks that the target holds the set's records.

### Name every discrepancy

When the copy isn't exact, "something differs" doesn't help anyone. Compare lists each **discrepancy**: a missing, extra, changed or duplicated record, or a table whose record count or sequence number differs. A changed record names each field that differs, with its two values.

A record whose equality can't be decided is an **unverified record**. It is listed as such, never counted as equal. Compare then gives `inconclusive`, not `exact`. Each discrepancy and each unverified record can be investigated, then explained or resolved.

### Refuse what can't be copied faithfully

Some values would be copied wrongly without any check noticing. A table with records but no primary key has no record key to match its records by. The 4D language reads an Int64 value beyond ±2^53 rounded. These are blockers, and the export refuses them with no override. Fix the data on the source copy, or leave the table out of the export.

Signs of damage are different. A control character in a text value is a sign that something went wrong, but the export can copy it byte for byte, so the health check only warns about it. The fixer removes bad characters when you ask it to, and never from a record key.

### Finish large datafiles in reasonable time

The health check, the export, the import and Compare split their record work into jobs, and run them on a pool of worker processes, preemptive when compiled. A large table is cut into key ranges, so several workers share it. The default is 4 workers, capped at the machine's core count.

### Leave a trail

Every run writes its run report as soon as it starts, and rewrites it at each phase. If 4D quits or crashes during a run, the report still says `interrupted` and names the step to take. The run log gets one line per event as the run goes, so `tail -f` can follow a run started from code. A worker log records when each job was sent to a worker, received and completed.

### Keep the host's code working

Hosts call the component through shared methods that keep the names and parameters of earlier
versions, and through the `ExportImport` class namespace. Both stay compatible from one release to
the next. [ADR 0001](adr/0001-two-host-seams.md) records why there are two.

## What the component doesn't do

- **Prove the source copy.** The component proves that the target matches the source datafile it
  read. Verify that the source copy is faithful to production with the MSC (Verify ▸ Records and
  indexes) before the export.
- **Prove 4D's write path.** The import flushes the cache and compares in the same session. For
  more assurance, reopen the target and run Compare again. Proving the path from 4D's cache to the disk is beyond the component.
- **Protect the export set.** The set digest detects a change. The set is neither signed nor encrypted.
- **Run outside 4D local mode.** Every run refuses 4D Remote, 4D Server, tool4d and 4D Volume
  Desktop.
- **Read other versions' export sets.** Import and Compare need an export set written by the same
  version and build of the component, for the same structure and data language. The XML export
  files of earlier versions can't be read.

## Read next

- [How ExportImport works](how-it-works.md): the classes, the passes and their phases, and the worker pool.
- [Export set and run file formats](file-formats.md): what each file holds, down to the byte.
- [README](../README.md): installing, the dialog, the shared methods, the options and the verdicts.
