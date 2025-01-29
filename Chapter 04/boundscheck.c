int numbers[] = {100,200};

__attribute__((export_name("boundscheck")))
int boundscheck(int index) {
    if (index < 0 || index >= 2) {
        return -1; // Error handling for invalid index
    }
    return numbers[index];
}
