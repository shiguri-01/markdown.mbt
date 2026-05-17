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
