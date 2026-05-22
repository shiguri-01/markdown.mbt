///|
fn main {
  let args = @env.args()
  if args.length() != 5 {
    print_help()
    return
  }
  run_profile(
    args[1],
    args[2],
    parse_positive_int(args[3]),
    parse_non_negative_int(args[4]),
  )
}

///|
fn print_help() -> Unit {
  println("usage: markdown-profile MODE FIXTURE REPEATS WARMUPS")
  println("")
  println("modes:")
  println("  parse")
  println("  html")
  println("")
  println("fixtures:")
  println("  plain_single_1mb")
  println("  long_delimiter_runs")
  println("  reference_definitions")
  println("  readme_like_16kb")
  println("  readme_like_200kb")
  println("  readme_like_1mb")
  println("  issue_thread_25kb")
  println("  issue_thread_200kb")
  println("  issue_thread_1mb")
}

///|
fn run_profile(
  mode : String,
  fixture_name : String,
  repeats : Int,
  warmups : Int,
) -> Unit {
  let input = fixture(fixture_name)
  let processor = @markdown.Processor()
  let mut checksum = 0
  for _ in 0..<warmups {
    checksum += run_once(mode, processor, input)
  }
  let times : Array[Double] = []
  for _ in 0..<repeats {
    let start = @bench.monotonic_clock_start()
    checksum += run_once(mode, processor, input)
    times.push(@bench.monotonic_clock_end(start) / 1000.0)
  }
  if checksum == 0 {
    abort("profile run produced empty work")
  }
  println(times.to_json().stringify())
}

///|
fn run_once(
  mode : String,
  processor : @markdown.Processor,
  input : String,
) -> Int {
  match mode {
    "parse" => parse_event_count_with(processor, input)
    "html" => parse_render_length_with(processor, input)
    _ => abort("unknown profile mode: " + mode)
  }
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
fn parse_render_length_with(
  processor : @markdown.Processor,
  input : String,
) -> Int {
  let html = @markdown.Html(size_hint=input.length())
  processor.parse(input, html.sink())
  html.to_string().length()
}

///|
fn parse_positive_int(value : String) -> Int {
  let parsed = parse_non_negative_int(value)
  if parsed < 1 {
    abort("expected positive integer: " + value)
  }
  parsed
}

///|
fn parse_non_negative_int(value : String) -> Int {
  if value == "" {
    abort("expected integer")
  }
  let mut parsed = 0
  for i in 0..<value.length() {
    let digit = value[i].to_int() - 48
    if digit < 0 || digit > 9 {
      abort("expected integer: " + value)
    }
    parsed = parsed * 10 + digit
  }
  parsed
}

///|
fn fixture(name : String) -> String {
  match name {
    "plain_single_1mb" => one_mb_single_paragraph_document()
    "long_delimiter_runs" => delimiter_document()
    "reference_definitions" => reference_document()
    "readme_like_16kb" => readme_like_document_sections(36)
    "readme_like_200kb" => readme_like_document_sections(460)
    "readme_like_1mb" => readme_like_document_sections(2320)
    "issue_thread_25kb" => issue_thread_document_comments(64)
    "issue_thread_200kb" => issue_thread_document_comments(509)
    "issue_thread_1mb" => issue_thread_document_comments(2545)
    _ => abort("unknown fixture: " + name)
  }
}

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
fn readme_like_document_sections(count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("# markdown.mbt\n\n")
  out.write_string(
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling, rule hooks, and HTML rendering.\n\n",
  )
  out.write_string("## Installation\n\n")
  out.write_string("```moonbit\n")
  out.write_string("let html = @markdown.Html()\n")
  out.write_string("@markdown.Processor().parse(source, html.sink())\n")
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
