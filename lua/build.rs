use std::error::Error;
use std::fmt::Write as _;
use std::io;
use std::path::{Path, PathBuf};

const ROOT: &str = "uji";
const BOOK: &str = "../docs/src";

fn main() -> Result<(), Box<dyn Error>> {
    println!("cargo::rerun-if-changed={ROOT}");
    let manifest = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR")?);
    let mut files = Vec::new();
    files_in(&manifest.join(ROOT), "lua", &mut files)?;
    files.sort();
    let mut out = String::from("pub const FILES: &[(&str, &str)] = &[\n");
    for file in &files {
        writeln!(
            out,
            "    ({:?}, include_str!({:?})),",
            relative(file, &manifest)?,
            file.to_string_lossy()
        )?;
    }
    let version = format!("return {:?}", std::env::var("CARGO_PKG_VERSION")?);
    writeln!(out, "    (\"uji/version.lua\", {version:?}),")?;
    writeln!(
        out,
        "    (\"uji/docs.lua\", {:?}),",
        book(&manifest.join(BOOK))?
    )?;
    out.push_str("];\n");
    std::fs::write(
        PathBuf::from(std::env::var("OUT_DIR")?).join("files.rs"),
        out,
    )?;
    Ok(())
}

fn book(dir: &Path) -> Result<String, Box<dyn Error>> {
    println!("cargo::rerun-if-changed={BOOK}");
    let mut pages = Vec::new();
    if dir.is_dir() {
        files_in(dir, "md", &mut pages)?;
        pages.sort();
    }
    if pages.is_empty() {
        return Err(format!(
            "no book at {}: uji ships it inside the binary for /setup, so the build needs docs/src",
            dir.display()
        )
        .into());
    }
    let mut out = String::from("return {\n");
    for page in &pages {
        let text = std::fs::read_to_string(page)?;
        writeln!(
            out,
            "[{:?}] = {},",
            relative(page, dir)?,
            long_string(&text)
        )?;
    }
    out.push('}');
    Ok(out)
}

fn long_string(text: &str) -> String {
    let mut level = String::from("=");
    while text.contains(&format!("]{level}")) {
        level.push('=');
    }
    format!("[{level}[\n{text}]{level}]")
}

fn relative(file: &Path, base: &Path) -> Result<String, Box<dyn Error>> {
    let parts: Vec<_> = file
        .strip_prefix(base)?
        .components()
        .map(|part| part.as_os_str().to_string_lossy())
        .collect();
    Ok(parts.join("/"))
}

fn files_in(dir: &Path, extension: &str, out: &mut Vec<PathBuf>) -> io::Result<()> {
    for entry in std::fs::read_dir(dir)? {
        let path = entry?.path();
        if path.is_dir() {
            files_in(&path, extension, out)?;
        } else if path.extension().is_some_and(|ext| ext == extension) {
            out.push(path);
        }
    }
    Ok(())
}
