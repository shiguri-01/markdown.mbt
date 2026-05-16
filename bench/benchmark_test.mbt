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
fn paragraph_document() -> String {
  repeat_text(
    "MoonBit markdown parser benchmark text with *emphasis*, **strong**, and [links](/url).\n\n",
    120,
  )
}

///|
fn plain_throughput_document() -> String {
  repeat_text(
    "MoonBit markdown parser benchmark text without inline markup for sustained throughput measurements.\n\n",
    2000,
  )
}

///|
fn single_paragraph_throughput_document() -> String {
  repeat_text(
    "MoonBit markdown parser benchmark text without inline markup. ", 1000,
  )
}

///|
fn one_mb_single_paragraph_document() -> String {
  repeat_text_to_size(
    "MoonBit markdown parser benchmark text without inline markup. ", 1_000_000,
  )
}

///|
fn ten_mb_single_paragraph_document() -> String {
  repeat_text_to_size(
    "MoonBit markdown parser benchmark text without inline markup. ", 10_000_000,
  )
}

///|
fn list_document() -> String {
  let mut out = ""
  for i in 0..<180 {
    out = out +
      "- item " +
      i.to_string() +
      " with [link](/item/" +
      i.to_string() +
      ") and `code`\n"
  }
  out
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
fn mixed_document() -> String {
  mixed_document_sections(60)
}

///|
fn large_mixed_document() -> String {
  mixed_document_sections(200)
}

///|
fn huge_mixed_document() -> String {
  mixed_document_sections(400)
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
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling, plugin hooks, and HTML rendering.\n\n",
  )
  out.write_string("## Installation\n\n")
  out.write_string("```moonbit\n")
  out.write_string("let events = @markdown.parse(source)\n")
  out.write_string("let html = @markdown.to_html(events)\n")
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
      "> Note: plugins can add new rules without changing the default preset.\n\n",
    )
  }
  out.to_string()
}

///|
fn changelog_like_document() -> String {
  changelog_like_document_sections(8, 10)
}

///|
fn changelog_like_large_document() -> String {
  changelog_like_document_sections(20, 50)
}

///|
fn changelog_like_huge_document() -> String {
  changelog_like_document_sections(37, 132)
}

