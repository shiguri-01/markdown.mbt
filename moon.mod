name = "shiguri-01/markdown"

version = "0.1.0"

readme = "src/README.mbt.md"

repository = "https://github.com/shiguri-01/markdown.mbt"

license = "Apache-2.0"

keywords = [ "markdown", "commonmark", "parser", "html" ]

supported_targets = [ "wasm", "wasm-gc", "js", "native" ]

description = "Event-driven Markdown parser for MoonBit with CommonMark parsing, HTML rendering, transforms, and AST helpers."

options(
  source: "src",
  exclude: [ "src/tools" ],
)