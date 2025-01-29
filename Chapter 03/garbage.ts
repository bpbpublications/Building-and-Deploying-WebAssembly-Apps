let arr: (Array<i8> | null) = null;

for (let n = 0; n < 800; n++) {
    arr = new Array<i8>(100 * 1024 * 1024);
}