///|
fn changelog_like_document_sections(
  major_count : Int,
  patch_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("# Changelog\n\n")
  out.write_string("All notable changes to this package are recorded here.\n\n")
  for major in 0..<major_count {
    out.write_string("## ")
    out.write_string(major.to_string())
    out.write_string(".0.0\n\n")
    for patch in 0..<patch_count {
      out.write_string("### ")
      out.write_string(major.to_string())
      out.write_string(".")
      out.write_string(patch.to_string())
      out.write_string(".0\n\n")
      out.write_string("- Added parser coverage for case `cm-")
      out.write_string(major.to_string())
      out.write_string("-")
      out.write_string(patch.to_string())
      out.write_string("` with [spec links](/commonmark/")
      out.write_string(patch.to_string())
      out.write_string(").\n")
      out.write_string(
        "- Fixed rendering around nested emphasis and code spans.\n",
      )
      out.write_string(
        "- Updated benchmark fixtures and documentation snippets.\n\n",
      )
    }
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
fn mixed_document_sections(count : Int) -> String {
  let mut out = "# Benchmark Document\n\n"
  for i in 0..<count {
    out = out +
      "## Section " +
      i.to_string() +
      "\n\n" +
      "> quoted text with **strong** content and a [link](/quote).\n\n" +
      "- unordered item with `code`\n" +
      "- unordered item with *emphasis*\n\n" +
      "1. ordered item\n" +
      "2. ordered item with <span>raw html</span>\n\n" +
      "```moonbit\n" +
      "fn main { println(\"hello\") }\n" +
      "```\n\n"
  }
  out
}

///|
fn no_op_inline_rule(
  _ctx : @markdown.InlineContext,
  _sink : @markdown.EventSink,
) -> Int {
  0
}

///|
fn many_extension_rules_plugin(count : Int) -> @markdown.Plugin {
  let plugin = @markdown.Plugin::new("many-extension-rules")
  for i in 0..<count {
    ignore(
      plugin.add(
        @markdown.Rule::inline(
          @markdown.RuleName::raw("x:inline:no_op:" + i.to_string()),
          priority=-i,
          no_op_inline_rule,
        ),
      ),
    )
  }
  plugin
}

///|
fn parse_event_count(input : String) -> Int {
  @markdown.Processor::commonmark().parse(input).collect().length()
}

///|
fn parse_event_count_with(
  processor : @markdown.Processor,
  input : String,
) -> Int {
  processor.parse(input).collect().length()
}

///|
fn parse_with_extension_event_count(input : String) -> Int {
  @markdown.Processor::commonmark()
  .with_plugin(many_extension_rules_plugin(50))
  .parse(input)
  .collect()
  .length()
}

///|
fn parse_render_length(input : String) -> Int {
  input |> @markdown.parse |> @markdown.to_html |> String::length
}

///|
fn parse_render_length_with(
  processor : @markdown.Processor,
  input : String,
) -> Int {
  processor.parse(input).collect() |> @markdown.to_html |> String::length
}

///|
fn render_length(events : Array[@markdown.Event]) -> Int {
  events |> @markdown.to_html |> String::length
}

///|
fn transform_event_count(events : Array[@markdown.Event]) -> Int {
  @markdown.Transform::new(events)
  .text_merge()
  .softbreak_to_hardbreak()
  .collect()
  .length()
}

///|
fn ast_child_count(events : Array[@markdown.Event]) -> Int {
  match @markdown.to_ast(events) {
    Ok(root) => root.children().length()
    Err(_) => 0
  }
}

///|
test "benchmark fixtures produce work" {
  assert_true(parse_event_count(paragraph_document()) > 0)
  assert_true(parse_event_count(plain_throughput_document()) > 0)
  assert_true(parse_event_count(single_paragraph_throughput_document()) > 0)
  assert_eq(one_mb_single_paragraph_document().length(), 1_000_000)
  assert_eq(ten_mb_single_paragraph_document().length(), 10_000_000)
  assert_true(parse_event_count(list_document()) > 0)
  assert_true(parse_event_count(delimiter_document()) > 0)
  assert_true(parse_event_count(reference_document()) > 0)
  assert_true(parse_event_count(mixed_document()) > 0)
  assert_true(parse_event_count(large_mixed_document()) > 0)
  assert_true(parse_event_count(huge_mixed_document()) > 0)
  assert_true(parse_event_count(readme_like_document()) > 0)
  assert_true(parse_event_count(readme_like_large_document()) > 0)
  assert_true(parse_event_count(readme_like_huge_document()) > 0)
  assert_true(parse_event_count(changelog_like_document()) > 0)
  assert_true(parse_event_count(changelog_like_large_document()) > 0)
  assert_true(parse_event_count(changelog_like_huge_document()) > 0)
  assert_true(parse_event_count(issue_thread_document()) > 0)
  assert_true(parse_event_count(issue_thread_large_document()) > 0)
  assert_true(parse_event_count(issue_thread_huge_document()) > 0)
  assert_eq(readme_like_document().length(), 15_747)
  assert_eq(readme_like_large_document().length(), 199_211)
  assert_eq(readme_like_huge_document().length(), 1_007_231)
  assert_eq(changelog_like_document().length(), 16_309)
  assert_eq(changelog_like_large_document().length(), 205_679)
  assert_eq(changelog_like_huge_document().length(), 1_011_256)
  assert_eq(issue_thread_document().length(), 25_153)
  assert_eq(issue_thread_large_document().length(), 200_411)
  assert_eq(issue_thread_huge_document().length(), 1_005_685)
  assert_true(parse_with_extension_event_count(paragraph_document()) > 0)
  assert_true(parse_render_length(readme_like_document()) > 0)
  let events = @markdown.parse(mixed_document())
  assert_true(render_length(events) > 0)
  assert_true(transform_event_count(events) > 0)
  assert_true(ast_child_count(events) > 0)
}

///|
test "markdown processing speed" (b : @bench.T) {
  let paragraph = paragraph_document()
  let plain_throughput = plain_throughput_document()
  let single_paragraph_throughput = single_paragraph_throughput_document()
  let one_mb_single_paragraph = one_mb_single_paragraph_document()
  let ten_mb_single_paragraph = ten_mb_single_paragraph_document()
  let list = list_document()
  let delimiter = delimiter_document()
  let references = reference_document()
  let mixed = mixed_document()
  let large_mixed = large_mixed_document()
  let huge_mixed = huge_mixed_document()
  let readme = readme_like_document()
  let large_readme = readme_like_large_document()
  let huge_readme = readme_like_huge_document()
  let changelog = changelog_like_document()
  let large_changelog = changelog_like_large_document()
  let huge_changelog = changelog_like_huge_document()
  let issue_thread = issue_thread_document()
  let large_issue_thread = issue_thread_large_document()
  let huge_issue_thread = issue_thread_huge_document()
  let commonmark = @markdown.Processor::commonmark()
  let commonmark_with_extensions = @markdown.Processor::commonmark().with_plugin(
    many_extension_rules_plugin(50),
  )
  let mixed_events = @markdown.parse(mixed)
  b.bench(
    name="parse/syntax/paragraphs_inline_markup",
    fn() { b.keep(parse_event_count_with(commonmark, paragraph)) },
    count=5,
  )
  b.bench(
    name="parse/micro/plain_lines/202kb",
    fn() { b.keep(parse_event_count_with(commonmark, plain_throughput)) },
    count=3,
  )
  b.bench(
    name="parse/micro/plain_single/62kb",
    fn() {
      b.keep(parse_event_count_with(commonmark, single_paragraph_throughput))
    },
    count=3,
  )
  b.bench(
    name="parse/micro/plain_single/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, one_mb_single_paragraph)) },
    count=3,
  )
  b.bench(
    name="parse/micro/plain_single/10mb",
    fn() { b.keep(parse_event_count_with(commonmark, ten_mb_single_paragraph)) },
    count=3,
  )
  b.bench(
    name="parse/syntax/lists_links_code_spans",
    fn() { b.keep(parse_event_count_with(commonmark, list)) },
    count=5,
  )
  b.bench(
    name="parse/syntax/long_delimiter_runs",
    fn() { b.keep(parse_event_count_with(commonmark, delimiter)) },
    count=5,
  )
  b.bench(
    name="parse/syntax/reference_definitions",
    fn() { b.keep(parse_event_count_with(commonmark, references)) },
    count=5,
  )
  b.bench(
    name="parse/scale/mixed_commonmark/15kb",
    fn() { b.keep(parse_event_count_with(commonmark, mixed)) },
    count=5,
  )
  b.bench(
    name="parse/scale/mixed_commonmark/49kb",
    fn() { b.keep(parse_event_count_with(commonmark, large_mixed)) },
    count=3,
  )
  b.bench(
    name="parse/scale/mixed_commonmark/98kb",
    fn() { b.keep(parse_event_count_with(commonmark, huge_mixed)) },
    count=3,
  )
  b.bench(
    name="parse/scale/readme_like/16kb",
    fn() { b.keep(parse_event_count_with(commonmark, readme)) },
    count=3,
  )
  b.bench(
    name="parse/scale/readme_like/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, large_readme)) },
    count=3,
  )
  b.bench(
    name="parse/scale/readme_like/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, huge_readme)) },
    count=3,
  )
  b.bench(
    name="parse/scale/changelog_like/16kb",
    fn() { b.keep(parse_event_count_with(commonmark, changelog)) },
    count=3,
  )
  b.bench(
    name="parse/scale/changelog_like/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, large_changelog)) },
    count=3,
  )
  b.bench(
    name="parse/scale/changelog_like/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, huge_changelog)) },
    count=3,
  )
  b.bench(
    name="parse/scale/issue_thread/25kb",
    fn() { b.keep(parse_event_count_with(commonmark, issue_thread)) },
    count=3,
  )
  b.bench(
    name="parse/scale/issue_thread/200kb",
    fn() { b.keep(parse_event_count_with(commonmark, large_issue_thread)) },
    count=3,
  )
  b.bench(
    name="parse/scale/issue_thread/1mb",
    fn() { b.keep(parse_event_count_with(commonmark, huge_issue_thread)) },
    count=3,
  )
  b.bench(
    name="parse/extensions/many_inline_rules",
    fn() {
      b.keep(parse_event_count_with(commonmark_with_extensions, paragraph))
    },
    count=5,
  )
  b.bench(
    name="pipeline/scale/mixed_commonmark/15kb",
    fn() { b.keep(parse_render_length_with(commonmark, mixed)) },
    count=5,
  )
  b.bench(
    name="pipeline/scale/mixed_commonmark/49kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_mixed)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/mixed_commonmark/98kb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_mixed)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/readme_like/16kb",
    fn() { b.keep(parse_render_length_with(commonmark, readme)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/readme_like/200kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_readme)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/readme_like/1mb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_readme)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/changelog_like/16kb",
    fn() { b.keep(parse_render_length_with(commonmark, changelog)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/changelog_like/200kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_changelog)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/changelog_like/1mb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_changelog)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/issue_thread/25kb",
    fn() { b.keep(parse_render_length_with(commonmark, issue_thread)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/issue_thread/200kb",
    fn() { b.keep(parse_render_length_with(commonmark, large_issue_thread)) },
    count=3,
  )
  b.bench(
    name="pipeline/scale/issue_thread/1mb",
    fn() { b.keep(parse_render_length_with(commonmark, huge_issue_thread)) },
    count=3,
  )
  b.bench(
    name="render/html_from_events",
    fn() { b.keep(render_length(mixed_events)) },
    count=5,
  )
  b.bench(
    name="transform/text_merge_softbreak",
    fn() { b.keep(transform_event_count(mixed_events)) },
    count=5,
  )
  b.bench(
    name="ast/build_from_events",
    fn() { b.keep(ast_child_count(mixed_events)) },
    count=5,
  )
}
