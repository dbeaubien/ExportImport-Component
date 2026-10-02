# Two host seams: compatible shared methods and an exposed class namespace

The component has two host seams, and both must stay compatible.

- **The shared methods:** `Export_AllTables`, `Export_ListOfTables`, `Import_AllTables`,
  `Export_HealthCheck_Scan`, `Export_PreCheck_RemoveBadChars` and `Export_Import_Dialog`. The rewrite
  keeps their names and parameter lists, so each one is now a one-line wrapper that still returns a
  path.
- **The `ExportImport` class namespace:** `HealthCheckPass`, `FixerPass`, `ExportPass`, `ImportPass`
  and `ComparePass`, each with `check()` and `run()`. `run()` returns the full result object,
  including the verdict.

Downstream host systems call the shared methods, and hosts install the component from GitHub at
`latest`. Any change to those methods would therefore reach those hosts at their next update. The
methods can only return a path, so the namespace gives hosts the result object as a new seam. The
dialog drives the same classes.

## Considered Options

- **New method names that return the result object, with no aliases:** this breaks every downstream
  caller.
- **The old method names with new signatures (options in, an Object out):** this also breaks callers,
  at compile time.
- **Old seams only, and a namespace later:** hosts would get a verdict only by reading the report's
  `.json`.
- **New shared method names beside the old ones:** that gives two names per pass and adds nothing that
  the namespace doesn't already give.

## Consequences

- A component namespace exposes every class. In v21, a leading `_` only hides a class or function
  from code completion, and a host can still call it by name. So every internal class and function
  starts with `_`. That makes it private by convention only, and outside the compatibility promise.
- `Compare_ExportSet` is the only new shared method.
- The full decision is in `.scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md`. The 4D facts are in
  `.scratch/DONE/exact-copy-v2/research/12-classes-4d-facts.md`.
