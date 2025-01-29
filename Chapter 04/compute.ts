function makeDouble(x: i32): i32 {
    return x + x;
}

function makeSquare(x: i32): i32 {
    return x * x;
}

// Array of function pointers
const funcs = [makeDouble, makeSquare];

// Function to call a function based on an index

export function compute(functionNumber: i32, value: i32): i32 {
    if (functionNumber < 0 || functionNumber >= 2) {
        return -1; // Error handling for invalid index
    }
    return funcs[functionNumber](value);
}