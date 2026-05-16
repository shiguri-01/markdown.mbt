# Markdown Processing Benchmarks

Run from this directory:

```bash
moon bench --release
```

The benchmark suite keeps fixture construction and reusable processor
configuration outside measured closures and records library-level Markdown
processing scenarios:

- `parse/*`: parser throughput for paragraph-heavy, list-heavy, delimiter,
  reference-definition, mixed CommonMark, plain throughput, and extension-rule
  inputs.
- `pipeline/parse_to_html`: end-to-end parsing plus HTML rendering.
- `render/html_from_events`: HTML rendering from a pre-parsed event stream.
- `transform/text_merge_softbreak`: event transform overhead.
- `ast/build_from_events`: AST construction from a pre-parsed event stream.

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
