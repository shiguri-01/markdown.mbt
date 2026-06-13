name = "shiguri-01/markdown"

version = "0.1.1"

readme = "src/README.mbt.md"

repository = "https://github.com/shiguri-01/markdown.mbt"

license = "Apache-2.0"

keywords = [ "markdown", "commonmark", "gfm", "html", "mdast" ]

supported_targets = [ "wasm", "wasm-gc", "js", "native" ]

description = "Event-driven Markdown parser with CommonMark, GFM, HTML, and AST support."

options(
  source: "src",
  exclude: [
    // Repository-only README symlink. Publish src/README.mbt.md instead.
    "AGENTS.md",
    "README.md",
    "flake.lock",
    "flake.nix",
    "justfile",
    "lefthook.yml",
    "src/tools",
    "testdata",
  ],
)
