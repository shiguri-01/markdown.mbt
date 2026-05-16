# CommonMark Conformance

This script analyzes CommonMark 0.31.2 conformance separately from the regular
unit test suite. It uses the official JSON fixture vendored at
`../testdata/commonmark-0.31.2-spec.json`.

```bash
moon -C conformance run .
moon -C conformance run . --failed
moon -C conformance run . --section Links --failed
moon -C conformance run . --example 207
moon -C conformance run . --format json
```

The default report shows pass counts by CommonMark section. Use `--failed` or
`--example` when you need the markdown input, expected HTML, actual HTML, and
first differing offset for individual failures.
