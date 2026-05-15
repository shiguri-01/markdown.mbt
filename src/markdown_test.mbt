///|
test "commonmark block and inline html rendering" {
  let html = @markdown.ParserBuilder::commonmark()
    .parse("## Hello *MoonBit*\n\n- one\n- two")
    .to_html()
  assert_eq(
    html, "<h2>Hello <em>MoonBit</em></h2>\n<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n",
  )
}

///|
test "top-level parser builders are available" {
  assert_eq(@markdown.commonmark().parse("# hi").to_html(), "<h1>hi</h1>\n")
  assert_eq(@markdown.new().parse("# hi").to_html(), "<p># hi</p>\n")
}

///|
test "commonmark plugin can be installed explicitly" {
  let html = @markdown.ParserBuilder::new()
    .use(@markdown.commonmark_plugin())
    .parse("# hi\n\n*em*")
    .to_html()
  assert_eq(html, "<h1>hi</h1>\n<p><em>em</em></p>\n")
}

///|
test "empty builder parses paragraph text without registered rules" {
  let parser = @markdown.ParserBuilder::new().parse("plain")
  match parser.next() {
    Some(@markdown.Enter(el)) => assert_eq(el.tag, "cm:paragraph")
    _ => abort("expected fallback paragraph")
  }
  match parser.next() {
    Some(@markdown.Text(text)) => assert_eq(text, "plain")
    _ => abort("expected fallback text")
  }
  match parser.next() {
    Some(@markdown.Exit(tag)) => assert_eq(tag, "cm:paragraph")
    _ => abort("expected fallback paragraph exit")
  }
  match parser.next() {
    None => ()
    Some(_) => abort("expected end")
  }
}

///|
test "ordered list and code block render with balanced tags" {
  let html = @markdown.ParserBuilder::commonmark()
    .parse("1. one\n2. two\n\n```\n<a>\n```")
    .to_html()
  assert_eq(
    html, "<ol>\n<li>one</li>\n<li>two</li>\n</ol>\n<pre><code>&lt;a&gt;\n</code></pre>\n",
  )
}

///|
test "standard rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:block:atx_heading")
    .parse("# not a heading")
    .to_html()
  assert_eq(html, "<p># not a heading</p>\n")
}

///|
test "disabled standard rule can be re-enabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:block:atx_heading")
    .enable("cm:block:atx_heading")
    .parse("# heading")
    .to_html()
  assert_eq(html, "<h1>heading</h1>\n")
}

///|
test "setext heading rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:block:setext_heading")
    .parse("heading\n---")
    .to_html()
  assert_eq(html, "<p>heading</p>\n<hr />\n")
}

///|
test "list rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:block:list")
    .parse("1) one")
    .to_html()
  assert_eq(html, "<p>1) one</p>\n")
}

///|
test "paragraph rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:block:paragraph")
    .parse("plain")
    .to_html()
  assert_eq(html, "plain")
}

///|
test "paragraph rule can be replaced" {
  let replacement = @markdown.Rule::block("cm:block:paragraph", priority=0, fn(
    ctx,
    sink,
  ) {
    sink.emit(@markdown.Enter(@markdown.element("x:paragraph")))
    sink.emit(@markdown.Text(ctx.current_line()))
    sink.emit(@markdown.Exit("x:paragraph"))
    1
  })
  let html = @markdown.ParserBuilder::commonmark()
    .replace(replacement)
    .parse("plain")
    .to_html()
  assert_eq(html, "<x:paragraph>plain</x:paragraph>")
}

///|
test "reference definition core rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:core:reference_definitions")
    .parse("[foo]: /url\n\n[foo]")
    .to_html()
  assert_eq(html, "<p>[foo]: /url</p>\n<p>[foo]</p>\n")
}

///|
test "reference definition continuation core rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:core:reference_definitions")
    .parse("[foo]: /url\n  'title'\n\n[foo]")
    .to_html()
  assert_eq(html, "<p>[foo]: /url\n'title'</p>\n<p>[foo]</p>\n")
}

///|
test "reference definition core rule can be disabled for images" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:core:reference_definitions")
    .parse("[alt]: /img.png\n\n![alt]")
    .to_html()
  assert_eq(html, "<p>[alt]: /img.png</p>\n<p>![alt]</p>\n")
}

///|
test "reference definition core rule can be replaced" {
  let replacement = @markdown.Rule::core(
    "cm:core:reference_definitions",
    priority=100,
    fn(events) { events },
  )
  let html = @markdown.ParserBuilder::commonmark()
    .replace(replacement)
    .parse("[foo]: /url\n\n[foo]")
    .to_html()
  assert_eq(html, "<p>[foo]: /url</p>\n<p>[foo]</p>\n")
}

///|
test "hard break rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:inline:hard_break")
    .parse("a\\\nb")
    .to_html()
  assert_eq(html, "<p>a\\\nb</p>\n")
}

///|
test "hard break rule emits event for backslash and spaces" {
  let backslash = @markdown.ParserBuilder::commonmark()
    .parse("a\\\nb")
    .collect()
  match backslash[2] {
    @markdown.HardBreak => ()
    _ => abort("expected backslash hard break")
  }
  let spaces = @markdown.ParserBuilder::commonmark().parse("a  \nb").collect()
  match spaces[2] {
    @markdown.HardBreak => ()
    _ => abort("expected spaces hard break")
  }
}

///|
test "soft break rule emits event and can be disabled" {
  let enabled = @markdown.ParserBuilder::commonmark().parse("a\nb").collect()
  match enabled[2] {
    @markdown.SoftBreak => ()
    _ => abort("expected soft break")
  }
  let disabled = @markdown.ParserBuilder::commonmark()
    .disable("cm:inline:soft_break")
    .parse("a\nb")
    .collect()
  match disabled[2] {
    @markdown.Text(text) => assert_eq(text, "\n")
    _ => abort("expected text newline")
  }
}

