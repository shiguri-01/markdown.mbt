///|
fn main {
  let input = fixture()
  let processor = @markdown.Processor()
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
  let html = @markdown.Html(size_hint=input.length())
  processor.parse(input, html.sink())
  html.to_string().length()
}

///|
fn fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("# markdown.mbt\n\n")
  out.write_string(
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling.\n\n",
  )
  for i in 0..<460 {
    out.write_string("## Section ")
    out.write_string(i.to_string())
    out.write_string("\n\n")
    out.write_string(
      "This paragraph includes `inline code`, *emphasis*, **strong text**, and [cross references](#section-",
    )
    out.write_string(i.to_string())
    out.write_string(").\n\n")
    out.write_string("- Parse source into a stable event stream.\n")
    out.write_string("- Render known CommonMark nodes to HTML.\n")
    out.write_string("- Preserve extension elements for downstream tools.\n\n")
    out.write_string("> Profiling should keep enough parser work visible.\n\n")
  }
  out.to_string()
}
