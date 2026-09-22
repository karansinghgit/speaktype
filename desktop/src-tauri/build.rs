fn main() {
    // Parakeet runs on ONNX Runtime, which ships no build for Intel Macs, so the
    // Intel half of the universal macOS app leaves Parakeet out. Code checks
    // `#[cfg(parakeet)]`; Cargo.toml drops the dependency for the same target.
    println!("cargo::rustc-check-cfg=cfg(parakeet)");
    let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();
    if !(os == "macos" && arch == "x86_64") {
        println!("cargo::rustc-cfg=parakeet");
    }
    tauri_build::build()
}