///|
test "entity rule can be disabled" {
  let html = @markdown.ParserBuilder::commonmark()
    .disable("cm:inline:entity")
    .parse("&amp;")
    .to_html()
  assert_eq(html, "<p>&amp;amp;</p>\n")
}

///|
test "entity rule emits text event and can be disabled" {
  let enabled = @markdown.ParserBuilder::commonmark().parse("&amp;").collect()
  match enabled[1] {
    @markdown.Text(text) => assert_eq(text, "&")
    _ => abort("expected decoded entity text")
  }
  let disabled = @markdown.ParserBuilder::commonmark()
    .disable("cm:inline:entity")
    .parse("&amp;")
    .collect()
  match disabled[1] {
    @markdown.Text(text) => assert_eq(text, "&")
    _ => abort("expected raw ampersand text")
  }
  match disabled[2] {
    @markdown.Text(text) => assert_eq(text, "amp;")
    _ => abort("expected raw entity suffix text")
  }
}

///|
test "standard rule can be replaced" {
  let replacement = @markdown.Rule::block(
    "cm:block:atx_heading",
    priority=100,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("# ") {
        sink.emit(@markdown.Enter(@markdown.element("x:heading")))
        sink.emit(@markdown.Text("replaced"))
        sink.emit(@markdown.Exit("x:heading"))
        1
      } else {
        0
      }
    },
  )
  let html = @markdown.ParserBuilder::commonmark()
    .replace(replacement)
    .parse("# hello")
    .to_html()
  assert_eq(html, "<x:heading>replaced</x:heading>")
}

///|
test "replaced disabled rule stays disabled until enabled" {
  let replacement = @markdown.Rule::block(
    "cm:block:atx_heading",
    priority=100,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("# ") {
        sink.emit(@markdown.Enter(@markdown.element("x:heading")))
        sink.emit(@markdown.Text("replaced"))
        sink.emit(@markdown.Exit("x:heading"))
        1
      } else {
        0
      }
    },
  )
  let disabled_html = @markdown.ParserBuilder::commonmark()
    .disable("cm:block:atx_heading")
    .replace(replacement)
    .parse("# hello")
    .to_html()
  assert_eq(disabled_html, "<p># hello</p>\n")
  let enabled_html = @markdown.ParserBuilder::commonmark()
    .disable("cm:block:atx_heading")
    .replace(replacement)
    .enable("cm:block:atx_heading")
    .parse("# hello")
    .to_html()
  assert_eq(enabled_html, "<x:heading>replaced</x:heading>")
}

///|
test "standard delimiter rule can be replaced" {
  let replacement = @markdown.Rule::delimiter(
    "cm:delimiter:emphasis",
    priority=100,
    fn(ctx, sink) {
      let scanner = ctx.scanner()
      if !scanner.has_prefix("*") {
        return 0
      }
      let source = ctx.source()
      let base = ctx.offset()
      let mut close = 1
      while base + close < source.length() &&
            source[base + close].to_int() != 42 {
        close = close + 1
      }
      if base + close >= source.length() {
        return 0
      }
      sink.emit(@markdown.Enter(@markdown.element("x:emphasis")))
      sink.emit(@markdown.Text(scanner.slice(1, close)))
      sink.emit(@markdown.Exit("x:emphasis"))
      close + 1
    },
  )
  let html = @markdown.ParserBuilder::commonmark()
    .replace(replacement)
    .parse("*hello*")
    .to_html()
  assert_eq(html, "<p><x:emphasis>hello</x:emphasis></p>\n")
}

///|
test "standard inline rule can be replaced" {
  let replacement = @markdown.Rule::inline(
    "cm:inline:code_span",
    priority=100,
    fn(ctx, sink) {
      let scanner = ctx.scanner()
      if !scanner.has_prefix("`") {
        return 0
      }
      let source = ctx.source()
      let base = ctx.offset()
      let mut close = 1
      while base + close < source.length() &&
            source[base + close].to_int() != 96 {
        close = close + 1
      }
      if base + close >= source.length() {
        return 0
      }
      sink.emit(@markdown.Enter(@markdown.element("x:code")))
      sink.emit(@markdown.Text(scanner.slice(1, close)))
      sink.emit(@markdown.Exit("x:code"))
      close + 1
    },
  )
  let html = @markdown.ParserBuilder::commonmark()
    .replace(replacement)
    .parse("`hello`")
    .to_html()
  assert_eq(html, "<p><x:code>hello</x:code></p>\n")
}

///|
test "standard text inline rule can be replaced" {
  let replacement = @markdown.Rule::inline("cm:inline:text", priority=-1000, fn(
    ctx,
    sink,
  ) {
    if ctx.scanner().has_prefix("abc") {
      sink.emit(@markdown.Text("XYZ"))
      3
    } else {
      0
    }
  })
  let html = @markdown.ParserBuilder::commonmark()
    .replace(replacement)
    .parse("abc")
    .to_html()
  assert_eq(html, "<p>XYZ</p>\n")
}

///|
test "standard text inline rule can be disabled" {
  let enabled = @markdown.ParserBuilder::commonmark().parse("abc").collect()
  match enabled[1] {
    @markdown.Text(text) => assert_eq(text, "abc")
    _ => abort("expected text")
  }
  let disabled = @markdown.ParserBuilder::commonmark()
    .disable("cm:inline:text")
    .parse("abc")
    .collect()
  match disabled[1] {
    @markdown.Text(text) => assert_eq(text, "a")
    _ => abort("expected fallback text")
  }
  match disabled[2] {
    @markdown.Text(text) => assert_eq(text, "b")
    _ => abort("expected fallback text")
  }
  match disabled[3] {
    @markdown.Text(text) => assert_eq(text, "c")
    _ => abort("expected fallback text")
  }
}

