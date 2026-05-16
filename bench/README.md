# Markdown Processing Benchmarks

Run from this directory:

```bash
moon bench --release
```

The benchmark suite keeps fixture construction and reusable processor
configuration outside measured closures and records library-level Markdown
processing scenarios. Benchmark names are grouped by what they are meant to
compare:

- `parse/scale/*`: parser throughput across fixture sizes for the same document
  shape.
- `pipeline/scale/*`: end-to-end parsing plus HTML rendering across fixture
  sizes.
- `parse/micro/*`: parser-only synthetic throughput cases.
- `parse/syntax/*`: focused syntax-heavy inputs such as list, delimiter, and
  reference-definition cases.
- `parse/extensions/*`: extension and plugin rule overhead.
- `render/*`, `transform/*`, and `ast/*`: post-parse processing from a
  pre-parsed event stream.

Fixture sizes:

| fixture | bytes | lines |
| --- | ---: | ---: |
| `paragraph_document` | 10,560 | 240 |
| `plain_throughput_document` | 202,000 | 4,000 |
| `single_paragraph_throughput_document` | 62,000 | 1 |
| `one_mb_single_paragraph_document` | 1,000,000 | 1 |
| `ten_mb_single_paragraph_document` | 10,000,000 | 1 |
| `list_document` | 7,880 | 180 |
| `delimiter_document` | 2,010 | 3 |
| `reference_document` | 9,170 | 360 |
| `mixed_document` | 14,652 | 842 |
| `large_mixed_document` | 48,912 | 2,802 |
| `huge_mixed_document` | 97,912 | 5,602 |
| `readme_like_document` | 15,747 | 372 |
| `readme_like_large_document` | 199,211 | 4,612 |
| `readme_like_huge_document` | 1,007,231 | 23,212 |
| `changelog_like_document` | 16,309 | 500 |
| `changelog_like_large_document` | 205,679 | 6,044 |
| `changelog_like_huge_document` | 1,011,256 | 29,562 |
| `issue_thread_document` | 25,153 | 899 |
| `issue_thread_large_document` | 200,411 | 7,129 |
| `issue_thread_huge_document` | 1,005,685 | 35,633 |
