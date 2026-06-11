///|
fn repeat_text(text : String, count : Int) -> String {
  let out = StringBuilder::new(size_hint=text.length() * count)
  for _ in 0..<count {
    out <+ "\{text}"
  }
  out.to_string()
}

///|
fn repeat_text_to_size(text : String, size : Int) -> String {
  let out = StringBuilder::new(size_hint=size)
  let mut remaining = size
  while remaining >= text.length() {
    out <+ "\{text}"
    remaining = remaining - text.length()
  }
  if remaining > 0 {
    out.write_view(text[:remaining])
  }
  out.to_string()
}

///|
fn one_mb_single_paragraph_document() -> String {
  repeat_text_to_size(
    "MoonBit markdown parser benchmark text without inline markup. ", 1_000_000,
  )
}

///|
fn long_space_run_document() -> String {
  "a" + repeat_text(" ", 16_384) + "*b*"
}

///|
fn delimiter_document() -> String {
  repeat_text("*", 500) +
  "text" +
  repeat_text("*", 500) +
  "\n\n" +
  repeat_text("_", 500) +
  "text" +
  repeat_text("_", 500)
}

///|
fn reference_document() -> String {
  let mut out = ""
  for i in 0..<120 {
    out = out +
      "[reference " +
      i.to_string() +
      "][id" +
      i.to_string() +
      "] in paragraph text.\n\n"
  }
  for i in 0..<120 {
    out = out +
      "[id" +
      i.to_string() +
      "]: /destination/" +
      i.to_string() +
      " \"title " +
      i.to_string() +
      "\"\n"
  }
  out
}

///|
fn readme_like_document() -> String {
  readme_like_document_sections(36)
}

///|
fn readme_like_large_document() -> String {
  readme_like_document_sections(460)
}

///|
fn readme_like_huge_document() -> String {
  readme_like_document_sections(2320)
}

///|
fn readme_like_document_sections(count : Int) -> String {
  let out = StringBuilder::new()
  out <+ "# markdown.mbt\n\n"
  out <+
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling, rule hooks, and HTML rendering.\n\n"
  out <+ "## Installation\n\n"
  out <+ "```moonbit\n"
  out <+ "let html = @markdown.Html(@commonmark.html_renderers())\n"
  out <+ "@markdown.Processor(@commonmark.rule()).parse(source, html.sink())\n"
  out <+ "```\n\n"
  out <+ "## Features\n\n"
  for i in 0..<count {
    out <+ "### Feature area "
    out <+ "\{i}"
    out <+ "\n\n"
    out <+
      "This section documents parser behavior for paragraphs, lists, links, code spans, and extension rules. "
    out <+
      "It includes `inline code`, *emphasis*, **strong text**, and [cross references](#feature-area-"
    out <+ "\{i}"
    out <+ ").\n\n"
    out <+ "- Parse source into a stable event stream.\n"
    out <+ "- Render known CommonMark nodes to HTML.\n"
    out <+ "- Preserve extension elements for downstream tools.\n\n"
    out <+
      "> Note: rules can add new rules without changing the default rule.\n\n"
  }
  out.to_string()
}

///|
fn issue_thread_document() -> String {
  issue_thread_document_comments(64)
}

///|
fn issue_thread_large_document() -> String {
  issue_thread_document_comments(509)
}

///|
fn issue_thread_huge_document() -> String {
  issue_thread_document_comments(2545)
}

///|
fn gfm_feature_document() -> String {
  gfm_feature_document_sections(52)
}

///|
fn gfm_feature_large_document() -> String {
  gfm_feature_document_sections(520)
}

///|
fn gfm_feature_document_sections(count : Int) -> String {
  let out = StringBuilder::new()
  out <+ "# GFM extension workload\n\n"
  for i in 0..<count {
    out <+ "## Iteration "
    out <+ "\{i}"
    out <+ "\n\n"
    out <+ "| task | owner | status |\n"
    out <+ "| :--- | ---: | :---: |\n"
    out <+ "| www.example.com/"
    out <+ "\{i}"
    out <+ " | @bot | ~~stale~~ |\n"
    out <+ "| foo"
    out <+ "\{i}"
    out <+ "@example.com | team | active |\n\n"
    out <+ "- [x] parse table rows with escaped pipes\n"
    out <+ "- [ ] render task list checkboxes\n"
    out <+ "- [x] link https://github.com/moonbitlang/moonbit-docs\n\n"
    out <+
      "A paragraph with ~~deleted text~~, www.commonmark.org/help, and a filtered <script>x</script> tag.\n\n"
  }
  out.to_string()
}

