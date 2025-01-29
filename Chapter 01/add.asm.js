function Adder() {
    "use asm";

    function add(a, b) {
        a = a | 0;
        b = b | 0;
        return (a + b) | 0;
    }

    return {
        add: add
    };
}
const adder = new Adder();
console.log(adder.add(3,5));