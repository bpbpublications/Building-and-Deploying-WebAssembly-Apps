mod = await import('./pkg/c_linked_add.js');
await mod.default();
console.log(mod.add_numbers(2,3));