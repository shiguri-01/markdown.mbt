///|
fn main {
  let args = @env.args()
  if args.length() != 2 {
    print_help()
    return
  }
  let input = fixture(args[1])
  let html = @markdown.Html::new()
  @markdown.Processor::new().parse(input, html.sink())
  println(html.to_string())
}

///|
fn print_help() -> Unit {
  println("usage: markdown-html FIXTURE")
  println("")
  println("fixtures:")
  println("  readme_like_16kb")
  println("  readme_like_200kb")
  println("  issue_thread_25kb")
  println("  issue_thread_200kb")
}

///|
fn fixture(name : String) -> String {
  match name {
    "readme_like_16kb" => readme_like_document_sections(36)
    "readme_like_200kb" => readme_like_document_sections(460)
    "issue_thread_25kb" => issue_thread_document_comments(64)
    "issue_thread_200kb" => issue_thread_document_comments(509)
    _ => abort("unknown fixture: " + name)
  }
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
