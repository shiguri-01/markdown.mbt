///|
fn repeat_text(text : String, count : Int) -> String {
  let mut out = ""
  for _ in 0..<count {
    out = out + text
  }
  out
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
    "MoonBit markdown parser benchmark text without inline markup. ",
    2000,
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
fn parse_event_count_with(processor : @markdown.Processor, input : String) -> Int {
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
  assert_true(parse_event_count(list_document()) > 0)
  assert_true(parse_event_count(delimiter_document()) > 0)
  assert_true(parse_event_count(reference_document()) > 0)
  assert_true(parse_event_count(mixed_document()) > 0)
  assert_true(parse_event_count(large_mixed_document()) > 0)
  assert_true(parse_event_count(huge_mixed_document()) > 0)
  assert_true(parse_with_extension_event_count(paragraph_document()) > 0)
  assert_true(parse_render_length(mixed_document()) > 0)
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
  let list = list_document()
  let delimiter = delimiter_document()
  let references = reference_document()
  let mixed = mixed_document()
  let large_mixed = large_mixed_document()
  let huge_mixed = huge_mixed_document()
  let commonmark = @markdown.Processor::commonmark()
  let commonmark_with_extensions = @markdown.Processor::commonmark()
    .with_plugin(many_extension_rules_plugin(50))
  let mixed_events = @markdown.parse(mixed)
  b.bench(
    name="parse/paragraphs_inline_markup",
    fn() { b.keep(parse_event_count_with(commonmark, paragraph)) },
    count=5,
  )
  b.bench(
    name="parse/plain_paragraphs_throughput",
    fn() { b.keep(parse_event_count_with(commonmark, plain_throughput)) },
    count=3,
  )
  b.bench(
    name="parse/single_paragraph_throughput",
    fn() {
      b.keep(parse_event_count_with(commonmark, single_paragraph_throughput))
    },
    count=3,
  )
  b.bench(
    name="parse/lists_links_code_spans",
    fn() { b.keep(parse_event_count_with(commonmark, list)) },
    count=5,
  )
  b.bench(
    name="parse/long_delimiter_runs",
    fn() { b.keep(parse_event_count_with(commonmark, delimiter)) },
    count=5,
  )
  b.bench(
    name="parse/reference_definitions",
    fn() { b.keep(parse_event_count_with(commonmark, references)) },
    count=5,
  )
  b.bench(
    name="parse/mixed_commonmark_document",
    fn() { b.keep(parse_event_count_with(commonmark, mixed)) },
    count=5,
  )
  b.bench(
    name="parse/large_mixed_commonmark_document",
    fn() { b.keep(parse_event_count_with(commonmark, large_mixed)) },
    count=3,
  )
  b.bench(
    name="parse/huge_mixed_commonmark_document",
    fn() { b.keep(parse_event_count_with(commonmark, huge_mixed)) },
    count=3,
  )
  b.bench(
    name="parse/many_extension_rules",
    fn() {
      b.keep(parse_event_count_with(commonmark_with_extensions, paragraph))
    },
    count=5,
  )
  b.bench(
    name="pipeline/parse_to_html",
    fn() { b.keep(parse_render_length_with(commonmark, mixed)) },
    count=5,
  )
  b.bench(
    name="pipeline/large_parse_to_html",
    fn() { b.keep(parse_render_length_with(commonmark, large_mixed)) },
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
