# Research 12: 4D v21 facts for a class-based host API

Ticket: [issues/12-define-shared-api.md](../issues/12-define-shared-api.md)
Date: 2026-10-01. Docs version: 4D v21 (developer.4d.com `/docs/21/`, read from the Markdown source in
the official [4D/docs repo][repo], `versioned_docs/version-21/`, commit `034b1c5` of 2026-09-25).
Where a fact is only in a later release, the 21 R3 page (`/docs/21-R3/`) is cited. 21 R4 is still a
beta, so it is used only to check that nothing changed.

## Method and evidence rules

- Primary sources only: developer.4d.com v21 (and 21 R3 where stated), blog.4d.com, kb.4d.com. Each
  claim has a link. Link labels are listed under [Sources](#sources).
- "Thread safe" is the **Properties** table at the bottom of each command page.
- **[gap]** marks a question the primary sources do not answer. It needs a test in 4D. Nothing
  under [gap] is a guess about 4D's behaviour.
- **[inference]** marks a conclusion drawn from two or more documented facts that no single page
  states. The facts it rests on are cited.
- kb.4d.com and blog.4d.com were searched for each question. Where nothing relevant turned up, the
  section says so.
- Facts only. No design choice is made here.

## Gist

- **Component namespace (since v19 R5).** One setting per component exposes **every** user class
  as `cs.<namespace>.<Class>`. The host can declare, instantiate and call functions on them. This
  works for compiled (`.4dz`) components. There is no per-class or per-function switch. An
  underscore prefix only hides a class or function from code completion; it can still be called by
  name. A component's ORDA classes are never exposed. The host cannot `extend` a component class.
- **Context.** `cs` and `Storage` are per component, and commands called from a component run in
  the component's context. A Formula runs in the context of the project or component that created
  it. That a class function called **by the host** runs with the component's `cs` and `Storage` is
  an [inference]; no page says it directly.
- **Passing instances between processes.** A non-shared object passed to `New process`,
  `CALL WORKER` or `CALL FORM` is **copied**. **Whether the copy keeps its class (functions) is not
  documented.** JSON streaming loses the class, and `VARIABLE TO BLOB` keeps it (21 R3 docs), but no
  page says which mechanism the inter-process copy uses. An instance of a **shared** class is a
  shared object, so it is passed by reference. 4D's own example calls a shared instance's function
  from a worker.
- **Shared classes and singletons** came in 20 R5 and session singletons in 20 R7. Shared
  singletons are shared objects, readable from preemptive processes without `Use`. Using singletons
  inside a component, and whether the host's `cs.<ns>.X.me` is the same instance as the
  component's `cs.X.me`: **not documented**.
- **Class functions in preemptive code.** Class functions have **no** execution-mode property. A
  thread-unsafe class function raises an error only at **runtime**, never at compile time. 4D's own
  examples pass `Formula(cs.X.new(...))` and `Formula(cs.X.me.fn())` to `CALL WORKER`. How 4D picks
  preemptive or cooperative for a worker whose message is a Formula: **not documented**.
- **Entry points.** `New process` takes only a method **name** (Text), in v21 and 21 R3.
  `CALL WORKER` and `CALL FORM` take a Formula object or a method name (since 19 R6). Passing a
  bare class function (`$instance.fn`) instead of a Formula: **not documented**. A form can be bound
  to a component class through its Form class property (20 R8).
- **JSON.** `JSON Stringify` on a class instance includes computed (`get`) properties (blog, v19 R3)
  and drops the class (21 R3 docs). Whether the host can use an instance of a class that is **not**
  exposed: **not documented**.

---

## 1. Component namespace: exposing classes to the host

### Facts

- **Default is closed:** "By default, component classes cannot be called from the 4D Code Editor
  of the host project. If you want your component classes to be exposed in the host project and
  its loaded components, you need to **declare a component namespace**." The setting is
  **Component namespace in the class store** on the General page of the matrix project's Settings.
  "By default, the area is empty: component classes are not available outside of the component
  context" ([Developing components][comp], [Settings: General][setgen]).
- **Syntax:** after you enter a value, "component classes will be available in the user class
  store (**cs**) of the host project as well as its loaded components, through the `cs.<value>`
  namespace". Documented example ([Developing components][comp]):
  `var $rect: cs.eGeometry.Rectangle` / `$rect:=cs.eGeometry.Rectangle.new(10;20)` /
  `$area:=$rect.getArea()`. `cs.<namespace>` is a `4D.ClassStore` "published by a component", named
  after the namespace ([ClassStore][classstore]). `cs.<namespace>.<className>` is a valid
  `property` type ([Classes][classes]).
- **Since:** v19 R5: "As of 4D v19 R5, [a component] is also a group of classes" (blog of
  2022-04-25, [Blog: component classes][blogcomp]). Since 20 R6, a namespaced component's classes
  are also shared with every other component loaded in the host ([Release notes][updates],
  [Blog: classes across components][blogacross]).
- **All classes or some?** The namespace is one setting for the whole component. It exposes the
  component's classes; the docs offer no per-class option ([Developing components][comp]).
  - **Exception:** "A component's ORDA classes are not available in its host project"
    ([Developing components][comp]).
  - **Underscore prefix:** hidden classes and functions "will not appear as suggestions when using
    code completion. Note however that they can still be used if you know their names", for
    example `cs.eGeometry._Rectangle.new(10;20)` ([Developing components][comp]). A function whose
    name starts with `_` is likewise only left out of autocompletion ([Classes][classes]). The
    v19 R5 blog says to prefix "internal classes you want to hide" with `_`; the v21 page shows the
    hiding is for completion only ([Blog: component classes][blogcomp]).
  - **Name clash:** "If a user class with the same name as a component namespace already exists in
    the project, the user class is taken into account and the component classes are ignored"
    ([Developing components][comp]).
- **Compiled components:** "When a compiled matrix project is installed as a component: The shared
  project methods, classes and functions can be called in the methods of the host project and are
  also visible on the Methods Page of the Explorer. However, their contents will not appear in the
  preview area and in the debugger." A compiled component's namespace is shown in parentheses after
  its name in the Explorer ([Developing components][comp], [Components][components]). A built
  component is `MyComponent.4dbase/Contents/` with the `.4DZ` inside ([Build][building]). A
  compiled host can use only compiled components ([Developing components][comp]).
- **Code completion for compiled components:** the **Generate syntax file for code completion when
  compiled** option writes a JSON syntax file. "If you don't enter a component namespace, the
  resources for the classes and exposed methods are not generated even if the syntax file option
  is checked" ([Developing components][comp]).
- **Host instantiates and calls:** yes. See the example above, and the compiled-component quote
  ([Developing components][comp]).
- **Inheritance:** "A user class cannot extend a user class from another project or component"
  ([Classes][classes]). The host cannot subclass a component class.
- **Form class:** a form's **Form class** property can name a component class as
  `"componentNameSpace.className"`. 4D then instantiates it for `Form` ([Form properties][formprops]).
  Added in 20 R8 ([Blog: form class][blogform]).
- **Component context:**
  - `cs` "returns the user class store for the current project or component". Thread safe: **yes**
    ([Classes][classes], [cs][cs]).
  - "When commands are called from a component, they are executed in the context of the component,
    except for the `EXECUTE FORMULA` or `EXECUTE METHOD` command". `SET DATABASE PARAMETER` and
    `Get database parameter` are global ([Developing components][comp]).
  - `Storage`: "There is one **Storage** catalog per machine and component ... if the database uses
    components, there is one **Storage** object per component". Thread safe: **yes**
    ([Storage][storage]). The KB says the same: "Each component has its own catalog that is
    separate from the host database" ([KB: Storage scopes][kbstorage]).
  - A Formula object "is evaluated within the context of the database or component that created
    it" ([Formula][formula]).
  - "Variables are not shared between components and host projects" ([Developing components][comp]).
  - The host's `ON ERR CALL` handler is not called for component errors. The host can install
    `ON ERR CALL(...; ek errors from components)` for errors no component handler caught
    ([Developing components][comp], [Error handling][errh]).
- **Shared-by-host attribute at class or function level:** none is documented. **Shared by
  components and host project** is a project-method property ([Developing components][comp]).
  The Method Properties page says "The other types of methods do not have specific properties"
  ([Project method properties][pmp]).

### [gap]

- [inference] A component class function called by the host runs with the component's `cs` and
  `Storage`. This rests on `cs` being "for the current project or component", on `Storage` being
  per component, and on commands from a component running in its context
  ([Classes][classes], [Storage][storage], [Developing components][comp]). No page states it for a
  class function called from the host. Test: from the host, call a component function that returns
  `OB Keys(cs)` and a `Storage` property only the component sets.
- kb.4d.com has nothing more on namespaces.

## 2. Passing class instances between processes

### Facts

- **`New process`:** "standard object or collection type parameters are passed **by copy**, *i.e.*
  4D will create a copy of the object or the collection in the destination process instead of a
  reference. If you want to pass an object or a collection parameter **by reference**, you must use
  a shared object or collection" ([New process][np]).
- **`CALL WORKER`:** the same, "if the worker is in a process different from the one calling the
  **CALL WORKER** command" ([CALL WORKER][cw]).
- **`CALL FORM`:** "4D creates a copy of the object or the collection in the destination process
  (instead of a reference) if the form is in a process different from the one calling the
  **CALL FORM** command" ([CALL FORM][cf]).
- **Shared objects** "can be passed by reference as parameters to commands such as `New process`
  or `CALL WORKER`" ([Shared objects][shared]). A shared class "instantiates a shared object when
  the `new()` function is called on the class. A shared class can only create shared objects"
  ([Classes][classes]).
- **4D's own worker example with a shared class instance** (20 R5): the instance is created in one
  process, the worker runs `CALL WORKER("AnyWorker"; Formula($calculation.makeCalculation()))`, and
  the caller polls `$calculation.isFinished` while the worker updates it through a `shared`
  setter ([Blog: shared classes][blogshared]).
- **Copies of shared objects:** `OB Copy` on a shared object "will return a standard (not shared)
  object" unless `ck shared` is passed ([Shared objects][shared], [OB Copy][obcopy]). The `OB Copy`
  page says nothing about classes.
- **Streaming and classes** (21 R3 docs, not in the v21 page): text streaming (`JSON Stringify`,
  `Execute on server`) supports "objects, collections, and user classes", but "a class object loses
  its class when it is stringified". Binary streaming (`VARIABLE TO BLOB`): "objects keep their
  class" ([Object 21 R3][object213]).
- **Formula capture:** "If *formulaExp* uses local variables, their values are copied and stored in
  the returned formula object when it is created" ([Formula][formula]).
- **Typed parameters catch a lost class:** passing an object of the wrong class to a parameter
  declared `cs.MyClass1` is an error ("wrong class instance, cs.MyClass1 expected")
  ([Parameters][params]).

### [gap]

- **Whether the copy of a non-shared class instance keeps its class** (functions, computed
  properties) or arrives as a plain object, for `New process`, `CALL WORKER` and `CALL FORM`. No
  page says which streaming the inter-process copy uses. kb.4d.com and blog.4d.com have nothing.
  Test: in the receiving process, check `OB Instance of($p; cs.X)`, `OB Class($p).name`, and call a
  function. A receiver that declares `$p : cs.X` will error if the class is lost
  ([Parameters][params]).
- [inference] A **shared** class instance passed as a parameter keeps its class. The receiver gets
  a reference to the same object, not a copy ([Shared objects][shared], [Classes][classes]), and
  4D's example calls its function from a worker ([Blog: shared classes][blogshared]).
- A **non-shared** object captured in a Formula that is sent to another process: whether the worker
  sees a copy or the same instance. The 4D example uses a shared instance only.

## 3. Shared classes and singletons

### Facts

- **Versions:** shared classes, singletons and shared singletons: **20 R5** ([Release notes][updates],
  [Blog: shared classes][blogshared], [Blog: singletons][blogsingle]). `.isShared`, `.isSingleton` and
  `.me`: history "20 R5 Added". Session singletons and `.isSessionSingleton`: **20 R7**
  ([Release notes][updates], [Class][classclass]).
- **Syntax:** `shared Class constructor`, `singleton Class constructor()` (process singleton),
  `shared singleton Class constructor()`, `session singleton Class constructor()`. "Session
  singletons are automatically shared singletons" ([Classes][classes]).
- **Scope:** a process singleton "has a unique instance for the process in which it is
  instantiated". A shared singleton "has a unique instance for all processes on the machine". In
  4D single-user, a shared singleton is application-wide. A session singleton is per session. A
  singleton "exists as long as a reference to it exists somewhere in the application running on the
  machine" ([Classes][classes]).
- **Creation:** `.me` "calls the class constructor without parameters and creates the instance" the
  first time. After that it returns the existing instance. `new()` can pass parameters if it is the
  first access. On an already created singleton, `new()` returns the existing instance
  ([Class][classclass], [Classes][classes], [Blog: singletons][blogsingle]).
- **Shared functions:** `shared Function` wraps the call in an automatic `Use...End use`. The
  keyword is ignored in a non-shared class. A shared class cannot extend a non-shared class
  ([Classes][classes], [Blog: shared classes][blogshared]).
- **Thread safety:** "Singletons are standard objects, while shared singletons are shared objects"
  ([Blog: singletons][blogsingle]). Shared objects are "compatible with Preemptive processes", and
  "reading properties or elements of a shared object/collection is allowed without having to call
  the `Use...End use` structure" ([Shared objects][shared]). KB: "Since singletons are designed to
  be preemptive capable, it uses the similar mechinisms to Storage". Writing a shared singleton's
  property directly needs `Use...End use`, unless it goes through a `shared` setter
  ([KB: singleton properties][kbsingle]). `cs` is thread safe ([cs][cs]). "A class object itself is
  a shared object and can therefore be accessed from different 4D processes simultaneously"
  ([Classes][classes]).
- **Singleton plus worker in 4D's own examples:** `CALL WORKER("WebSocketServerWorker";
  Formula(cs.WebSocketServerWrapper.me))`, then `...me.terminate()` through the same worker (a
  process singleton living in that worker) ([Blog: singletons][blogsingle]).
- **Components:** "A component can call on most of the 4D elements: datastore (`ds`), classes,
  functions, project methods, ..." No restriction on singletons or shared classes is listed
  ([Developing components][comp]).

### [gap]

- Singletons and shared classes **inside a component**: not documented either way. Nothing forbids
  them.
- Whether the host's `cs.<ns>.X.me` returns the same instance as `cs.X.me` inside the component.
  [inference] Probably yes for a shared singleton, since the namespace exposes the component's own
  class objects ([ClassStore][classstore]). A host class of the same name would be a separate class
  in a separate store ([Classes][classes]). No page says so.
- How 4D handles a shared singleton when the host and two components all reach it. Not covered.

## 4. Class functions in preemptive processes

### Facts

- **No execution-mode property for class functions.** The **Can be run / Cannot be run /
  Indifferent** options live in the Method Properties dialog of project methods
  ([Preemptive processes][preemptive]). "The other types of methods do not have specific
  properties" ([Project method properties][pmp]).
- **Runtime check only:** "If a class function is not thread-safe and called by a method with the
  'Can be run in preemptive process' attribute: the compiler does not generate any error (which is
  different compared to regular methods), an error is thrown by 4D only at runtime"
  ([Classes][classes]).
- ORDA data model class functions run "in preemptive or cooperative processes (depending on the
  calling process)" in single-user. Thread-unsafe code then throws an error at runtime
  ([ORDA classes][orda]). A KB note shows error -10529 "Can't call not thread safe method from
  preemptive process" for a class function called through REST ([KB: -10529][kbrest]).
- **Process start rule:** "In compiled mode, when starting a process created by either `New process`
  or `CALL WORKER` commands, 4D reads the preemptive property of the process method". An
  "indifferent" process method runs cooperatively ([Preemptive processes][preemptive]).
  Interpreted mode is always cooperative ([Preemptive processes][preemptive]).
- **Shared component methods:** "If the method has also the **Shared by components and host
  database** property, setting the **Indifferent** option will automatically tag the method as
  thread-unsafe. If you want a shared component method to be thread-safe, you must explicitely set
  it to **Can be run in preemptive processes**" ([Preemptive processes][preemptive]).
- **Formula in `CALL WORKER`:** "a **formula object** ... Formula objects can encapsulate any
  executable expressions, including functions and project methods". Thread safe: **yes**
  ([CALL WORKER][cw]).
- **4D's own examples of class code sent to a worker:**
  `CALL WORKER("myServerUDP"; Formula(cs.serverUDP.new(12345)))` ([Blog: UDP][blogudp]);
  `CALL WORKER("WebSocketServer"; Formula(wss:=4D.WebSocketServer.new($handler)))`
  ([WebSocketServer][wss]); `Formula(cs.WebSocketServerWrapper.me.terminate())`
  ([Blog: singletons][blogsingle]); `Formula($calculation.makeCalculation())`
  ([Blog: shared classes][blogshared]). For 4D's async classes, "Callbacks can be passed as class
  functions (recommended) or Formula objects" ([Asynchronous execution][async]).
- **Checking the mode:** `Process info(Current process).preemptive` is "True if run preemptive"
  ([Process info][pinfo]).

### [gap]

- **How 4D decides preemptive or cooperative for a worker whose message is a Formula.** The docs
  define the rule only for a process **method** and its property. A Formula has no such property.
  Test (compiled): in the formula's code, read `Process info(Current process).preemptive`, once for
  a worker first created by a Formula and once for a worker first created by a thread-safe method
  name.
- Whether the compiler checks the thread safety of class functions reached through a Formula. The
  only documented statement is the runtime-error warning above ([Classes][classes]).
- No restriction specific to calling class functions through `CALL WORKER` with a Formula is
  documented.

## 5. Class functions as process or form entry points

### Facts

- **`New process(method : Text; ...)`:** *method* is "the name of the process method". The type is
  Text only, in v21 and in 21 R3 ([New process][np], [New process 21 R3][np213]). It does not take a
  Formula.
- **`CALL WORKER` and `CALL FORM`:** *formula* is "Object, Text", that is "Formula object or Name of
  project method". History: "19 R6 Modified" ([CALL WORKER][cw], [CALL FORM][cf]). Blog: "Starting
  with 4D v19 R6, 4D allows you to use a formula to define a callback in the collection member
  functions, the EXECUTE METHOD IN SUBFORM, CALL FORM, and CALL WORKER commands"
  ([Blog: formulas in callbacks][blogformulas]).
- **Worker startup method:** an empty *formula* "executes the method that was originally used to
  start its process, if any (i.e., the startup method of the worker)" ([CALL WORKER][cw]). Only
  workers have a message box. A process created by `New process` cannot be called by `CALL WORKER`
  ([Processes and workers][processes]).
- In 21 R3, Formula objects became instances of `4D.Formula`, which inherits from `4D.Function`
  ([Release notes 21 R3][updates213]). User class functions are also `4D.Function` objects
  ([Function][function]).
- **Forms:** `DIALOG(form; formData)`. If a Form class is set and no *formData* is passed, 4D
  instantiates the class. A *formData* object has priority. The class can come from a component
  through its namespace ([DIALOG][dialog], [Form properties][formprops]). 4D's blog example passes
  a class instance as *formData* in the same process ([Blog: form class][blogform]).

### [gap]

- Passing a bare class function as *formula* (`CALL WORKER($name; $instance.fn; ...)`) instead of a
  Formula object. The pages say "formula object". [inference] Even if accepted, `This` would not be
  the instance, because `This` "is determined by how a function is called"
  ([This][this]). 4D's examples always wrap the call: `Formula($instance.fn())`.
- What the "startup method" of a worker first created by a Formula is, for a later
  `CALL WORKER($name; "")`. The "if any" wording suggests none.

## 6. JSON and returning instances to the host

### Facts

- The v21 `JSON Stringify` page says nothing about classes, functions or computed properties
  ([JSON Stringify][jsonstr]).
- **Computed properties are included:** "When you use an object with computed properties, these
  properties will be considered when you 'stringify' it", followed by
  `ALERT(JSON Stringify($rect;*))` (blog, v19 R3) ([Blog: computed properties][blogcomputed]).
- **The class is dropped:** "a class object loses its class when it is stringified" (21 R3 docs)
  ([Object 21 R3][object213]).
- **Declared properties:** `property` declarations "are not automatically added to objects (they are
  only added when they are assigned a value)", unless initialized on the declaration line
  ([Classes][classes]).
- Class functions "are specific properties of the class", not of the instance ([Classes][classes]).
- **Unexposed classes:** without a namespace, "component classes are not available outside of the
  component context" ([Developing components][comp]).

### [gap]

- Whether functions or `_`-prefixed properties appear in `JSON Stringify` output. [inference]
  Functions do not, since they belong to the class, not the instance ([Classes][classes]). The
  reference page does not say.
- **An instance of a non-exposed component class returned to the host**: whether the host can call
  its functions (`$o.fn()`), read its computed properties, or test it with `OB Class` and
  `OB Instance of`. Not documented. The host could not type a variable as that class, since it has
  no `cs.<ns>` path ([Developing components][comp]). Test it with a compiled component.

## Other facts found on the way

- Classes appeared in 18 R3 (`.new()`, `.name`, `.superclass`). The `cs` command page says
  "19 Created" ([Class][classclass], [cs][cs]).
- Shared project methods of a component are shown in the host's Explorer and can be viewed in the
  debugger, unless the component is compiled ([Developing components][comp]).
- From the host, component code can be edited in interpreted mode, including classes that are not
  shared ([Developing components][comp]).
- 21 R4 (beta) adds `local` and `server` keywords for shared and session singleton functions in
  client/server ([Classes 21 R4 beta][classesbeta]). Not relevant to a 4D local component, and not
  yet released.
- kb.4d.com searches on component classes, class copies between processes, and Formula-started
  workers found nothing beyond the two KB notes cited. blog.4d.com had the posts cited above.

## Sources

[repo]: https://github.com/4D/docs
[comp]: https://developer.4d.com/docs/21/Extensions/develop-components
[components]: https://developer.4d.com/docs/21/Concepts/components
[setgen]: https://developer.4d.com/docs/21/settings/general
[classes]: https://developer.4d.com/docs/21/Concepts/classes
[classclass]: https://developer.4d.com/docs/21/API/ClassClass
[classstore]: https://developer.4d.com/docs/21/API/ClassStoreClass
[cs]: https://developer.4d.com/docs/21/commands/cs
[function]: https://developer.4d.com/docs/21/API/FunctionClass
[formula]: https://developer.4d.com/docs/21/commands/formula
[this]: https://developer.4d.com/docs/21/commands/this
[storage]: https://developer.4d.com/docs/21/commands/storage
[shared]: https://developer.4d.com/docs/21/Concepts/shared
[obcopy]: https://developer.4d.com/docs/21/commands/ob-copy
[params]: https://developer.4d.com/docs/21/Concepts/parameters
[np]: https://developer.4d.com/docs/21/commands/new-process
[np213]: https://developer.4d.com/docs/21-R3/commands/new-process
[cw]: https://developer.4d.com/docs/21/commands/call-worker
[cf]: https://developer.4d.com/docs/21/commands/call-form
[processes]: https://developer.4d.com/docs/21/Develop/processes
[preemptive]: https://developer.4d.com/docs/21/Develop/preemptive-processes
[async]: https://developer.4d.com/docs/21/Develop/async
[pinfo]: https://developer.4d.com/docs/21/commands/process-info
[pmp]: https://developer.4d.com/docs/21/Project/project-method-properties
[orda]: https://developer.4d.com/docs/21/ORDA/ordaClasses
[errh]: https://developer.4d.com/docs/21/Concepts/error-handling
[building]: https://developer.4d.com/docs/21/Desktop/building
[formprops]: https://developer.4d.com/docs/21/FormEditor/propertiesForm
[dialog]: https://developer.4d.com/docs/21/commands/dialog
[wss]: https://developer.4d.com/docs/21/API/WebSocketServerClass
[jsonstr]: https://developer.4d.com/docs/21/commands/json-stringify
[object213]: https://developer.4d.com/docs/21-R3/Concepts/object#streaming-support
[updates]: https://developer.4d.com/docs/21/Notes/updates
[updates213]: https://developer.4d.com/docs/21-R3/Notes/updates
[classesbeta]: https://developer.4d.com/docs/Concepts/classes#local-and-server
[blogcomp]: https://blog.4d.com/access-your-component-classes-from-your-host-project/
[blogacross]: https://blog.4d.com/using-classes-across-components/
[blogshared]: https://blog.4d.com/shared-classes/
[blogsingle]: https://blog.4d.com/singletons-in-4d/
[blogformulas]: https://blog.4d.com/the-use-of-formulas-in-collections-callback-commands/
[blogudp]: https://blog.4d.com/new-class-to-perform-udp-communications/
[blogcomputed]: https://blog.4d.com/need-a-magic-wand-here-are-computed-class-properties/
[blogform]: https://blog.4d.com/empower-your-development-process-with-your-forms
[kbstorage]: https://kb.4d.com/assetid=79406
[kbsingle]: https://kb.4d.com/assetid=79496
[kbrest]: https://kb.4d.com/assetid=79551
