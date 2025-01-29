// Function type
typedef int (*func_t)(int);

// Functions to be used
int makeDouble(int x) {
    return x + x;
}

int makeSquare(int x) {
    return x * x;
}

// Array of function pointers
func_t funcs[] = {makeDouble, makeSquare};

// Function to call a function based on an index
__attribute__((export_name("compute")))
int compute(int functionNumber, int value) {
    if (functionNumber < 0 || functionNumber >= 2) {
        return -1; // Error handling for invalid index
    }
    return funcs[functionNumber](value);
}