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
  let html = @markdown.Html(@markdown.HtmlRenderers())
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

///|
test "html renderers map extension tags" {
  let tag = @markdown.Tag::raw("x:note")
  let renderers = @markdown.HtmlRenderers().register(tag, fn(writer, el) {
    writer.write_string("<aside")
    writer.write_attrs(el.attrs())
    writer.write_string(">")
    "</aside>"
  })
  let html = @markdown.Html(renderers)
  let sink = html.sink()
  sink.emit(
    Enter(
      @markdown.Element::with_attrs(tag, [
        @markdown.Attr(@markdown.AttrName::raw("data-name"), "a&b"),
      ]),
    ),
  )
  sink.emit(Text("<body>"))
  sink.emit(Exit(tag))
  sink.finish()
  assert_eq(
    html.to_string(),
    "<aside data-name=\"a&amp;b\">&lt;body&gt;</aside>",
  )
}

///|
test "html renderer controls apply across later extensions" {
  let paragraph = @markdown.Tag::raw("cm:paragraph")
  assert_eq(
    render_html_with(
      @commonmark.rule(),
      @markdown.HtmlRenderers()
      .disable(paragraph)
      .extend(@commonmark.html_renderers()),
      "hello",
    ),
    "<cm:paragraph>hello</cm:paragraph>",
  )
  assert_eq(
    render_html_with(
      @commonmark.rule(),
      @markdown.HtmlRenderers()
      .disable(paragraph)
      .extend(@commonmark.html_renderers())
      .enable(paragraph),
      "hello",
    ),
    "<p>hello</p>\n",
  )
  assert_eq(
    render_html_with(
      @commonmark.rule(),
      @markdown.HtmlRenderers()
      .replace(paragraph, fn(writer, _el) {
        writer.write_string("<aside>")
        "</aside>"
      })
      .extend(@commonmark.html_renderers()),
      "hello",
    ),
    "<aside>hello</aside>",
  )
}

///|
test "html list item rendering is controlled by renderers" {
  let item = @markdown.Tag::raw("cm:item")
  assert_eq(
    render_html_with(
      @commonmark.rule(),
      @commonmark.html_renderers().disable(item),
      "- one\n",
    ),
    "<ul>\n<cm:item>one</cm:item></ul>\n",
  )
}
