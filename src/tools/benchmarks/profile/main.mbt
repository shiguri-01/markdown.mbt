///|
fn main {
  let input = fixture()
  let processor = @markdown.Processor(@commonmark.rule())
  let mut checksum = 0
  for _ in 0..<20 {
    checksum += render_length(processor, input)
  }
  if checksum == 0 {
    abort("prof run produced empty work")
  }
  println(checksum)
}

///|
fn render_length(processor : @markdown.Processor, input : String) -> Int {
  let html = @markdown.Html(
    @commonmark.html_renderers(),
    size_hint=input.length(),
  )
  processor.parse(input, html.sink())
  html.to_string().length()
}

///|
fn fixture() -> String {
  let out = StringBuilder::new()
  out <+ "# markdown.mbt\n\n"
  out <+
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling.\n\n"
  for i in 0..<460 {
    out <+ "## Section "
    out <+ "\{i}"
    out <+ "\n\n"
    out <+
      "This paragraph includes `inline code`, *emphasis*, **strong text**, and [cross references](#section-"
    out <+ "\{i}"
    out <+ ").\n\n"
    out <+ "- Parse source into a stable event stream.\n"
    out <+ "- Render known CommonMark nodes to HTML.\n"
    out <+ "- Preserve extension elements for downstream tools.\n\n"
    out <+ "> Profiling should keep enough parser work visible.\n\n"
  }
  out.to_string()
}
