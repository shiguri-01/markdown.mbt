///|
test "commonmark block and inline html rendering" {
  let html = render_html(
    @commonmark.rule(),
    "## Hello *MoonBit*\n\n- one\n- two",
  )
  assert_eq(
    html, "<h2>Hello <em>MoonBit</em></h2>\n<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n",
  )
}

///|
test "html sink escapes extension events and preserves raw html" {
  let html = @markdown.Html()
  let sink = html.sink()
  let tag = @markdown.Tag::raw("x:note")
  sink.emit(
    Enter(
      @markdown.Element::with_attrs(tag, [
        @markdown.Attr(@markdown.AttrName::raw("data\"name"), "<value&\""),
      ]),
    ),
  )
  sink.emit(Text("<body&\""))
  sink.emit(RawHtml("<raw>"))
  sink.emit(Exit(tag))
  sink.finish()
  assert_eq(
    html.to_string(),
    "<x:note data&quot;name=\"&lt;value&amp;&quot;\">&lt;body&amp;&quot;<raw></x:note>",
  )
}