///|
test "external plugin rule participates in block chain" {
  let admonition = @markdown.Rule::block("x:block:admonition", priority=100, fn(
    ctx,
    sink,
  ) {
    let line = ctx.current_line()
    if line.has_prefix("!!! ") {
      sink.emit(
        @markdown.Enter(
          @markdown.element_with_attrs("x:admonition", [
            { name: "kind", value: line[4:].to_owned() },
          ]),
        ),
      )
      sink.emit(@markdown.Exit("x:admonition"))
      1
    } else {
      0
    }
  })
  let plugin = @markdown.Plugin::new("admonition").add(admonition)
  let html = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .parse("!!! note")
    .to_html()
  assert_eq(html, "<x:admonition kind=\"note\"></x:admonition>")
}

///|
test "external block plugin rule can be disabled and re-enabled" {
  let admonition = @markdown.Rule::block("x:block:admonition", priority=100, fn(
    ctx,
    sink,
  ) {
    let line = ctx.current_line()
    if line.has_prefix("!!! ") {
      sink.emit(
        @markdown.Enter(
          @markdown.element_with_attrs("x:admonition", [
            { name: "kind", value: line[4:].to_owned() },
          ]),
        ),
      )
      sink.emit(@markdown.Exit("x:admonition"))
      1
    } else {
      0
    }
  })
  let plugin = @markdown.Plugin::new("admonition").add(admonition)
  let disabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:block:admonition")
    .parse("!!! note")
    .to_html()
  assert_eq(disabled, "<p>!!! note</p>\n")
  let enabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:block:admonition")
    .enable("x:block:admonition")
    .parse("!!! note")
    .to_html()
  assert_eq(enabled, "<x:admonition kind=\"note\"></x:admonition>")
}

///|
test "external plugin rule can be disabled and re-enabled" {
  let marker = @markdown.Rule::inline("x:inline:marker", priority=100, fn(
    ctx,
    sink,
  ) {
    if ctx.scanner().has_prefix("@@") {
      sink.emit(@markdown.Enter(@markdown.element("x:marker")))
      sink.emit(@markdown.Text("marked"))
      sink.emit(@markdown.Exit("x:marker"))
      2
    } else {
      0
    }
  })
  let plugin = @markdown.Plugin::new("marker").add(marker)
  let disabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:inline:marker")
    .parse("@@")
    .to_html()
  assert_eq(disabled, "<p>@@</p>\n")
  let enabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:inline:marker")
    .enable("x:inline:marker")
    .parse("@@")
    .to_html()
  assert_eq(enabled, "<p><x:marker>marked</x:marker></p>\n")
}

///|
test "external block plugin can consume multiline admonition" {
  let admonition = @markdown.Rule::block("x:block:admonition", priority=100, fn(
    ctx,
    sink,
  ) {
    let line = ctx.current_line()
    if !line.has_prefix("!!! ") {
      return 0
    }
    let mut consumed = 1
    let mut body = ""
    let mut scanning = true
    while scanning {
      match ctx.line_at(ctx.line_index() + consumed) {
        Some(next) =>
          if next.has_prefix("    ") {
            if body.length() > 0 {
              body = body + "\n"
            }
            body = body + next[4:].to_owned()
            consumed = consumed + 1
          } else {
            scanning = false
          }
        None => scanning = false
      }
    }
    let start = ctx.current_line_start()
    sink.emit(
      @markdown.Enter(
        @markdown.element_with_attrs(
          "x:admonition",
          [{ name: "kind", value: line[4:].to_owned() }],
          range=Some({ start, end: start + line.length() }),
        ),
      ),
    )
    sink.emit(@markdown.Text(body))
    sink.emit(@markdown.Exit("x:admonition"))
    consumed
  })
  let events = @markdown.ParserBuilder::commonmark()
    .use(@markdown.Plugin::new("admonition").add(admonition))
    .parse("!!! note\n    first\n    second\n\nnext")
    .collect()
  match events[0] {
    @markdown.Enter(el) => {
      assert_eq(el.tag, "x:admonition")
      assert_eq(el.attrs[0].value, "note")
      match el.range {
        Some(range) => {
          assert_eq(range.start, 0)
          assert_eq(range.end, 8)
        }
        None => abort("expected admonition range")
      }
    }
    _ => abort("expected admonition")
  }
  match events[1] {
    @markdown.Text(text) => assert_eq(text, "first\nsecond")
    _ => abort("expected admonition body")
  }
  match events[3] {
    @markdown.Enter(el) => assert_eq(el.tag, "cm:paragraph")
    _ => abort("expected following paragraph")
  }
}

///|
test "external plugin rule participates in block continue chain" {
  let continuation = @markdown.Rule::block_continue(
    "x:block_continue:marker",
    priority=-100,
    fn(ctx, sink) {
      let line = ctx.current_line()
      if line.has_prefix("% ") {
        sink.emit(@markdown.Enter(@markdown.element("x:continued")))
        sink.emit(@markdown.Text(line[2:].to_owned()))
        sink.emit(@markdown.Exit("x:continued"))
        1
      } else {
        0
      }
    },
  )
  let start = @markdown.Rule::block("x:block:start_marker", priority=100, fn(
    ctx,
    sink,
  ) {
    let line = ctx.current_line()
    if line.has_prefix("% ") {
      sink.emit(@markdown.Enter(@markdown.element("x:start")))
      sink.emit(@markdown.Text(line[2:].to_owned()))
      sink.emit(@markdown.Exit("x:start"))
      1
    } else {
      0
    }
  })
  let plugin = @markdown.Plugin::new("block-continue")
    .add(start)
    .add(continuation)
  let html = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .parse("% done")
    .to_html()
  assert_eq(html, "<x:continued>done</x:continued>")
}