///|
fn issue_thread_document_comments(count : Int) -> String {
  let out = StringBuilder::new()
  out <+ "# Parser regression discussion\n\n"
  for i in 0..<count {
    out <+ "## Comment "
    out <+ "\{i}"
    out <+ "\n\n"
    out <+
      "The failing input combines blockquotes, list items, escaped punctuation, and reference links in one report.\n\n"
    out <+
      "> Expected output should keep `code` intact and avoid merging unrelated paragraphs.\n\n"
    out <+ "- [ ] reproduce with native backend\n"
    out <+ "- [x] add a focused regression test\n"
    out <+ "- [ ] compare against the rendered HTML output\n\n"
    out <+ "```text\n"
    out <+ "line "
    out <+ "\{i}"
    out <+ ": *literal* [label][ref] <span>html</span>\n"
    out <+ "```\n\n"
  }
  out <+ "[ref]: /issues/parser-regression \"parser regression\"\n"
  out.to_string()
}

///|
fn no_op_inline_rule(
  _ctx : @markdown.InlineContext,
  _sink : @markdown.Sink,
) -> @markdown.InlineRuleResult {
  NoMatch
}

///|
fn many_inline_rules_rule(count : Int) -> @markdown.Rule {
  let mut rule = @markdown.Rule("many-inline-rules")
  for i in 0..<count {
    rule = rule.extend(
      @markdown.Rule::inline(
        @markdown.RuleName::raw("x:inline:no_op:" + i.to_string()),
        priority=-i,
        no_op_inline_rule,
      ),
    )
  }
  rule
}

///|
fn parse_event_count(input : String) -> Int {
  parse_event_count_with(@markdown.Processor(@commonmark.rule()), input)
}

///|
fn parse_event_count_with(
  processor : @markdown.Processor,
  input : String,
) -> Int {
  let mut count = 0
  let sink = @markdown.Sink(fn(_event) { count = count + 1 })
  processor.parse(input, sink)
  count
}

///|
fn parse_with_rules_event_count(input : String) -> Int {
  parse_event_count_with(
    @markdown.Processor(@commonmark.rule().extend(many_inline_rules_rule(50))),
    input,
  )
}

///|
fn parse_render_length(input : String) -> Int {
  parse_render_length_with(@markdown.Processor(@commonmark.rule()), input)
}

///|
fn parse_render_length_with(
  processor : @markdown.Processor,
  input : String,
) -> Int {
  let html = @markdown.Html(
    @commonmark.html_renderers(),
    size_hint=input.length(),
  )
  processor.parse(input, html.sink())
  html.to_string().length()
}

///|
test "benchmark fixtures produce work" {
  let one_mb_len = one_mb_single_paragraph_document().length()
  assert_true(one_mb_len >= 999_000 && one_mb_len <= 1_001_000)
  let long_space_len = long_space_run_document().length()
  assert_true(long_space_len >= 16_000 && long_space_len <= 17_000)
  let readme_len = readme_like_document().length()
  assert_true(readme_len >= 15_000 && readme_len <= 17_000)
  let large_readme_len = readme_like_large_document().length()
  assert_true(large_readme_len >= 190_000 && large_readme_len <= 210_000)
  let huge_readme_len = readme_like_huge_document().length()
  assert_true(huge_readme_len >= 990_000 && huge_readme_len <= 1_010_000)
  let issue_thread_len = issue_thread_document().length()
  assert_true(issue_thread_len >= 24_000 && issue_thread_len <= 26_000)
  let large_issue_thread_len = issue_thread_large_document().length()
  assert_true(
    large_issue_thread_len >= 190_000 && large_issue_thread_len <= 210_000,
  )
  let huge_issue_thread_len = issue_thread_huge_document().length()
  assert_true(
    huge_issue_thread_len >= 990_000 && huge_issue_thread_len <= 1_010_000,
  )
  let gfm_len = gfm_feature_document().length()
  assert_true(gfm_len >= 18_000 && gfm_len <= 22_000)
  let large_gfm_len = gfm_feature_large_document().length()
  assert_true(large_gfm_len >= 190_000 && large_gfm_len <= 230_000)
  assert_true(parse_event_count(long_space_run_document()) > 0)
  assert_true(parse_event_count(delimiter_document()) > 0)
  assert_true(parse_event_count(reference_document()) > 0)
  assert_true(parse_event_count(readme_like_document()) > 0)
  assert_true(parse_event_count(readme_like_large_document()) > 0)
  assert_true(parse_event_count(readme_like_huge_document()) > 0)
  assert_true(parse_event_count(issue_thread_document()) > 0)
  assert_true(parse_event_count(issue_thread_large_document()) > 0)
  assert_true(parse_event_count(issue_thread_huge_document()) > 0)
  assert_true(parse_with_rules_event_count(readme_like_document()) > 0)
  assert_true(parse_render_length(readme_like_document()) > 0)
  let gfm = @markdown.Processor(@gfm.rule())
  assert_true(parse_event_count_with(gfm, gfm_feature_document()) > 0)
  assert_true(parse_render_length_with(gfm, gfm_feature_document()) > 0)
}

