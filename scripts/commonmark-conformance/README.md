# CommonMark Conformance

This script analyzes CommonMark 0.31.2 conformance separately from the regular
unit test suite. It uses the official JSON fixture vendored at
`../../testdata/commonmark-0.31.2-spec.json`.

```bash
moon -C scripts/commonmark-conformance run .
moon -C scripts/commonmark-conformance run . --failed
moon -C scripts/commonmark-conformance run . --section Links --failed
moon -C scripts/commonmark-conformance run . --example 207
moon -C scripts/commonmark-conformance run . --format json
```

The default report shows pass counts by CommonMark section. Use `--failed` or
`--example` when you need the markdown input, expected HTML, actual HTML, and
first differing offset for individual failures.