///|
test "external block continue rule can be disabled and re-enabled" {
  let continuation = @markdown.Rule::block_continue(
    "x:block_continue:marker",
    priority=-100,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("% ") {
        sink.emit(@markdown.Enter(@markdown.element("x:continued")))
        sink.emit(@markdown.Text(ctx.current_line()[2:].to_owned()))
        sink.emit(@markdown.Exit("x:continued"))
        1
      } else {
        0
      }
    },
  )
  let start = @markdown.Rule::block("x:block:start_marker", priority=100, fn(
    ctx,
    sink,
  ) {
    if ctx.current_line().has_prefix("% ") {
      sink.emit(@markdown.Enter(@markdown.element("x:start")))
      sink.emit(@markdown.Text(ctx.current_line()[2:].to_owned()))
      sink.emit(@markdown.Exit("x:start"))
      1
    } else {
      0
    }
  })
  let plugin = @markdown.Plugin::new("block-continue")
    .add(start)
    .add(continuation)
  let disabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:block_continue:marker")
    .parse("% done")
    .to_html()
  assert_eq(disabled, "<x:start>done</x:start>")
  let enabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:block_continue:marker")
    .enable("x:block_continue:marker")
    .parse("% done")
    .to_html()
  assert_eq(enabled, "<x:continued>done</x:continued>")
}

