using Wasmtime;

var engine = new Engine();

var module = Module.FromFile(engine, "quickjs_rust.wasm");
var linker = new Linker(engine);
linker.DefineWasi();
var store = new Store(engine);
store.SetWasiConfiguration(new WasiConfiguration());

var instance = linker.Instantiate(store, module);
var script = @"
`Hello from Javascript. Current date and time is ${new Date()}`";
var scriptptr = (int)instance.GetFunction("allocate_script").Invoke(script.Length);

var memory = instance.GetMemory("memory");
memory.WriteString(scriptptr, script);

var resultptr = (int)instance.GetFunction("run_js").Invoke();
var resultstring = memory.ReadNullTerminatedString(resultptr);
Console.WriteLine(resultstring);
           