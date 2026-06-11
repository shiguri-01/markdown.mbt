set shell := ["bash", "-cu"]

# List available tasks.
default:
  @just --list

# Type-check every MoonBit module in this repository.
check:
  moon check

# Run the library test suite.
test:
  moon test

# Regenerate package interface files.
info:
  moon info

# Format every MoonBit module in this repository.
fmt:
  moon fmt

# Run the standard local validation sequence.
verify:
  just check
  moon test
  moon info
  just fmt

# Run conformance.
#
# `gfm` intentionally runs only the GFM extension examples. The full GFM 0.29
# fixture is useful for diagnostics, but this parser targets CommonMark 0.31.2
# and the older GFM 0.29 fixture differs in non-extension emphasis examples.
conformance target="commonmark" *args:
  @case "{{target}}" in \
    commonmark|cmark|cm) moon run src/tools/conformance {{args}} ;; \
    gfm|gfm-ext|extensions|ext) moon run src/tools/conformance --dialect gfm --extensions-only {{args}} ;; \
    *) moon run src/tools/conformance {{target}} {{args}} ;; \
  esac

# Run internal Markdown processing benchmarks.
bench:
  moon bench --package shiguri-01/markdown/tools/benchmarks --release

# Run cross-parser HTML benchmarks from the Nix dev shell.
compare:
  markdown-compare

# Build the shared profiling workload.
prof-build target="wasm-gc":
  nix develop .#pprof -c moon build src/tools/benchmarks/profile --target {{target}} --release --no-strip

# Profile wasm-gc and print a summary.
prof-wasm-gc out="/tmp/markdown-mbt-wasm-gc.pb.gz" json="/tmp/markdown-mbt-wasm-gc.firefox.json":
  just prof-build wasm-gc
  nix develop .#pprof -c moon-pprof profile _build/wasm-gc/release/build/tools/benchmarks/profile/profile.wasm --out {{out}} --json-out {{json}}
  nix develop .#pprof -c moon-pprof summary {{out}}

# Profile native, convert to pprof, and print a summary.
prof-native out="/tmp/markdown-mbt-native.pb.gz" data="/tmp/markdown-mbt-native.perf.data" script="/tmp/markdown-mbt-native.perf.txt":
  just prof-build native
  nix develop .#pprof -c perf record -F 999 -e cpu-clock --call-graph dwarf -o {{data}} -- _build/native/release/build/tools/benchmarks/profile/profile.exe
  nix develop .#pprof -c bash -lc 'perf script -i "$1" > "$2"' bash {{data}} {{script}}
  nix develop .#pprof -c moon-pprof perf2pprof {{script}} --out {{out}}
  nix develop .#pprof -c moon-pprof summary {{out}}

# Print a moon-pprof summary for an existing pprof file.
prof-summary input:
  nix develop .#pprof -c moon-pprof summary {{input}}

# Compare two pprof files with moon-pprof's function-level diff.
prof-diff before after:
  nix develop .#pprof -c moon-pprof summary --diff {{before}} {{after}}