///|
test "block continue rule order honors before edges" {
  let first = @markdown.Rule::block_continue(
    "x:block_continue:first",
    priority=10,
    fn(ctx, sink) {
      if ctx.current_line() == "%" {
        sink.emit(@markdown.Text("first"))
        1
      } else {
        0
      }
    },
  )
  let second = @markdown.Rule::block_continue(
    "x:block_continue:second",
    priority=0,
    before=["x:block_continue:first"],
    fn(ctx, sink) {
      if ctx.current_line() == "%" {
        sink.emit(@markdown.Text("second"))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("block-continue-order")
    .add(first)
    .add(second)
  assert_eq(
    @markdown.ParserBuilder::new().use(plugin).parse("%").to_html(),
    "second",
  )
}

///|
test "external plugin rule participates in inline chain" {
  let math = @markdown.Rule::inline("x:inline:math", priority=100, fn(
    ctx,
    sink,
  ) {
    let scanner = ctx.scanner()
    let offset_index = ctx.offset()
    let source = ctx.source()
    if !scanner.has_prefix("$") {
      return 0
    }
    let mut offset = 1
    while scanner.char_at_offset(offset) != Some(36) &&
          offset_index + offset < source.length() {
      offset = offset + 1
    }
    if offset_index + offset >= source.length() {
      return 0
    }
    sink.emit(@markdown.Enter(@markdown.element("x:math")))
    sink.emit(@markdown.Text(scanner.slice(1, offset)))
    sink.emit(@markdown.Exit("x:math"))
    offset + 1
  })
  let html = @markdown.ParserBuilder::commonmark()
    .use(@markdown.Plugin::new("math").add(math))
    .parse("a $x + y$ b")
    .to_html()
  assert_eq(html, "<p>a <x:math>x + y</x:math> b</p>\n")
}

///|
test "external plugin rule participates in delimiter chain" {
  let mark = @markdown.Rule::delimiter("x:delimiter:mark", priority=100, fn(
    ctx,
    sink,
  ) {
    let scanner = ctx.scanner()
    let offset_index = ctx.offset()
    let source = ctx.source()
    if !scanner.has_prefix("^^") {
      return 0
    }
    let mut offset = 2
    while offset_index + offset + 1 < source.length() &&
          !(source[offset_index + offset].to_int() == 94 &&
          source[offset_index + offset + 1].to_int() == 94) {
      offset = offset + 1
    }
    if offset_index + offset + 1 >= source.length() {
      return 0
    }
    sink.emit(@markdown.Enter(@markdown.element("x:mark")))
    sink.emit(@markdown.Text(scanner.slice(2, offset)))
    sink.emit(@markdown.Exit("x:mark"))
    offset + 2
  })
  let html = @markdown.ParserBuilder::commonmark()
    .use(@markdown.Plugin::new("mark").add(mark))
    .parse("a ^^marked^^ b")
    .to_html()
  assert_eq(html, "<p>a <x:mark>marked</x:mark> b</p>\n")
}

///|
test "external delimiter rule can be disabled and re-enabled" {
  let mark = @markdown.Rule::delimiter("x:delimiter:mark", priority=100, fn(
    ctx,
    sink,
  ) {
    if !ctx.scanner().has_prefix("^^") {
      return 0
    }
    let source = ctx.source()
    let base = ctx.offset()
    let mut offset = 2
    while base + offset + 1 < source.length() &&
          !(source[base + offset].to_int() == 94 &&
          source[base + offset + 1].to_int() == 94) {
      offset = offset + 1
    }
    if base + offset + 1 >= source.length() {
      return 0
    }
    sink.emit(@markdown.Enter(@markdown.element("x:mark")))
    sink.emit(@markdown.Text(ctx.scanner().slice(2, offset)))
    sink.emit(@markdown.Exit("x:mark"))
    offset + 2
  })
  let plugin = @markdown.Plugin::new("mark").add(mark)
  let disabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:delimiter:mark")
    .parse("a ^^marked^^ b")
    .to_html()
  assert_eq(disabled, "<p>a ^^marked^^ b</p>\n")
  let enabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:delimiter:mark")
    .enable("x:delimiter:mark")
    .parse("a ^^marked^^ b")
    .to_html()
  assert_eq(enabled, "<p>a <x:mark>marked</x:mark> b</p>\n")
}

///|
test "delimiter rule order honors after edges" {
  let first = @markdown.Rule::delimiter("x:delimiter:first", priority=1, fn(
    ctx,
    sink,
  ) {
    if ctx.scanner().has_prefix("^") {
      sink.emit(@markdown.Text("first"))
      1
    } else {
      0
    }
  })
  let second = @markdown.Rule::delimiter(
    "x:delimiter:second",
    priority=0,
    after=["x:delimiter:first"],
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("^") {
        sink.emit(@markdown.Text("second"))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("delimiter-order").add(second).add(first)
  assert_eq(
    @markdown.ParserBuilder::commonmark().use(plugin).parse("^").to_html(),
    "<p>first</p>\n",
  )
}

///|
test "external plugin can define wikilinks" {
  let wikilink = @markdown.Rule::inline("x:inline:wikilink", priority=100, fn(
    ctx,
    sink,
  ) {
    let source = ctx.source()
    let offset_index = ctx.offset()
    let rest = source[offset_index:].to_owned()
    if !rest.has_prefix("[[") {
      return 0
    }
    let mut end = offset_index + 2
    while end + 1 < source.length() &&
          !(source[end].to_int() == 93 && source[end + 1].to_int() == 93) {
      end = end + 1
    }
    if end + 1 >= source.length() {
      return 0
    }
    let target = source[offset_index + 2:end].to_owned()
    sink.emit(
      @markdown.Enter(
        @markdown.element_with_attrs("x:wikilink", [
          { name: "target", value: target },
        ]),
      ),
    )
    sink.emit(@markdown.Text(target))
    sink.emit(@markdown.Exit("x:wikilink"))
    end - offset_index + 2
  })
  let html = @markdown.ParserBuilder::commonmark()
    .use(@markdown.Plugin::new("wikilink").add(wikilink))
    .parse("See [[MoonBit]].")
    .to_html()
  assert_eq(
    html, "<p>See <x:wikilink target=\"MoonBit\">MoonBit</x:wikilink>.</p>\n",
  )
}

///|
test "external plugin core rule transforms event stream" {
  let core = @markdown.Rule::core("x:core:footer", priority=10, fn(events) {
    let next : Array[@markdown.Event] = []
    for event in events {
      next.push(event)
    }
    next.push(@markdown.Enter(@markdown.element("x:footer")))
    next.push(@markdown.Text("done"))
    next.push(@markdown.Exit("x:footer"))
    next
  })
  let html = @markdown.ParserBuilder::commonmark()
    .use(@markdown.Plugin::new("footer").add(core))
    .parse("body")
    .to_html()
  assert_eq(html, "<p>body</p>\n<x:footer>done</x:footer>")
}

///|
test "external core plugin rule can be disabled and re-enabled" {
  let core = @markdown.Rule::core("x:core:footer", priority=10, fn(events) {
    let next : Array[@markdown.Event] = []
    for event in events {
      next.push(event)
    }
    next.push(@markdown.Enter(@markdown.element("x:footer")))
    next.push(@markdown.Text("done"))
    next.push(@markdown.Exit("x:footer"))
    next
  })
  let plugin = @markdown.Plugin::new("footer").add(core)
  let disabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:core:footer")
    .parse("body")
    .to_html()
  assert_eq(disabled, "<p>body</p>\n")
  let enabled = @markdown.ParserBuilder::commonmark()
    .use(plugin)
    .disable("x:core:footer")
    .enable("x:core:footer")
    .parse("body")
    .to_html()
  assert_eq(enabled, "<p>body</p>\n<x:footer>done</x:footer>")
}

///|
test "rule order honors priority and registration order" {
  let a = @markdown.Rule::core("x:core:a", priority=1, fn(events) {
    let next : Array[@markdown.Event] = []
    for event in events {
      next.push(event)
    }
    next.push(@markdown.Text("A"))
    next
  })
  let b = @markdown.Rule::core("x:core:b", priority=10, fn(events) {
    let next : Array[@markdown.Event] = []
    for event in events {
      next.push(event)
    }
    next.push(@markdown.Text("B"))
    next
  })
  let c = @markdown.Rule::core("x:core:c", priority=1, fn(events) {
    let next : Array[@markdown.Event] = []
    for event in events {
      next.push(event)
    }
    next.push(@markdown.Text("C"))
    next
  })
  let plugin = @markdown.Plugin::new("order").add(a).add(b).add(c)
  assert_eq(
    @markdown.ParserBuilder::new().use(plugin).parse("").to_html(),
    "BAC",
  )
}

///|
test "rule order honors before and after edges" {
  let first = @markdown.Rule::core("x:core:first", after=["x:core:second"], fn(
    events,
  ) {
    let next : Array[@markdown.Event] = []
    for event in events {
      next.push(event)
    }
    next.push(@markdown.Text("1"))
    next
  })
  let second = @markdown.Rule::core("x:core:second", before=["x:core:first"], fn(
    events,
  ) {
    let next : Array[@markdown.Event] = []
    for event in events {
      next.push(event)
    }
    next.push(@markdown.Text("2"))
    next
  })
  let plugin = @markdown.Plugin::new("edges").add(first).add(second)
  assert_eq(
    @markdown.ParserBuilder::new().use(plugin).parse("").to_html(),
    "21",
  )
}

///|
test "block rule order honors before edges" {
  let first = @markdown.Rule::block("x:block:first", priority=1, fn(ctx, sink) {
    if ctx.current_line() == "!" {
      sink.emit(@markdown.Text("first"))
      1
    } else {
      0
    }
  })
  let second = @markdown.Rule::block(
    "x:block:second",
    priority=0,
    before=["x:block:first"],
    fn(ctx, sink) {
      if ctx.current_line() == "!" {
        sink.emit(@markdown.Text("second"))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("block-order").add(first).add(second)
  assert_eq(
    @markdown.ParserBuilder::new().use(plugin).parse("!").to_html(),
    "second",
  )
}

///|
test "rule order ignores edges that target another chain" {
  let first = @markdown.Rule::block("x:block:first", priority=10, fn(
    ctx,
    sink,
  ) {
    if ctx.current_line() == "!" {
      sink.emit(@markdown.Text("first"))
      1
    } else {
      0
    }
  })
  let second = @markdown.Rule::block(
    "x:block:second",
    priority=0,
    before=["x:inline:target"],
    fn(ctx, sink) {
      if ctx.current_line() == "!" {
        sink.emit(@markdown.Text("second"))
        1
      } else {
        0
      }
    },
  )
  let target = @markdown.Rule::inline("x:inline:target", priority=100, fn(
    _ctx,
    _sink,
  ) {
    0
  })
  let plugin = @markdown.Plugin::new("cross-chain-order")
    .add(first)
    .add(second)
    .add(target)
  assert_eq(
    @markdown.ParserBuilder::new().use(plugin).parse("!").to_html(),
    "first",
  )
}

///|
test "inline rule order honors after edges" {
  let first = @markdown.Rule::inline("x:inline:first", priority=1, fn(
    ctx,
    sink,
  ) {
    if ctx.scanner().has_prefix("@") {
      sink.emit(@markdown.Text("first"))
      1
    } else {
      0
    }
  })
  let second = @markdown.Rule::inline(
    "x:inline:second",
    priority=0,
    after=["x:inline:first"],
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@") {
        sink.emit(@markdown.Text("second"))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("inline-order").add(second).add(first)
  assert_eq(
    @markdown.ParserBuilder::commonmark().use(plugin).parse("@").to_html(),
    "<p>first</p>\n",
  )
}

///|
test "parser is pull based" {
  let parser = @markdown.ParserBuilder::commonmark().parse("hello")
  match parser.next() {
    Some(@markdown.Enter(el)) => assert_eq(el.tag, "cm:paragraph")
    _ => abort("expected paragraph enter")
  }
  match parser.next() {
    Some(@markdown.Text(text)) => assert_eq(text, "hello")
    _ => abort("expected text")
  }
  match parser.next() {
    Some(@markdown.Exit(tag)) => assert_eq(tag, "cm:paragraph")
    _ => abort("expected paragraph exit")
  }
  match parser.next() {
    None => ()
    Some(_) => abort("expected end of stream")
  }
  match parser.next() {
    None => ()
    Some(_) => abort("expected stable end of stream")
  }
}

///|
test "parser attaches block source ranges" {
  let parser = @markdown.ParserBuilder::commonmark().parse("# hi\n\ntext")
  match parser.next() {
    Some(@markdown.Enter(el)) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:heading")
          assert_eq(range.start, 0)
          assert_eq(range.end, 4)
        }
        None => abort("expected heading range")
      }
    _ => abort("expected heading enter")
  }
  ignore(parser.next())
  ignore(parser.next())
  match parser.next() {
    Some(@markdown.Enter(el)) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:paragraph")
          assert_eq(range.start, 6)
          assert_eq(range.end, 10)
        }
        None => abort("expected paragraph range")
      }
    _ => abort("expected paragraph enter")
  }
}

///|
test "parser attaches list source ranges" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("- one\n  continued\n- two")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:list")
          assert_eq(range.start, 0)
          assert_eq(range.end, 23)
        }
        None => abort("expected list range")
      }
    _ => abort("expected list enter")
  }
  match events[1] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:item")
          assert_eq(range.start, 0)
          assert_eq(range.end, 17)
        }
        None => abort("expected item range")
      }
    _ => abort("expected item enter")
  }
}