///|
test "markdown processing speed" (b : @bench.T) {
  let one_mb_single_paragraph = one_mb_single_paragraph_document()
  let long_space_run = long_space_run_document()
  let delimiter = delimiter_document()
  let references = reference_document()
  let readme = readme_like_document()
  let large_readme = readme_like_large_document()
  let huge_readme = readme_like_huge_document()
  let issue_thread = issue_thread_document()
  let large_issue_thread = issue_thread_large_document()
  let huge_issue_thread = issue_thread_huge_document()
  let gfm_features = gfm_feature_document()
  let large_gfm_features = gfm_feature_large_document()
  let commonmark = @markdown.Processor(@commonmark.rule())
  let gfm = @markdown.Processor(@gfm.rule())
  let commonmark_with_rules = @markdown.Processor(
    @commonmark.rule().extend(many_inline_rules_rule(50)),
  )
  b.bench(
    name="setup/commonmark_rule",
    fn() { b.keep(@commonmark.rule()) },
    count=10,
  )
  b.bench(
    name="setup/processor_commonmark",
    fn() { b.keep(@markdown.Processor(@commonmark.rule())) },
    count=10,
  )
  b.bench(name="setup/gfm_rule", fn() { b.keep(@gfm.rule()) }, count=10)
  b.bench(
    name="setup/processor_gfm",
    fn() { b.keep(@markdown.Processor(@gfm.rule())) },
    count=10,
  )
  b.bench(
    name="micro/plain_single/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, one_mb_single_paragraph)) },
    count=10,
  )
  b.bench(
    name="micro/long_space_run/16kb",
    fn() { b.keep(parse_event_count_with(commonmark, long_space_run)) },
    count=10,
  )
  b.bench(
    name="syntax/long_delimiter_runs",
    fn() { b.keep(parse_event_count_with(commonmark, delimiter)) },
    count=10,
  )
  b.bench(
    name="syntax/reference_definitions",
    fn() { b.keep(parse_event_count_with(commonmark, references)) },
    count=10,
  )
  b.bench(
    name="parse/readme_like/16kb",
    fn() { b.keep(parse_event_count_with(commonmark, readme)) },
    count=10,
  )
  b.bench(
    name="parse/readme_like/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, large_readme)) },
    count=10,
  )
  b.bench(
    name="parse/readme_like/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, huge_readme)) },
    count=10,
  )
  b.bench(
    name="parse/issue_thread/25kb",
    fn() { b.keep(parse_event_count_with(commonmark, issue_thread)) },
    count=10,
  )
  b.bench(
    name="parse/issue_thread/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, large_issue_thread)) },
    count=10,
  )
  b.bench(
    name="parse/issue_thread/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, huge_issue_thread)) },
    count=10,
  )
  b.bench(
    name="parse/gfm_features/20kb",
    fn() { b.keep(parse_event_count_with(gfm, gfm_features)) },
    count=10,
  )
  b.bench(
    name="parse/gfm_features/200kb",
    fn() { b.keep(parse_event_count_with(gfm, large_gfm_features)) },
    count=10,
  )
  b.bench(
    name="rules/many_inline_rules",
    fn() { b.keep(parse_event_count_with(commonmark_with_rules, readme)) },
    count=10,
  )
  b.bench(
    name="html/readme_like/16kb",
    fn() { b.keep(parse_render_length_with(commonmark, readme)) },
    count=10,
  )
  b.bench(
    name="html/readme_like/200kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_readme)) },
    count=10,
  )
  b.bench(
    name="html/readme_like/1mb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_readme)) },
    count=10,
  )
  b.bench(
    name="html/issue_thread/25kb",
    fn() { b.keep(parse_render_length_with(commonmark, issue_thread)) },
    count=10,
  )
  b.bench(
    name="html/issue_thread/200kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_issue_thread)) },
    count=10,
  )
  b.bench(
    name="html/issue_thread/1mb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_issue_thread)) },
    count=10,
  )
  b.bench(
    name="html/gfm_features/20kb",
    fn() { b.keep(parse_render_length_with(gfm, gfm_features)) },
    count=10,
  )
  b.bench(
    name="html/gfm_features/200kb",
    fn() { b.keep(parse_render_length_with(gfm, large_gfm_features)) },
    count=10,
  )
}
