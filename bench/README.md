# Markdown Processing Benchmarks

Run from this directory:

```bash
moon bench --release
```

For native CPU profiling, use the dedicated profile runner from the repository
root:

```bash
nix develop --command just perf-record html issue_thread_200kb
nix develop --command just perf-report
```

The benchmark suite keeps fixture construction and reusable processor
configuration outside measured closures. Benchmark names are grouped by the
operation they measure:

- `html/*`: parse Markdown and render it to HTML.
- `parse/*`: parse Markdown into a counting sink that does not retain output.
- `rules/*`: parser overhead from additional rule registrations.
- `syntax/*`: focused syntax-heavy parser cases.
- `micro/*`: synthetic throughput and stress cases.

Fixture sizes:

| fixture | bytes | lines |
| --- | ---: | ---: |
| `one_mb_single_paragraph_document` | 1,000,000 | 1 |
| `delimiter_document` | 2,010 | 3 |
| `reference_document` | 9,170 | 360 |
| `readme_like_document` | 15,686 | 372 |
| `readme_like_large_document` | 198,302 | 4,612 |
| `readme_like_huge_document` | 1,002,602 | 23,212 |
| `issue_thread_document` | 25,153 | 899 |
| `issue_thread_large_document` | 200,411 | 7,129 |
| `issue_thread_huge_document` | 1,005,685 | 35,633 |
