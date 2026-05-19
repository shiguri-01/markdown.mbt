set shell := ["bash", "-cu"]

# List available tasks.
default:
  @just --list

# Type-check every MoonBit module in this repository.
check:
  moon check
  moon -C bench check
  moon -C conformance check
  moon -C bench/compare/markdown_html check

# Run the library test suite.
test:
  moon test

# Regenerate package interface files.
info:
  moon info

# Format every MoonBit module in this repository.
fmt:
  moon fmt
  moon -C bench fmt
  moon -C conformance fmt
  moon -C bench/compare/markdown_html fmt

# Run the standard local validation sequence.
verify:
  just check
  moon test
  moon info
  just fmt

# Run the CommonMark conformance report. Pass extra args after `--`.
conformance *args:
  moon -C conformance run . {{args}}

# Run internal Markdown processing benchmarks.
bench:
  moon -C bench bench --release

# Run cross-parser HTML benchmarks from the Nix dev shell.
compare:
  markdown-compare

# Record a native perf profile for the internal profile runner.
perf-record mode="html" fixture="issue_thread_200kb" repeats="80" warmups="10" output="/tmp/markdown-mbt.perf.data":
  moon -C bench build profile --target native --release --no-strip
  perf record -F 999 --call-graph dwarf -o {{output}} -- bench/_build/native/release/build/profile/profile.exe {{mode}} {{fixture}} {{repeats}} {{warmups}}

# Show the most useful perf report for a profile recorded by perf-record.
perf-report input="/tmp/markdown-mbt.perf.data" limit="1":
  perf report --stdio -i {{input}} --children --percent-limit {{limit}} --sort symbol | head -180

# Show flat self-time symbols for a profile recorded by perf-record.
perf-flat input="/tmp/markdown-mbt.perf.data" limit="1":
  perf report --stdio -i {{input}} --no-children --percent-limit {{limit}} --sort symbol | head -180