///|
test "parser attaches loose list source ranges across blank continuation" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("- one\n\n  two\n- three")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:list")
          assert_eq(range.start, 0)
          assert_eq(range.end, 20)
        }
        None => abort("expected loose list range")
      }
    _ => abort("expected list enter")
  }
  match events[1] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:item")
          assert_eq(range.start, 0)
          assert_eq(range.end, 12)
        }
        None => abort("expected loose item range")
      }
    _ => abort("expected item enter")
  }
}

///|
test "parser attaches blockquote source ranges" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("> quote\n> more\n\ntext")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:block_quote")
          assert_eq(range.start, 0)
          assert_eq(range.end, 14)
        }
        None => abort("expected blockquote range")
      }
    _ => abort("expected blockquote enter")
  }
}

///|
test "parser attaches fenced code source ranges" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("```\ncode\n```\n\ntext")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:code_block")
          assert_eq(range.start, 0)
          assert_eq(range.end, 12)
        }
        None => abort("expected fenced code range")
      }
    _ => abort("expected fenced code enter")
  }
}

///|
test "parser attaches unclosed fenced code source ranges" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("```\ncode")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:code_block")
          assert_eq(range.start, 0)
          assert_eq(range.end, 8)
        }
        None => abort("expected unclosed fence range")
      }
    _ => abort("expected fenced code enter")
  }
}

///|
test "parser attaches indented code source ranges" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("    code\n\ntext")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:code_block")
          assert_eq(range.start, 0)
          assert_eq(range.end, 8)
        }
        None => abort("expected indented code range")
      }
    _ => abort("expected indented code enter")
  }
}

///|
test "four space indented blockquote marker is code" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("    > quote")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:code_block")
          assert_eq(range.start, 0)
          assert_eq(range.end, 11)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented heading marker is code" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("    # foo")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:code_block")
          assert_eq(range.start, 0)
          assert_eq(range.end, 9)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented thematic break marker is code" {
  let events = @markdown.ParserBuilder::commonmark().parse("    ***").collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:code_block")
          assert_eq(range.start, 0)
          assert_eq(range.end, 7)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented setext underline stays paragraph" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("Foo\n    ---")
    .collect()
  match events[0] {
    @markdown.Enter(el) => assert_eq(el.tag, "cm:paragraph")
    _ => abort("expected paragraph")
  }
}

///|
test "four space indented fence does not interrupt paragraph" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("foo\n    ```")
    .collect()
  match events[0] {
    @markdown.Enter(el) => assert_eq(el.tag, "cm:paragraph")
    _ => abort("expected paragraph")
  }
}

///|
test "four space indented html block marker is code" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("    <div>")
    .collect()
  match events[0] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:code_block")
          assert_eq(range.start, 0)
          assert_eq(range.end, 9)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented list marker does not interrupt paragraph" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("paragraph\n    - item")
    .collect()
  match events[0] {
    @markdown.Enter(el) => assert_eq(el.tag, "cm:paragraph")
    _ => abort("expected paragraph")
  }
  for event in events {
    match event {
      @markdown.Enter(el) =>
        if el.tag == "cm:list" {
          abort("did not expect list")
        }
      _ => ()
    }
  }
}

