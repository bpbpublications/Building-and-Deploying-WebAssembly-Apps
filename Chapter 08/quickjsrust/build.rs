
fn main() {
    println!("cargo:rustc-link-lib=static={}", "quickjs");
    println!("cargo:rustc-link-lib=static={}", "jseval");
    println!("cargo:rustc-link-search=native={}", ".");
    println!("cargo:rustc-link-arg=--max-memory=16777216");
}
