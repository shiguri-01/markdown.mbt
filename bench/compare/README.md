# Cross Parser HTML Benchmarks

This directory compares `markdown.mbt` with external Markdown parsers on a
small set of HTML-rendering workloads.

The development shell installs the external comparators:

- `cmark`
- `markdown-it` via Bun

Run from the repository root:

```bash
nix develop
markdown-compare
```

The runner builds the MoonBit HTML renderer once in native release mode,
generates Markdown fixture files under `bench/compare/.generated/fixtures`,
then times each parser against the same input. `markdown.mbt` and `cmark` are
timed as external binaries. `markdown-it` is imported once and rendered directly
inside the Bun process, so per-iteration JS runtime startup is not included.
Each parser is warmed up 3 times by default before timing starts.

The fixture set is intentionally smaller than the internal `moon bench` suite:

- `readme_like_16kb`
- `readme_like_200kb`
- `issue_thread_25kb`
- `issue_thread_200kb`