///|
test "parser attaches thematic break source ranges" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("text\n\n---")
    .collect()
  match events[3] {
    @markdown.Enter(el) =>
      match el.range {
        Some(range) => {
          assert_eq(el.tag, "cm:thematic_break")
          assert_eq(range.start, 6)
          assert_eq(range.end, 9)
        }
        None => abort("expected thematic break range")
      }
    _ => abort("expected thematic break enter")
  }
}

///|
test "parser normalizes image alt text" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("![a\\*b &amp; c](/img.png)")
    .collect()
  match events[1] {
    @markdown.Enter(el) => {
      assert_eq(el.tag, "cm:image")
      assert_eq(el.attrs.length(), 2)
      assert_eq(el.attrs[1].name, "alt")
      assert_eq(el.attrs[1].value, "a*b & c")
    }
    _ => abort("expected image enter")
  }
}

///|
test "parser flattens image alt inline markup" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("![*em* **strong** `code`](/img.png)")
    .collect()
  match events[1] {
    @markdown.Enter(el) => {
      assert_eq(el.tag, "cm:image")
      assert_eq(el.attrs[1].name, "alt")
      assert_eq(el.attrs[1].value, "em strong code")
    }
    _ => abort("expected image enter")
  }
}

///|
test "parser normalizes link destination and title attributes" {
  let events = @markdown.ParserBuilder::commonmark()
    .parse("[link](/a\\*b?x=&amp; \"a\\*b &amp; c\")")
    .collect()
  match events[1] {
    @markdown.Enter(el) => {
      assert_eq(el.tag, "cm:link")
      assert_eq(el.attrs.length(), 2)
      assert_eq(el.attrs[0].value, "/a*b?x=&")
      assert_eq(el.attrs[1].value, "a*b & c")
    }
    _ => abort("expected link enter")
  }
}

///|
test "html renderer escapes text and attribute values" {
  let html = @markdown.HtmlRenderer::new().render([
    @markdown.Enter(
      @markdown.element_with_attrs("x:<tag>", [
        { name: "data<&>", value: "\"<&>" },
      ]),
    ),
    @markdown.Text("<&>\""),
    @markdown.Exit("x:<tag>"),
  ])
  assert_eq(
    html, "<x:&lt;tag&gt; data&lt;&amp;&gt;=\"&quot;&lt;&amp;&gt;\">&lt;&amp;&gt;&quot;</x:&lt;tag&gt;>",
  )
}

///|
test "html renderer preserves raw html events" {
  let html = @markdown.HtmlRenderer::new().render([
    @markdown.Text("<"),
    @markdown.Html("<span>raw</span>"),
    @markdown.Text(">"),
  ])
  assert_eq(html, "&lt;<span>raw</span>&gt;")
}

///|
test "html renderer preserves extension attrs on standard tags" {
  let events = [
    @markdown.Enter(
      @markdown.element_with_attrs("cm:paragraph", [
        { name: "class", value: "lead" },
      ]),
    ),
    @markdown.Enter(
      @markdown.element_with_attrs("cm:link", [
        { name: "destination", value: "/url" },
        { name: "title", value: "Title" },
        { name: "data-kind", value: "xref" },
      ]),
    ),
    @markdown.Text("link"),
    @markdown.Exit("cm:link"),
    @markdown.Exit("cm:paragraph"),
  ]
  assert_eq(
    @markdown.HtmlRenderer::new().render(events),
    "<p class=\"lead\"><a href=\"/url\" title=\"Title\" data-kind=\"xref\">link</a></p>\n",
  )
}

///|
test "html renderer preserves extension attrs on standard void tags" {
  let events = [
    @markdown.Enter(
      @markdown.element_with_attrs("cm:image", [
        { name: "destination", value: "/img.png" },
        { name: "alt", value: "alt" },
        { name: "data-size", value: "small" },
      ]),
    ),
    @markdown.Exit("cm:image"),
    @markdown.Enter(
      @markdown.element_with_attrs("cm:thematic_break", [
        { name: "class", value: "cut" },
      ]),
    ),
    @markdown.Exit("cm:thematic_break"),
  ]
  assert_eq(
    @markdown.HtmlRenderer::new().render(events),
    "<img src=\"/img.png\" alt=\"alt\" data-size=\"small\" /><hr class=\"cut\" />\n",
  )
}

///|
test "event transform and ast conversion keep extension tags" {
  let events = [
    @markdown.Enter(@markdown.element("x:note")),
    @markdown.Text("a"),
    @markdown.Text("b"),
    @markdown.Exit("x:note"),
  ]
  let transformed = @markdown.Transform::new(events)
    .text_merge()
    .inject_attr("x:note", { name: "role", value: "note" })
    .collect()
  let root = @markdown.AstBuilder::new().build(transformed)
  match root {
    Ok(node) => {
      assert_eq(node.children.length(), 1)
      match node.children[0].element {
        Some(el) => {
          assert_eq(el.tag, "x:note")
          assert_eq(el.attrs.length(), 1)
        }
        None => abort("expected element")
      }
      assert_eq(node.children[0].children[0].text, "ab")
    }
    Err(_) => abort("expected ast")
  }
}

///|
test "ast builder preserves extension attributes" {
  let result = @markdown.AstBuilder::new().build([
    @markdown.Enter(
      @markdown.element_with_attrs("x:note", [
        { name: "kind", value: "tip" },
        { name: "data-id", value: "42" },
      ]),
    ),
    @markdown.Text("body"),
    @markdown.Exit("x:note"),
  ])
  match result {
    Ok(root) =>
      match root.children[0].element {
        Some(el) => {
          assert_eq(el.tag, "x:note")
          assert_eq(el.attrs.length(), 2)
          assert_eq(el.attrs[0].name, "kind")
          assert_eq(el.attrs[0].value, "tip")
          assert_eq(el.attrs[1].name, "data-id")
          assert_eq(el.attrs[1].value, "42")
        }
        None => abort("expected element")
      }
    Err(_) => abort("expected ast")
  }
}

