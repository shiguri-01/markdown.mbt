///|
fn repeat_text(text : String, count : Int) -> String {
  let out = StringBuilder::new(size_hint=text.length() * count)
  for _ in 0..<count {
    out.write_string(text)
  }
  out.to_string()
}

///|
fn repeat_text_to_size(text : String, size : Int) -> String {
  let out = StringBuilder::new(size_hint=size)
  let mut remaining = size
  while remaining >= text.length() {
    out.write_string(text)
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
fn emphasis_mixed_document() -> String {
  repeat_text_to_size(
    "This parser paragraph mixes *emphasis*, **strong text**, [links](https://example.test/path), and `literal * markers _ inside code` while keeping normal prose around them.\n\n",
    200_000,
  )
}

///|
fn delimiter_literal_document() -> String {
  repeat_text_to_size(
    "literal a_b_c paths foo_bar_baz and escaped \\*stars\\* plus \\_underscores\\_ with punctuation ***** _____ around ordinary words.\n\n",
    200_000,
  )
}

///|
fn emphasis_nested_document() -> String {
  repeat_text_to_size(
    "***outer strong-em*** then **strong with *inner emphasis* text** and *emphasis with **inner strong** text* plus [*linked emphasis*](url).\n\n",
    200_000,
  )
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
  out.write_string("# markdown.mbt\n\n")
  out.write_string(
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling, rule hooks, and HTML rendering.\n\n",
  )
  out.write_string("## Installation\n\n")
  out.write_string("```moonbit\n")
  out.write_string("let html = @markdown.Html::new()\n")
  out.write_string("@markdown.Processor::new().parse(source, html.sink())\n")
  out.write_string("```\n\n")
  out.write_string("## Features\n\n")
  for i in 0..<count {
    out.write_string("### Feature area ")
    out.write_string(i.to_string())
    out.write_string("\n\n")
    out.write_string(
      "This section documents parser behavior for paragraphs, lists, links, code spans, and extension rules. ",
    )
    out.write_string(
      "It includes `inline code`, *emphasis*, **strong text**, and [cross references](#feature-area-",
    )
    out.write_string(i.to_string())
    out.write_string(").\n\n")
    out.write_string("- Parse source into a stable event stream.\n")
    out.write_string("- Render known CommonMark nodes to HTML.\n")
    out.write_string("- Preserve extension elements for downstream tools.\n\n")
    out.write_string(
      "> Note: rules can add new rules without changing the default preset.\n\n",
    )
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
fn issue_thread_document_comments(count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("# Parser regression discussion\n\n")
  for i in 0..<count {
    out.write_string("## Comment ")
    out.write_string(i.to_string())
    out.write_string("\n\n")
    out.write_string(
      "The failing input combines blockquotes, list items, escaped punctuation, and reference links in one report.\n\n",
    )
    out.write_string(
      "> Expected output should keep `code` intact and avoid merging unrelated paragraphs.\n\n",
    )
    out.write_string("- [ ] reproduce with native backend\n")
    out.write_string("- [x] add a focused regression test\n")
    out.write_string("- [ ] compare against the rendered HTML output\n\n")
    out.write_string("```text\n")
    out.write_string("line ")
    out.write_string(i.to_string())
    out.write_string(": *literal* [label][ref] <span>html</span>\n")
    out.write_string("```\n\n")
  }
  out.write_string("[ref]: /issues/parser-regression \"parser regression\"\n")
  out.to_string()
}

///|
fn no_op_inline_rule(
  _ctx : @markdown.InlineContext,
) -> @markdown.InlineRuleResult {
  NoMatch
}

///|
fn many_inline_rules_rule(count : Int) -> @markdown.Rule {
  let mut rule = @markdown.Rule::new("many-inline-rules")
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
  parse_event_count_with(@markdown.Processor::new(), input)
}

///|
fn parse_event_count_with(
  processor : @markdown.Processor,
  input : String,
) -> Int {
  let mut count = 0
  let sink = @markdown.Sink::new(fn(_event) { count = count + 1 })
  processor.parse(input, sink)
  count
}

///|
fn parse_with_rules_event_count(input : String) -> Int {
  parse_event_count_with(
    @markdown.Processor::new(
      rule=@markdown.commonmark().extend(many_inline_rules_rule(50)),
    ),
    input,
  )
}

///|
fn parse_render_length(input : String) -> Int {
  parse_render_length_with(@markdown.Processor::new(), input)
}

///|
fn parse_render_length_with(
  processor : @markdown.Processor,
  input : String,
) -> Int {
  let html = @markdown.Html::new()
  processor.parse(input, html.sink())
  html.to_string().length()
}

///|
test "benchmark fixtures produce work" {
  assert_eq(one_mb_single_paragraph_document().length(), 1_000_000)
  assert_true(parse_event_count(delimiter_document()) > 0)
  assert_true(parse_event_count(emphasis_mixed_document()) > 0)
  assert_true(parse_event_count(delimiter_literal_document()) > 0)
  assert_true(parse_event_count(emphasis_nested_document()) > 0)
  assert_true(parse_event_count(reference_document()) > 0)
  assert_true(parse_event_count(readme_like_document()) > 0)
  assert_true(parse_event_count(readme_like_large_document()) > 0)
  assert_true(parse_event_count(readme_like_huge_document()) > 0)
  assert_true(parse_event_count(issue_thread_document()) > 0)
  assert_true(parse_event_count(issue_thread_large_document()) > 0)
  assert_true(parse_event_count(issue_thread_huge_document()) > 0)
  assert_eq(readme_like_document().length(), 15_686)
  assert_eq(emphasis_mixed_document().length(), 200_000)
  assert_eq(delimiter_literal_document().length(), 200_000)
  assert_eq(emphasis_nested_document().length(), 200_000)
  assert_eq(readme_like_large_document().length(), 198_302)
  assert_eq(readme_like_huge_document().length(), 1_002_602)
  assert_eq(issue_thread_document().length(), 25_153)
  assert_eq(issue_thread_large_document().length(), 200_411)
  assert_eq(issue_thread_huge_document().length(), 1_005_685)
  assert_true(parse_with_rules_event_count(readme_like_document()) > 0)
  assert_true(parse_render_length(readme_like_document()) > 0)
}

///|
test "markdown processing speed" (b : @bench.T) {
  let one_mb_single_paragraph = one_mb_single_paragraph_document()
  let delimiter = delimiter_document()
  let emphasis_mixed = emphasis_mixed_document()
  let delimiter_literal = delimiter_literal_document()
  let emphasis_nested = emphasis_nested_document()
  let references = reference_document()
  let readme = readme_like_document()
  let large_readme = readme_like_large_document()
  let huge_readme = readme_like_huge_document()
  let issue_thread = issue_thread_document()
  let large_issue_thread = issue_thread_large_document()
  let huge_issue_thread = issue_thread_huge_document()
  let commonmark = @markdown.Processor::new()
  let commonmark_with_rules = @markdown.Processor::new(
    rule=@markdown.commonmark().extend(many_inline_rules_rule(50)),
  )
  b.bench(
    name="micro/plain_single/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, one_mb_single_paragraph)) },
    count=3,
  )
  b.bench(
    name="syntax/long_delimiter_runs",
    fn() { b.keep(parse_event_count_with(commonmark, delimiter)) },
    count=5,
  )
  b.bench(
    name="syntax/emphasis_mixed/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, emphasis_mixed)) },
    count=3,
  )
  b.bench(
    name="syntax/delimiter_literal/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, delimiter_literal)) },
    count=3,
  )
  b.bench(
    name="syntax/emphasis_nested/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, emphasis_nested)) },
    count=3,
  )
  b.bench(
    name="syntax/reference_definitions",
    fn() { b.keep(parse_event_count_with(commonmark, references)) },
    count=5,
  )
  b.bench(
    name="parse/readme_like/16kb",
    fn() { b.keep(parse_event_count_with(commonmark, readme)) },
    count=3,
  )
  b.bench(
    name="parse/readme_like/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, large_readme)) },
    count=3,
  )
  b.bench(
    name="parse/readme_like/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, huge_readme)) },
    count=3,
  )
  b.bench(
    name="rules/many_inline_rules",
    fn() { b.keep(parse_event_count_with(commonmark_with_rules, readme)) },
    count=5,
  )
  b.bench(
    name="html/readme_like/16kb",
    fn() { b.keep(parse_render_length_with(commonmark, readme)) },
    count=3,
  )
  b.bench(
    name="html/readme_like/200kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_readme)) },
    count=3,
  )
  b.bench(
    name="html/readme_like/1mb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_readme)) },
    count=3,
  )
  b.bench(
    name="html/issue_thread/25kb",
    fn() { b.keep(parse_render_length_with(commonmark, issue_thread)) },
    count=3,
  )
  b.bench(
    name="html/issue_thread/200kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_issue_thread)) },
    count=3,
  )
  b.bench(
    name="html/issue_thread/1mb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_issue_thread)) },
    count=3,
  )
}