///|
test "ast builder preserves element source range" {
  let range : @markdown.SourceRange = { start: 2, end: 9 }
  let result = @markdown.AstBuilder::new().build([
    @markdown.Enter(
      @markdown.element_with_attrs("x:note", [], range=Some(range)),
    ),
    @markdown.Text("body"),
    @markdown.Exit("x:note"),
  ])
  match result {
    Ok(root) => {
      match root.children[0].range {
        Some(r) => {
          assert_eq(r.start, 2)
          assert_eq(r.end, 9)
        }
        None => abort("expected ast node range")
      }
      match root.children[0].element {
        Some(el) =>
          match el.range {
            Some(r) => {
              assert_eq(r.start, 2)
              assert_eq(r.end, 9)
            }
            None => abort("expected element range")
          }
        None => abort("expected element")
      }
    }
    Err(_) => abort("expected ast")
  }
}

///|
test "ast builder converts break and raw html events" {
  let result = @markdown.AstBuilder::new().build([
    @markdown.Text("a"),
    @markdown.SoftBreak,
    @markdown.HardBreak,
    @markdown.Html("<span>raw</span>"),
  ])
  match result {
    Ok(node) => {
      assert_eq(node.children.length(), 4)
      assert_eq(node.children[0].text, "a")
      assert_eq(node.children[1].text, "\n")
      match node.children[2].element {
        Some(el) => assert_eq(el.tag, "cm:hard_break")
        None => abort("expected hard break element")
      }
      match node.children[3].element {
        Some(el) => assert_eq(el.tag, "cm:html")
        None => abort("expected html element")
      }
      assert_eq(node.children[3].children[0].text, "<span>raw</span>")
    }
    Err(_) => abort("expected ast")
  }
}

///|
test "transform preserves source range while renaming and injecting attrs" {
  let range : @markdown.SourceRange = { start: 1, end: 4 }
  let events = [
    @markdown.Enter(
      @markdown.element_with_attrs("x:old", [], range=Some(range)),
    ),
    @markdown.Exit("x:old"),
  ]
  let transformed = @markdown.Transform::new(events)
    .rename_tag("x:old", "x:new")
    .inject_attr("x:new", { name: "class", value: "note" })
    .collect()
  match transformed[0] {
    @markdown.Enter(el) => {
      assert_eq(el.tag, "x:new")
      assert_eq(el.attrs.length(), 1)
      match el.range {
        Some(r) => {
          assert_eq(r.start, 1)
          assert_eq(r.end, 4)
        }
        None => abort("expected range")
      }
    }
    _ => abort("expected enter")
  }
}

///|
test "transform injects attrs on unknown extension tags" {
  let transformed = @markdown.Transform::new([
      @markdown.Enter(
        @markdown.element_with_attrs("x:note", [{ name: "kind", value: "tip" }]),
      ),
      @markdown.Exit("x:note"),
    ])
    .inject_attr("x:note", { name: "role", value: "note" })
    .collect()
  match transformed[0] {
    @markdown.Enter(el) => {
      assert_eq(el.tag, "x:note")
      assert_eq(el.attrs.length(), 2)
      assert_eq(el.attrs[0].name, "kind")
      assert_eq(el.attrs[0].value, "tip")
      assert_eq(el.attrs[1].name, "role")
      assert_eq(el.attrs[1].value, "note")
    }
    _ => abort("expected transformed enter")
  }
}

///|
test "transform text merge only merges adjacent text" {
  let transformed = @markdown.Transform::new([
      @markdown.Text("a"),
      @markdown.Text("b"),
      @markdown.SoftBreak,
      @markdown.Text("c"),
      @markdown.Text("d"),
    ])
    .text_merge()
    .collect()
  assert_eq(transformed.length(), 3)
  match transformed[0] {
    @markdown.Text(text) => assert_eq(text, "ab")
    _ => abort("expected merged first text")
  }
  match transformed[2] {
    @markdown.Text(text) => assert_eq(text, "cd")
    _ => abort("expected merged second text")
  }
}

///|
test "transform preserves event order and unknown tags" {
  let events = [
    @markdown.Enter(@markdown.element("x:unknown")),
    @markdown.Text("a"),
    @markdown.SoftBreak,
    @markdown.Text("b"),
    @markdown.Exit("x:unknown"),
  ]
  let transformed = @markdown.Transform::new(events)
    .softbreak_to_hardbreak()
    .collect()
  match transformed[0] {
    @markdown.Enter(el) => assert_eq(el.tag, "x:unknown")
    _ => abort("expected unknown enter")
  }
  match transformed[1] {
    @markdown.Text(text) => assert_eq(text, "a")
    _ => abort("expected first text")
  }
  match transformed[2] {
    @markdown.HardBreak => ()
    _ => abort("expected hard break")
  }
  match transformed[4] {
    @markdown.Exit(tag) => assert_eq(tag, "x:unknown")
    _ => abort("expected unknown exit")
  }
}

///|
test "ast builder rejects invalid event stream" {
  let result = @markdown.AstBuilder::new().build([@markdown.Exit("x:missing")])
  match result {
    Err(@markdown.UnexpectedExit(tag)) => assert_eq(tag, "x:missing")
    _ => abort("expected ast error")
  }
}

///|
test "ast builder rejects mismatched closing tag" {
  let result = @markdown.AstBuilder::new().build([
    @markdown.Enter(@markdown.element("x:open")),
    @markdown.Exit("x:other"),
  ])
  match result {
    Err(@markdown.UnexpectedExit(tag)) => assert_eq(tag, "x:other")
    _ => abort("expected mismatched tag error")
  }
}

///|
test "ast builder rejects unclosed tags" {
  let result = @markdown.AstBuilder::new().build([
    @markdown.Enter(@markdown.element("x:open")),
    @markdown.Text("body"),
  ])
  match result {
    Err(@markdown.UnclosedTag(tag)) => assert_eq(tag, "x:open")
    _ => abort("expected unclosed tag error")
  }
}
