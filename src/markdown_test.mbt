///|
test "commonmark block and inline html rendering" {
  let html = @markdown.Processor::commonmark().render_html(
    "## Hello *MoonBit*\n\n- one\n- two",
  )
  assert_eq(
    html, "<h2>Hello <em>MoonBit</em></h2>\n<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n",
  )
}

///|
test "convenience parser builders are available" {
  assert_eq(@markdown.to_html(@markdown.parse("# hi")), "<h1>hi</h1>\n")
  match @markdown.to_ast(@markdown.parse("# hi")) {
    Ok(root) => assert_eq(root.children().length(), 1)
    Err(_) => abort("expected AST")
  }
  assert_eq(@markdown.Processor::new().render_html("# hi"), "<p># hi</p>\n")
}

///|
test "commonmark plugin can be installed explicitly" {
  let html = @markdown.Processor::new()
    .with_plugin(@markdown.commonmark_plugin())
    .render_html("# hi\n\n*em*")
  assert_eq(html, "<h1>hi</h1>\n<p><em>em</em></p>\n")
}

///|
test "typed keys expose stable string contracts" {
  let cm_tag = @markdown.Tag::commonmark("paragraph")
  let custom_tag = @markdown.Tag::custom("x", "note")
  let raw_tag = @markdown.Tag::raw("x:raw")
  assert_eq(cm_tag.to_string(), "cm:paragraph")
  assert_eq(custom_tag.to_string(), "x:note")
  assert_eq(raw_tag.to_string(), "x:raw")
  assert_true(custom_tag == @markdown.Tag::raw("x:note"))
  let cm_attr = @markdown.AttrName::commonmark("title")
  let custom_attr = @markdown.AttrName::custom("x", "role")
  let raw_attr = @markdown.AttrName::raw("data-id")
  assert_eq(cm_attr.to_string(), "title")
  assert_eq(custom_attr.to_string(), "x:role")
  assert_eq(raw_attr.to_string(), "data-id")
  assert_true(custom_attr == @markdown.AttrName::raw("x:role"))
  let cm_rule = @markdown.RuleName::commonmark("block:paragraph")
  let custom_rule = @markdown.RuleName::custom("x", "inline:math")
  let raw_rule = @markdown.RuleName::raw("x:inline:math")
  assert_eq(cm_rule.to_string(), "cm:block:paragraph")
  assert_eq(custom_rule.to_string(), "x:inline:math")
  assert_eq(raw_rule.to_string(), "x:inline:math")
  assert_true(custom_rule == raw_rule)
}

///|
test "public element and attr accessors preserve extension data" {
  let range = @markdown.SourceRange::new(2, 8)
  let attr = @markdown.attr(@markdown.AttrName::custom("x", "role"), "tip")
  let el = @markdown.element_with_attrs(
    @markdown.Tag::custom("x", "note"),
    [attr],
    range=Some(range),
  )
  assert_eq(el.tag().to_string(), "x:note")
  assert_eq(el.attrs().length(), 1)
  assert_eq(el.attrs()[0].name().to_string(), "x:role")
  assert_eq(el.attrs()[0].value(), "tip")
  match el.range() {
    Some(actual) => {
      assert_eq(actual.start(), 2)
      assert_eq(actual.end(), 8)
    }
    None => abort("expected source range")
  }
}

///|
test "element attributes are isolated from mutable arrays" {
  let original = [@markdown.attr(@markdown.AttrName::raw("class"), "note")]
  let el = @markdown.element_with_attrs(@markdown.Tag::raw("x:note"), original)
  original.push(@markdown.attr(@markdown.AttrName::raw("id"), "later"))
  assert_eq(el.attrs().length(), 1)
  let exposed = el.attrs()
  exposed.push(@markdown.attr(@markdown.AttrName::raw("data-x"), "changed"))
  assert_eq(el.attrs().length(), 1)
  assert_eq(el.attrs()[0].name().to_string(), "class")
  assert_eq(el.attrs()[0].value(), "note")
}

///|
test "plugin and inline scanner public helpers have stable behavior" {
  let plugin = @markdown.Plugin::new("contract")
  assert_eq(plugin.name(), "contract")
  let scanner = @markdown.InlineScanner::new("abcdef", 2)
  assert_true(scanner.has_prefix("cd"))
  assert_true(!scanner.has_prefix("bc"))
  match scanner.char() {
    Some(c) => assert_eq(c, 99)
    None => abort("expected current char")
  }
  match scanner.char_at_offset(-1) {
    Some(c) => assert_eq(c, 98)
    None => abort("expected previous char")
  }
  assert_true(scanner.char_at_offset(4) is None)
  assert_eq(scanner.slice(-1, 2), "bcd")
  assert_eq(scanner.slice(3, 1), "")
  assert_eq(scanner.find_char(101), 2)
  assert_eq(scanner.find_char(120), -1)
}

///|
test "plugins compose in order" {
  let first = @markdown.Plugin::new("first").add(
    @markdown.Rule::inline(@markdown.RuleName::raw("x:inline:first"), fn(
      ctx,
      sink,
    ) {
      if ctx.scanner().has_prefix("#") {
        sink.emit(Text("first"))
        1
      } else {
        0
      }
    }),
  )
  let second = @markdown.Plugin::new("second").add(
    @markdown.Rule::inline(@markdown.RuleName::raw("x:inline:second"), fn(
      ctx,
      sink,
    ) {
      if ctx.scanner().has_prefix("#") {
        sink.emit(Text("second"))
        1
      } else {
        0
      }
    }),
  )
  let first_then_second = @markdown.Plugin::new("combined")
    .with_plugin(first)
    .with_plugin(second)
  let second_then_first = @markdown.Plugin::new("combined")
    .with_plugin(second)
    .with_plugin(first)
  assert_eq(
    @markdown.Processor::new().with_plugin(first_then_second).render_html("#"),
    "<p>first</p>\n",
  )
  assert_eq(
    @markdown.Processor::new().with_plugin(second_then_first).render_html("#"),
    "<p>second</p>\n",
  )
}

///|
test "plugin builders leave the original plugin unchanged" {
  let rule = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("#") {
        sink.emit(Text("marker"))
        1
      } else {
        0
      }
    },
  )
  let base = @markdown.Plugin::new("base")
  let configured = base.add(rule)
  assert_eq(
    @markdown.Processor::new().with_plugin(base).render_html("#"),
    "<p>#</p>\n",
  )
  assert_eq(
    @markdown.Processor::new().with_plugin(configured).render_html("#"),
    "<p>marker</p>\n",
  )
}

///|
test "processor builders leave the original processor unchanged" {
  let base = @markdown.Processor::new()
  let configured = base.with_plugin(@markdown.commonmark_plugin())
  assert_eq(base.render_html("# hi"), "<p># hi</p>\n")
  assert_eq(configured.render_html("# hi"), "<h1>hi</h1>\n")
}

///|
test "plugins can carry rule controls" {
  let no_heading = @markdown.Plugin::new("no-heading")
    .disable(@markdown.RuleName::raw("cm:block:atx_heading"))
    .with_plugin(@markdown.commonmark_plugin())
  assert_eq(
    @markdown.Processor::new().with_plugin(no_heading).render_html("# title"),
    "<p># title</p>\n",
  )

  let heading = @markdown.Rule::block(
    @markdown.RuleName::raw("cm:block:atx_heading"),
    priority=60,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("# ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:heading"))))
        sink.emit(Text("overridden"))
        sink.emit(Exit(@markdown.Tag::raw("x:heading")))
        1
      } else {
        0
      }
    },
  )
  let overridden = @markdown.commonmark_plugin().override_rule(heading)
  assert_eq(
    @markdown.Processor::new().with_plugin(overridden).render_html("# title"),
    "<x:heading>overridden</x:heading>",
  )
}

///|
test "plugin override applies to later matching rules" {
  let override_rule = @markdown.Rule::block(
    @markdown.RuleName::raw("cm:block:atx_heading"),
    priority=60,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("# ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:heading"))))
        sink.emit(Text("configured"))
        sink.emit(Exit(@markdown.Tag::raw("x:heading")))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("heading-override")
    .override_rule(override_rule)
    .with_plugin(@markdown.commonmark_plugin())
  assert_eq(
    @markdown.Processor::new().with_plugin(plugin).render_html("# title"),
    "<x:heading>configured</x:heading>",
  )
}

///|
test "block context public helpers expose parser position safely" {
  let seen : Array[String] = []
  let rule = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:context"),
    priority=100,
    fn(ctx, sink) {
      seen.push(ctx.current_line())
      seen.push(ctx.line_index().to_string())
      seen.push(ctx.current_line_start().to_string())
      match ctx.line_at(-1) {
        None => seen.push("none-before")
        Some(_) => seen.push("unexpected-before")
      }
      match ctx.line_at(ctx.line_index() + 1) {
        Some(line) => seen.push(line)
        None => seen.push("unexpected-next")
      }
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:ctx"))))
      sink.emit(Text(ctx.current_line()))
      sink.emit(Exit(@markdown.Tag::raw("x:ctx")))
      1
    },
  )
  let html = @markdown.Processor::new()
    .with_plugin(@markdown.Plugin::new("context").add(rule))
    .render_html("first\nsecond")
  assert_eq(html, "<x:ctx>first</x:ctx><x:ctx>second</x:ctx>")
  assert_eq(seen.length(), 10)
  assert_eq(seen[0], "first")
  assert_eq(seen[1], "0")
  assert_eq(seen[2], "0")
  assert_eq(seen[3], "none-before")
  assert_eq(seen[4], "second")
  assert_eq(seen[5], "second")
  assert_eq(seen[6], "1")
  assert_eq(seen[7], "6")
  assert_eq(seen[8], "none-before")
  assert_eq(seen[9], "unexpected-next")
}

///|
test "html renderer keeps extension tags attrs and stray exits deterministic" {
  let events : Array[@markdown.Event] = [
    Enter(
      @markdown.element_with_attrs(@markdown.Tag::custom("x", "note"), [
        @markdown.attr(@markdown.AttrName::custom("x", "role"), "tip"),
      ]),
    ),
    Text("<body>"),
    Exit(@markdown.Tag::custom("x", "note")),
    Exit(@markdown.Tag::custom("x", "missing")),
  ]
  let html = @markdown.HtmlRenderer::new().render(events)
  assert_eq(html, "<x:note x:role=\"tip\">&lt;body&gt;</x:note></x:missing>")
}

///|
test "empty builder parses paragraph text without registered rules" {
  let parser = @markdown.Processor::new().parse("plain")
  match parser.next() {
    Some(Enter(el)) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected fallback paragraph")
  }
  match parser.next() {
    Some(Text(text)) => assert_eq(text, "plain")
    _ => abort("expected fallback text")
  }
  match parser.next() {
    Some(Exit(tag)) => assert_eq(tag.to_string(), "cm:paragraph")
    _ => abort("expected fallback paragraph exit")
  }
  match parser.next() {
    None => ()
    Some(_) => abort("expected end")
  }
}

///|
test "ordered list and code block render with balanced tags" {
  let html = @markdown.Processor::commonmark().render_html(
    "1. one\n2. two\n\n```\n<a>\n```",
  )
  assert_eq(
    html, "<ol>\n<li>one</li>\n<li>two</li>\n</ol>\n<pre><code>&lt;a&gt;\n</code></pre>\n",
  )
}

///|
test "standard rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:block:atx_heading"),
  )
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("# not a heading")
  assert_eq(html, "<p># not a heading</p>\n")
}

///|
test "disabled standard rule can be re-enabled" {
  let plugin = @markdown.commonmark_plugin()
    .disable(@markdown.RuleName::raw("cm:block:atx_heading"))
    .enable(@markdown.RuleName::raw("cm:block:atx_heading"))
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("# heading")
  assert_eq(html, "<h1>heading</h1>\n")
}

///|
test "setext heading rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:block:setext_heading"),
  )
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("heading\n---")
  assert_eq(html, "<p>heading</p>\n<hr />\n")
}

///|
test "list rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:block:list"),
  )
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("1) one")
  assert_eq(html, "<p>1) one</p>\n")
}

///|
test "paragraph rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:block:paragraph"),
  )
  let html = @markdown.Processor::new().with_plugin(plugin).render_html("plain")
  assert_eq(html, "plain")
}

///|
test "paragraph rule can be overridden" {
  let override_rule = @markdown.Rule::block(
    @markdown.RuleName::raw("cm:block:paragraph"),
    priority=0,
    fn(ctx, sink) {
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:paragraph"))))
      sink.emit(Text(ctx.current_line()))
      sink.emit(Exit(@markdown.Tag::raw("x:paragraph")))
      1
    },
  )
  let plugin = @markdown.commonmark_plugin().override_rule(override_rule)
  let html = @markdown.Processor::new().with_plugin(plugin).render_html("plain")
  assert_eq(html, "<x:paragraph>plain</x:paragraph>")
}

///|
test "reference definition core rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:core:reference_definitions"),
  )
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("[foo]: /url\n\n[foo]")
  assert_eq(html, "<p>[foo]: /url</p>\n<p>[foo]</p>\n")
}

///|
test "reference definition continuation core rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:core:reference_definitions"),
  )
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("[foo]: /url\n  'title'\n\n[foo]")
  assert_eq(html, "<p>[foo]: /url\n'title'</p>\n<p>[foo]</p>\n")
}

///|
test "reference definition core rule can be disabled for images" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:core:reference_definitions"),
  )
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("[alt]: /img.png\n\n![alt]")
  assert_eq(html, "<p>[alt]: /img.png</p>\n<p>![alt]</p>\n")
}

///|
test "reference definition core rule can be overridden" {
  let override_rule = @markdown.Rule::core(
    @markdown.RuleName::raw("cm:core:reference_definitions"),
    priority=100,
    fn(events) { events },
  )
  let plugin = @markdown.commonmark_plugin().override_rule(override_rule)
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("[foo]: /url\n\n[foo]")
  assert_eq(html, "<p>[foo]: /url</p>\n<p>[foo]</p>\n")
}

///|
test "hard break rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:inline:hard_break"),
  )
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("a\\\nb")
  assert_eq(html, "<p>a\\\nb</p>\n")
}

///|
test "hard break rule emits event for backslash and spaces" {
  let backslash = @markdown.Processor::commonmark().parse("a\\\nb").collect()
  match backslash[2] {
    HardBreak => ()
    _ => abort("expected backslash hard break")
  }
  let spaces = @markdown.Processor::commonmark().parse("a  \nb").collect()
  match spaces[2] {
    HardBreak => ()
    _ => abort("expected spaces hard break")
  }
}

///|
test "soft break rule emits event and can be disabled" {
  let enabled = @markdown.Processor::commonmark().parse("a\nb").collect()
  match enabled[2] {
    SoftBreak => ()
    _ => abort("expected soft break")
  }
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:inline:soft_break"),
  )
  let disabled = @markdown.Processor::new()
    .with_plugin(plugin)
    .parse("a\nb")
    .collect()
  match disabled[2] {
    Text(text) => assert_eq(text, "\n")
    _ => abort("expected text newline")
  }
}

///|
test "entity rule can be disabled" {
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:inline:entity"),
  )
  let html = @markdown.Processor::new().with_plugin(plugin).render_html("&amp;")
  assert_eq(html, "<p>&amp;amp;</p>\n")
}

///|
test "entity rule emits text event and can be disabled" {
  let enabled = @markdown.Processor::commonmark().parse("&amp;").collect()
  match enabled[1] {
    Text(text) => assert_eq(text, "&")
    _ => abort("expected decoded entity text")
  }
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:inline:entity"),
  )
  let disabled = @markdown.Processor::new()
    .with_plugin(plugin)
    .parse("&amp;")
    .collect()
  match disabled[1] {
    Text(text) => assert_eq(text, "&")
    _ => abort("expected raw ampersand text")
  }
  match disabled[2] {
    Text(text) => assert_eq(text, "amp;")
    _ => abort("expected raw entity suffix text")
  }
}

///|
test "standard rule can be overridden" {
  let override_rule = @markdown.Rule::block(
    @markdown.RuleName::raw("cm:block:atx_heading"),
    priority=100,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("# ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:heading"))))
        sink.emit(Text("overridden"))
        sink.emit(Exit(@markdown.Tag::raw("x:heading")))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.commonmark_plugin().override_rule(override_rule)
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("# hello")
  assert_eq(html, "<x:heading>overridden</x:heading>")
}

///|
test "overridden disabled rule stays disabled until enabled" {
  let override_rule = @markdown.Rule::block(
    @markdown.RuleName::raw("cm:block:atx_heading"),
    priority=100,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("# ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:heading"))))
        sink.emit(Text("overridden"))
        sink.emit(Exit(@markdown.Tag::raw("x:heading")))
        1
      } else {
        0
      }
    },
  )
  let disabled_plugin = @markdown.commonmark_plugin()
    .disable(@markdown.RuleName::raw("cm:block:atx_heading"))
    .override_rule(override_rule)
  let disabled_html = @markdown.Processor::new()
    .with_plugin(disabled_plugin)
    .render_html("# hello")
  assert_eq(disabled_html, "<p># hello</p>\n")
  let enabled_plugin = @markdown.commonmark_plugin()
    .disable(@markdown.RuleName::raw("cm:block:atx_heading"))
    .override_rule(override_rule)
    .enable(@markdown.RuleName::raw("cm:block:atx_heading"))
  let enabled_html = @markdown.Processor::new()
    .with_plugin(enabled_plugin)
    .render_html("# hello")
  assert_eq(enabled_html, "<x:heading>overridden</x:heading>")
}

///|
test "standard delimiter rule can be overridden" {
  let override_rule = @markdown.Rule::delimiter(
    @markdown.RuleName::raw("cm:delimiter:emphasis"),
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
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:emphasis"))))
      sink.emit(Text(scanner.slice(1, close)))
      sink.emit(Exit(@markdown.Tag::raw("x:emphasis")))
      close + 1
    },
  )
  let plugin = @markdown.commonmark_plugin().override_rule(override_rule)
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("*hello*")
  assert_eq(html, "<p><x:emphasis>hello</x:emphasis></p>\n")
}

///|
test "standard inline rule can be overridden" {
  let override_rule = @markdown.Rule::inline(
    @markdown.RuleName::raw("cm:inline:code_span"),
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
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:code"))))
      sink.emit(Text(scanner.slice(1, close)))
      sink.emit(Exit(@markdown.Tag::raw("x:code")))
      close + 1
    },
  )
  let plugin = @markdown.commonmark_plugin().override_rule(override_rule)
  let html = @markdown.Processor::new()
    .with_plugin(plugin)
    .render_html("`hello`")
  assert_eq(html, "<p><x:code>hello</x:code></p>\n")
}

///|
test "standard text inline rule can be overridden" {
  let override_rule = @markdown.Rule::inline(
    @markdown.RuleName::raw("cm:inline:text"),
    priority=-1000,
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("abc") {
        sink.emit(Text("XYZ"))
        3
      } else {
        0
      }
    },
  )
  let plugin = @markdown.commonmark_plugin().override_rule(override_rule)
  let html = @markdown.Processor::new().with_plugin(plugin).render_html("abc")
  assert_eq(html, "<p>XYZ</p>\n")
}

///|
test "standard text inline rule can be disabled" {
  let enabled = @markdown.Processor::commonmark().parse("abc").collect()
  match enabled[1] {
    Text(text) => assert_eq(text, "abc")
    _ => abort("expected text")
  }
  let plugin = @markdown.commonmark_plugin().disable(
    @markdown.RuleName::raw("cm:inline:text"),
  )
  let disabled = @markdown.Processor::new()
    .with_plugin(plugin)
    .parse("abc")
    .collect()
  match disabled[1] {
    Text(text) => assert_eq(text, "a")
    _ => abort("expected fallback text")
  }
  match disabled[2] {
    Text(text) => assert_eq(text, "b")
    _ => abort("expected fallback text")
  }
  match disabled[3] {
    Text(text) => assert_eq(text, "c")
    _ => abort("expected fallback text")
  }
}

///|
test "external plugin rule participates in block chain" {
  let admonition = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:admonition"),
    priority=100,
    fn(ctx, sink) {
      let line = ctx.current_line()
      if line.has_prefix("!!! ") {
        sink.emit(
          Enter(
            @markdown.element_with_attrs(@markdown.Tag::raw("x:admonition"), [
              @markdown.attr(
                @markdown.AttrName::raw("kind"),
                line[4:].to_owned(),
              ),
            ]),
          ),
        )
        sink.emit(Exit(@markdown.Tag::raw("x:admonition")))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("admonition").add(admonition)
  let html = @markdown.Processor::commonmark()
    .with_plugin(plugin)
    .render_html("!!! note")
  assert_eq(html, "<x:admonition kind=\"note\"></x:admonition>")
}

///|
test "external block plugin rule can be disabled and re-enabled" {
  let admonition = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:admonition"),
    priority=100,
    fn(ctx, sink) {
      let line = ctx.current_line()
      if line.has_prefix("!!! ") {
        sink.emit(
          Enter(
            @markdown.element_with_attrs(@markdown.Tag::raw("x:admonition"), [
              @markdown.attr(
                @markdown.AttrName::raw("kind"),
                line[4:].to_owned(),
              ),
            ]),
          ),
        )
        sink.emit(Exit(@markdown.Tag::raw("x:admonition")))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("admonition").add(admonition)
  let disabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:block:admonition"))
  let disabled = @markdown.Processor::new()
    .with_plugin(disabled_plugin)
    .render_html("!!! note")
  assert_eq(disabled, "<p>!!! note</p>\n")
  let enabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:block:admonition"))
    .enable(@markdown.RuleName::raw("x:block:admonition"))
  let enabled = @markdown.Processor::new()
    .with_plugin(enabled_plugin)
    .render_html("!!! note")
  assert_eq(enabled, "<x:admonition kind=\"note\"></x:admonition>")
}

///|
test "external plugin rule can be disabled and re-enabled" {
  let marker = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@@") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:marker"))))
        sink.emit(Text("marked"))
        sink.emit(Exit(@markdown.Tag::raw("x:marker")))
        2
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("marker").add(marker)
  let disabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:inline:marker"))
  let disabled = @markdown.Processor::new()
    .with_plugin(disabled_plugin)
    .render_html("@@")
  assert_eq(disabled, "<p>@@</p>\n")
  let enabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:inline:marker"))
    .enable(@markdown.RuleName::raw("x:inline:marker"))
  let enabled = @markdown.Processor::new()
    .with_plugin(enabled_plugin)
    .render_html("@@")
  assert_eq(enabled, "<p><x:marker>marked</x:marker></p>\n")
}

///|
test "external block plugin can consume multiline admonition" {
  let admonition = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:admonition"),
    priority=100,
    fn(ctx, sink) {
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
        Enter(
          @markdown.element_with_attrs(
            @markdown.Tag::raw("x:admonition"),
            [
              @markdown.attr(
                @markdown.AttrName::raw("kind"),
                line[4:].to_owned(),
              ),
            ],
            range=Some(@markdown.SourceRange::new(start, start + line.length())),
          ),
        ),
      )
      sink.emit(Text(body))
      sink.emit(Exit(@markdown.Tag::raw("x:admonition")))
      consumed
    },
  )
  let events = @markdown.Processor::commonmark()
    .with_plugin(@markdown.Plugin::new("admonition").add(admonition))
    .parse("!!! note\n    first\n    second\n\nnext")
    .collect()
  match events[0] {
    Enter(el) => {
      assert_eq(el.tag().to_string(), "x:admonition")
      assert_eq(el.attrs()[0].value(), "note")
      match el.range() {
        Some(range) => {
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 8)
        }
        None => abort("expected admonition range")
      }
    }
    _ => abort("expected admonition")
  }
  match events[1] {
    Text(text) => assert_eq(text, "first\nsecond")
    _ => abort("expected admonition body")
  }
  match events[3] {
    Enter(el) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected following paragraph")
  }
}

///|
test "external plugin rule participates in block continue chain" {
  let continuation = @markdown.Rule::block_continue(
    @markdown.RuleName::raw("x:block_continue:marker"),
    priority=-100,
    fn(ctx, sink) {
      let line = ctx.current_line()
      if line.has_prefix("% ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:continued"))))
        sink.emit(Text(line[2:].to_owned()))
        sink.emit(Exit(@markdown.Tag::raw("x:continued")))
        1
      } else {
        0
      }
    },
  )
  let start = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:start_marker"),
    priority=100,
    fn(ctx, sink) {
      let line = ctx.current_line()
      if line.has_prefix("% ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:start"))))
        sink.emit(Text(line[2:].to_owned()))
        sink.emit(Exit(@markdown.Tag::raw("x:start")))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("block-continue")
    .add(start)
    .add(continuation)
  let html = @markdown.Processor::commonmark()
    .with_plugin(plugin)
    .render_html("% done")
  assert_eq(html, "<x:continued>done</x:continued>")
}

///|
test "external block continue rule can be disabled and re-enabled" {
  let continuation = @markdown.Rule::block_continue(
    @markdown.RuleName::raw("x:block_continue:marker"),
    priority=-100,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("% ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:continued"))))
        sink.emit(Text(ctx.current_line()[2:].to_owned()))
        sink.emit(Exit(@markdown.Tag::raw("x:continued")))
        1
      } else {
        0
      }
    },
  )
  let start = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:start_marker"),
    priority=100,
    fn(ctx, sink) {
      if ctx.current_line().has_prefix("% ") {
        sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:start"))))
        sink.emit(Text(ctx.current_line()[2:].to_owned()))
        sink.emit(Exit(@markdown.Tag::raw("x:start")))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("block-continue")
    .add(start)
    .add(continuation)
  let disabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:block_continue:marker"))
  let disabled = @markdown.Processor::new()
    .with_plugin(disabled_plugin)
    .render_html("% done")
  assert_eq(disabled, "<x:start>done</x:start>")
  let enabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:block_continue:marker"))
    .enable(@markdown.RuleName::raw("x:block_continue:marker"))
  let enabled = @markdown.Processor::new()
    .with_plugin(enabled_plugin)
    .render_html("% done")
  assert_eq(enabled, "<x:continued>done</x:continued>")
}

///|
test "block continue rule order honors before edges" {
  let first = @markdown.Rule::block_continue(
    @markdown.RuleName::raw("x:block_continue:first"),
    priority=10,
    fn(ctx, sink) {
      if ctx.current_line() == "%" {
        sink.emit(Text("first"))
        1
      } else {
        0
      }
    },
  )
  let second = @markdown.Rule::block_continue(
    @markdown.RuleName::raw("x:block_continue:second"),
    priority=0,
    before=[@markdown.RuleName::raw("x:block_continue:first")],
    fn(ctx, sink) {
      if ctx.current_line() == "%" {
        sink.emit(Text("second"))
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
    @markdown.Processor::new().with_plugin(plugin).render_html("%"),
    "second",
  )
}

///|
test "external plugin rule participates in inline chain" {
  let math = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:math"),
    priority=100,
    fn(ctx, sink) {
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
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:math"))))
      sink.emit(Text(scanner.slice(1, offset)))
      sink.emit(Exit(@markdown.Tag::raw("x:math")))
      offset + 1
    },
  )
  let html = @markdown.Processor::commonmark()
    .with_plugin(@markdown.Plugin::new("math").add(math))
    .render_html("a $x + y$ b")
  assert_eq(html, "<p>a <x:math>x + y</x:math> b</p>\n")
}

///|
test "external plugin rule participates in delimiter chain" {
  let mark = @markdown.Rule::delimiter(
    @markdown.RuleName::raw("x:delimiter:mark"),
    priority=100,
    fn(ctx, sink) {
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
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:mark"))))
      sink.emit(Text(scanner.slice(2, offset)))
      sink.emit(Exit(@markdown.Tag::raw("x:mark")))
      offset + 2
    },
  )
  let html = @markdown.Processor::commonmark()
    .with_plugin(@markdown.Plugin::new("mark").add(mark))
    .render_html("a ^^marked^^ b")
  assert_eq(html, "<p>a <x:mark>marked</x:mark> b</p>\n")
}

///|
test "external delimiter rule can be disabled and re-enabled" {
  let mark = @markdown.Rule::delimiter(
    @markdown.RuleName::raw("x:delimiter:mark"),
    priority=100,
    fn(ctx, sink) {
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
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:mark"))))
      sink.emit(Text(ctx.scanner().slice(2, offset)))
      sink.emit(Exit(@markdown.Tag::raw("x:mark")))
      offset + 2
    },
  )
  let plugin = @markdown.Plugin::new("mark").add(mark)
  let disabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:delimiter:mark"))
  let disabled = @markdown.Processor::new()
    .with_plugin(disabled_plugin)
    .render_html("a ^^marked^^ b")
  assert_eq(disabled, "<p>a ^^marked^^ b</p>\n")
  let enabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:delimiter:mark"))
    .enable(@markdown.RuleName::raw("x:delimiter:mark"))
  let enabled = @markdown.Processor::new()
    .with_plugin(enabled_plugin)
    .render_html("a ^^marked^^ b")
  assert_eq(enabled, "<p>a <x:mark>marked</x:mark> b</p>\n")
}

///|
test "delimiter rule order honors after edges" {
  let first = @markdown.Rule::delimiter(
    @markdown.RuleName::raw("x:delimiter:first"),
    priority=1,
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("^") {
        sink.emit(Text("first"))
        1
      } else {
        0
      }
    },
  )
  let second = @markdown.Rule::delimiter(
    @markdown.RuleName::raw("x:delimiter:second"),
    priority=0,
    after=[@markdown.RuleName::raw("x:delimiter:first")],
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("^") {
        sink.emit(Text("second"))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("delimiter-order").add(second).add(first)
  assert_eq(
    @markdown.Processor::commonmark().with_plugin(plugin).render_html("^"),
    "<p>first</p>\n",
  )
}

///|
test "external plugin can define wikilinks" {
  let wikilink = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:wikilink"),
    priority=100,
    fn(ctx, sink) {
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
        Enter(
          @markdown.element_with_attrs(@markdown.Tag::raw("x:wikilink"), [
            @markdown.attr(@markdown.AttrName::raw("target"), target),
          ]),
        ),
      )
      sink.emit(Text(target))
      sink.emit(Exit(@markdown.Tag::raw("x:wikilink")))
      end - offset_index + 2
    },
  )
  let html = @markdown.Processor::commonmark()
    .with_plugin(@markdown.Plugin::new("wikilink").add(wikilink))
    .render_html("See [[MoonBit]].")
  assert_eq(
    html, "<p>See <x:wikilink target=\"MoonBit\">MoonBit</x:wikilink>.</p>\n",
  )
}

///|
test "external plugin core rule transforms event stream" {
  let core = @markdown.Rule::core(
    @markdown.RuleName::raw("x:core:footer"),
    priority=10,
    fn(events) {
      let next : Array[@markdown.Event] = []
      for event in events {
        next.push(event)
      }
      next.push(Enter(@markdown.element(@markdown.Tag::raw("x:footer"))))
      next.push(Text("done"))
      next.push(Exit(@markdown.Tag::raw("x:footer")))
      next
    },
  )
  let html = @markdown.Processor::commonmark()
    .with_plugin(@markdown.Plugin::new("footer").add(core))
    .render_html("body")
  assert_eq(html, "<p>body</p>\n<x:footer>done</x:footer>")
}

///|
test "external core plugin rule can be disabled and re-enabled" {
  let core = @markdown.Rule::core(
    @markdown.RuleName::raw("x:core:footer"),
    priority=10,
    fn(events) {
      let next : Array[@markdown.Event] = []
      for event in events {
        next.push(event)
      }
      next.push(Enter(@markdown.element(@markdown.Tag::raw("x:footer"))))
      next.push(Text("done"))
      next.push(Exit(@markdown.Tag::raw("x:footer")))
      next
    },
  )
  let plugin = @markdown.Plugin::new("footer").add(core)
  let disabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:core:footer"))
  let disabled = @markdown.Processor::new()
    .with_plugin(disabled_plugin)
    .render_html("body")
  assert_eq(disabled, "<p>body</p>\n")
  let enabled_plugin = @markdown.commonmark_plugin()
    .with_plugin(plugin)
    .disable(@markdown.RuleName::raw("x:core:footer"))
    .enable(@markdown.RuleName::raw("x:core:footer"))
  let enabled = @markdown.Processor::new()
    .with_plugin(enabled_plugin)
    .render_html("body")
  assert_eq(enabled, "<p>body</p>\n<x:footer>done</x:footer>")
}

///|
test "rule order honors priority and registration order" {
  let a = @markdown.Rule::core(
    @markdown.RuleName::raw("x:core:a"),
    priority=1,
    fn(events) {
      let next : Array[@markdown.Event] = []
      for event in events {
        next.push(event)
      }
      next.push(Text("A"))
      next
    },
  )
  let b = @markdown.Rule::core(
    @markdown.RuleName::raw("x:core:b"),
    priority=10,
    fn(events) {
      let next : Array[@markdown.Event] = []
      for event in events {
        next.push(event)
      }
      next.push(Text("B"))
      next
    },
  )
  let c = @markdown.Rule::core(
    @markdown.RuleName::raw("x:core:c"),
    priority=1,
    fn(events) {
      let next : Array[@markdown.Event] = []
      for event in events {
        next.push(event)
      }
      next.push(Text("C"))
      next
    },
  )
  let plugin = @markdown.Plugin::new("order").add(a).add(b).add(c)
  assert_eq(
    @markdown.Processor::new().with_plugin(plugin).render_html(""),
    "BAC",
  )
}

///|
test "rule order honors before and after edges" {
  let first = @markdown.Rule::core(
    @markdown.RuleName::raw("x:core:first"),
    after=[@markdown.RuleName::raw("x:core:second")],
    fn(events) {
      let next : Array[@markdown.Event] = []
      for event in events {
        next.push(event)
      }
      next.push(Text("1"))
      next
    },
  )
  let second = @markdown.Rule::core(
    @markdown.RuleName::raw("x:core:second"),
    before=[@markdown.RuleName::raw("x:core:first")],
    fn(events) {
      let next : Array[@markdown.Event] = []
      for event in events {
        next.push(event)
      }
      next.push(Text("2"))
      next
    },
  )
  let plugin = @markdown.Plugin::new("edges").add(first).add(second)
  assert_eq(
    @markdown.Processor::new().with_plugin(plugin).render_html(""),
    "21",
  )
}

///|
test "block rule order honors before edges" {
  let first = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:first"),
    priority=1,
    fn(ctx, sink) {
      if ctx.current_line() == "!" {
        sink.emit(Text("first"))
        1
      } else {
        0
      }
    },
  )
  let second = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:second"),
    priority=0,
    before=[@markdown.RuleName::raw("x:block:first")],
    fn(ctx, sink) {
      if ctx.current_line() == "!" {
        sink.emit(Text("second"))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("block-order").add(first).add(second)
  assert_eq(
    @markdown.Processor::new().with_plugin(plugin).render_html("!"),
    "second",
  )
}

///|
test "rule order ignores edges that target another chain" {
  let first = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:first"),
    priority=10,
    fn(ctx, sink) {
      if ctx.current_line() == "!" {
        sink.emit(Text("first"))
        1
      } else {
        0
      }
    },
  )
  let second = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:second"),
    priority=0,
    before=[@markdown.RuleName::raw("x:inline:target")],
    fn(ctx, sink) {
      if ctx.current_line() == "!" {
        sink.emit(Text("second"))
        1
      } else {
        0
      }
    },
  )
  let target = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:target"),
    priority=100,
    fn(_ctx, _sink) { 0 },
  )
  let plugin = @markdown.Plugin::new("cross-chain-order")
    .add(first)
    .add(second)
    .add(target)
  assert_eq(
    @markdown.Processor::new().with_plugin(plugin).render_html("!"),
    "first",
  )
}

///|
test "inline rule order honors after edges" {
  let first = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:first"),
    priority=1,
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@") {
        sink.emit(Text("first"))
        1
      } else {
        0
      }
    },
  )
  let second = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:second"),
    priority=0,
    after=[@markdown.RuleName::raw("x:inline:first")],
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@") {
        sink.emit(Text("second"))
        1
      } else {
        0
      }
    },
  )
  let plugin = @markdown.Plugin::new("inline-order").add(second).add(first)
  assert_eq(
    @markdown.Processor::commonmark().with_plugin(plugin).render_html("@"),
    "<p>first</p>\n",
  )
}

///|
test "parser is pull based" {
  let parser = @markdown.Processor::commonmark().parse("hello")
  match parser.next() {
    Some(Enter(el)) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected paragraph enter")
  }
  match parser.next() {
    Some(Text(text)) => assert_eq(text, "hello")
    _ => abort("expected text")
  }
  match parser.next() {
    Some(Exit(tag)) => assert_eq(tag.to_string(), "cm:paragraph")
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
  let parser = @markdown.Processor::commonmark().parse("# hi\n\ntext")
  match parser.next() {
    Some(Enter(el)) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:heading")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 4)
        }
        None => abort("expected heading range")
      }
    _ => abort("expected heading enter")
  }
  ignore(parser.next())
  ignore(parser.next())
  match parser.next() {
    Some(Enter(el)) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:paragraph")
          assert_eq(range.start(), 6)
          assert_eq(range.end(), 10)
        }
        None => abort("expected paragraph range")
      }
    _ => abort("expected paragraph enter")
  }
}

///|
test "parser collect does not expose internal event arrays" {
  let parser = @markdown.Processor::commonmark().parse("hello")
  let events = parser.collect()
  assert_eq(events.length(), 3)
  ignore(events.pop())
  assert_eq(events.length(), 2)
  assert_eq(parser.collect().length(), 3)
}

///|
test "parser attaches list source ranges" {
  let events = @markdown.Processor::commonmark()
    .parse("- one\n  continued\n- two")
    .collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:list")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 23)
        }
        None => abort("expected list range")
      }
    _ => abort("expected list enter")
  }
  match events[1] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:item")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 17)
        }
        None => abort("expected item range")
      }
    _ => abort("expected item enter")
  }
}

///|
test "parser attaches loose list source ranges across blank continuation" {
  let events = @markdown.Processor::commonmark()
    .parse("- one\n\n  two\n- three")
    .collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:list")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 20)
        }
        None => abort("expected loose list range")
      }
    _ => abort("expected list enter")
  }
  match events[1] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:item")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 12)
        }
        None => abort("expected loose item range")
      }
    _ => abort("expected item enter")
  }
}

///|
test "parser attaches blockquote source ranges" {
  let events = @markdown.Processor::commonmark()
    .parse("> quote\n> more\n\ntext")
    .collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:block_quote")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 14)
        }
        None => abort("expected blockquote range")
      }
    _ => abort("expected blockquote enter")
  }
}

///|
test "parser attaches fenced code source ranges" {
  let events = @markdown.Processor::commonmark()
    .parse("```\ncode\n```\n\ntext")
    .collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:code_block")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 12)
        }
        None => abort("expected fenced code range")
      }
    _ => abort("expected fenced code enter")
  }
}

///|
test "parser attaches unclosed fenced code source ranges" {
  let events = @markdown.Processor::commonmark().parse("```\ncode").collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:code_block")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 8)
        }
        None => abort("expected unclosed fence range")
      }
    _ => abort("expected fenced code enter")
  }
}

///|
test "parser attaches indented code source ranges" {
  let events = @markdown.Processor::commonmark()
    .parse("    code\n\ntext")
    .collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:code_block")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 8)
        }
        None => abort("expected indented code range")
      }
    _ => abort("expected indented code enter")
  }
}

///|
test "four space indented blockquote marker is code" {
  let events = @markdown.Processor::commonmark().parse("    > quote").collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:code_block")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 11)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented heading marker is code" {
  let events = @markdown.Processor::commonmark().parse("    # foo").collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:code_block")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 9)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented thematic break marker is code" {
  let events = @markdown.Processor::commonmark().parse("    ***").collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:code_block")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 7)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented setext underline stays paragraph" {
  let events = @markdown.Processor::commonmark().parse("Foo\n    ---").collect()
  match events[0] {
    Enter(el) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected paragraph")
  }
}

///|
test "four space indented fence does not interrupt paragraph" {
  let events = @markdown.Processor::commonmark().parse("foo\n    ```").collect()
  match events[0] {
    Enter(el) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected paragraph")
  }
}

///|
test "four space indented html block marker is code" {
  let events = @markdown.Processor::commonmark().parse("    <div>").collect()
  match events[0] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:code_block")
          assert_eq(range.start(), 0)
          assert_eq(range.end(), 9)
        }
        None => abort("expected code range")
      }
    _ => abort("expected code block")
  }
}

///|
test "four space indented list marker does not interrupt paragraph" {
  let events = @markdown.Processor::commonmark()
    .parse("paragraph\n    - item")
    .collect()
  match events[0] {
    Enter(el) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected paragraph")
  }
  for event in events {
    match event {
      Enter(el) =>
        if el.tag().to_string() == "cm:list" {
          abort("did not expect list")
        }
      _ => ()
    }
  }
}

///|
test "parser attaches thematic break source ranges" {
  let events = @markdown.Processor::commonmark().parse("text\n\n---").collect()
  match events[3] {
    Enter(el) =>
      match el.range() {
        Some(range) => {
          assert_eq(el.tag().to_string(), "cm:thematic_break")
          assert_eq(range.start(), 6)
          assert_eq(range.end(), 9)
        }
        None => abort("expected thematic break range")
      }
    _ => abort("expected thematic break enter")
  }
}

///|
test "parser normalizes image alt text" {
  let events = @markdown.Processor::commonmark()
    .parse("![a\\*b &amp; c](/img.png)")
    .collect()
  match events[1] {
    Enter(el) => {
      assert_eq(el.tag().to_string(), "cm:image")
      assert_eq(el.attrs().length(), 2)
      assert_eq(el.attrs()[1].name().to_string(), "alt")
      assert_eq(el.attrs()[1].value(), "a*b & c")
    }
    _ => abort("expected image enter")
  }
}

///|
test "parser flattens image alt inline markup" {
  let events = @markdown.Processor::commonmark()
    .parse("![*em* **strong** `code`](/img.png)")
    .collect()
  match events[1] {
    Enter(el) => {
      assert_eq(el.tag().to_string(), "cm:image")
      assert_eq(el.attrs()[1].name().to_string(), "alt")
      assert_eq(el.attrs()[1].value(), "em strong code")
    }
    _ => abort("expected image enter")
  }
}

///|
test "parser normalizes link destination and title attributes" {
  let events = @markdown.Processor::commonmark()
    .parse("[link](/a\\*b?x=&amp; \"a\\*b &amp; c\")")
    .collect()
  match events[1] {
    Enter(el) => {
      assert_eq(el.tag().to_string(), "cm:link")
      assert_eq(el.attrs().length(), 2)
      assert_eq(el.attrs()[0].value(), "/a*b?x=&")
      assert_eq(el.attrs()[1].value(), "a*b & c")
    }
    _ => abort("expected link enter")
  }
}

///|
test "html renderer escapes text and attribute values" {
  let html = @markdown.HtmlRenderer::new().render([
    Enter(
      @markdown.element_with_attrs(@markdown.Tag::raw("x:<tag>"), [
        @markdown.attr(@markdown.AttrName::raw("data<&>"), "\"<&>"),
      ]),
    ),
    Text("<&>\""),
    Exit(@markdown.Tag::raw("x:<tag>")),
  ])
  assert_eq(
    html, "<x:&lt;tag&gt; data&lt;&amp;&gt;=\"&quot;&lt;&amp;&gt;\">&lt;&amp;&gt;&quot;</x:&lt;tag&gt;>",
  )
}

///|
test "html renderer preserves raw html events" {
  let html = @markdown.HtmlRenderer::new().render([
    Text("<"),
    Html("<span>raw</span>"),
    Text(">"),
  ])
  assert_eq(html, "&lt;<span>raw</span>&gt;")
}

///|
test "html renderer preserves extension attrs on standard tags" {
  let events : Array[@markdown.Event] = [
    Enter(
      @markdown.element_with_attrs(@markdown.Tag::raw("cm:paragraph"), [
        @markdown.attr(@markdown.AttrName::raw("class"), "lead"),
      ]),
    ),
    Enter(
      @markdown.element_with_attrs(@markdown.Tag::raw("cm:link"), [
        @markdown.attr(@markdown.AttrName::raw("destination"), "/url"),
        @markdown.attr(@markdown.AttrName::raw("title"), "Title"),
        @markdown.attr(@markdown.AttrName::raw("data-kind"), "xref"),
      ]),
    ),
    Text("link"),
    Exit(@markdown.Tag::raw("cm:link")),
    Exit(@markdown.Tag::raw("cm:paragraph")),
  ]
  assert_eq(
    @markdown.HtmlRenderer::new().render(events),
    "<p class=\"lead\"><a href=\"/url\" title=\"Title\" data-kind=\"xref\">link</a></p>\n",
  )
}

///|
test "html renderer preserves extension attrs on standard void tags" {
  let events : Array[@markdown.Event] = [
    Enter(
      @markdown.element_with_attrs(@markdown.Tag::raw("cm:image"), [
        @markdown.attr(@markdown.AttrName::raw("destination"), "/img.png"),
        @markdown.attr(@markdown.AttrName::raw("alt"), "alt"),
        @markdown.attr(@markdown.AttrName::raw("data-size"), "small"),
      ]),
    ),
    Exit(@markdown.Tag::raw("cm:image")),
    Enter(
      @markdown.element_with_attrs(@markdown.Tag::raw("cm:thematic_break"), [
        @markdown.attr(@markdown.AttrName::raw("class"), "cut"),
      ]),
    ),
    Exit(@markdown.Tag::raw("cm:thematic_break")),
  ]
  assert_eq(
    @markdown.HtmlRenderer::new().render(events),
    "<img src=\"/img.png\" alt=\"alt\" data-size=\"small\" /><hr class=\"cut\" />\n",
  )
}

///|
test "event transform and ast conversion keep extension tags" {
  let events : Array[@markdown.Event] = [
    Enter(@markdown.element(@markdown.Tag::raw("x:note"))),
    Text("a"),
    Text("b"),
    Exit(@markdown.Tag::raw("x:note")),
  ]
  let transformed = @markdown.Transform::new(events)
    .text_merge()
    .inject_attr(
      @markdown.Tag::raw("x:note"),
      @markdown.attr(@markdown.AttrName::raw("role"), "note"),
    )
    .collect()
  let root = @markdown.AstBuilder::new().build(transformed)
  match root {
    Ok(node) => {
      assert_eq(node.children().length(), 1)
      match node.children()[0].element() {
        Some(el) => {
          assert_eq(el.tag().to_string(), "x:note")
          assert_eq(el.attrs().length(), 1)
        }
        None => abort("expected element")
      }
      assert_eq(node.children()[0].children()[0].text(), "ab")
    }
    Err(_) => abort("expected ast")
  }
}

///|
test "transform keeps event arrays isolated" {
  let events : Array[@markdown.Event] = [Text("a"), Text("b")]
  let transform = @markdown.Transform::new(events)
  ignore(events.pop())
  assert_eq(transform.collect().length(), 2)
  let collected = transform.collect()
  ignore(collected.pop())
  assert_eq(transform.collect().length(), 2)
}

///|
test "ast builder preserves extension attributes" {
  let result = @markdown.AstBuilder::new().build([
    Enter(
      @markdown.element_with_attrs(@markdown.Tag::raw("x:note"), [
        @markdown.attr(@markdown.AttrName::raw("kind"), "tip"),
        @markdown.attr(@markdown.AttrName::raw("data-id"), "42"),
      ]),
    ),
    Text("body"),
    Exit(@markdown.Tag::raw("x:note")),
  ])
  match result {
    Ok(root) =>
      match root.children()[0].element() {
        Some(el) => {
          assert_eq(el.tag().to_string(), "x:note")
          assert_eq(el.attrs().length(), 2)
          assert_eq(el.attrs()[0].name().to_string(), "kind")
          assert_eq(el.attrs()[0].value(), "tip")
          assert_eq(el.attrs()[1].name().to_string(), "data-id")
          assert_eq(el.attrs()[1].value(), "42")
        }
        None => abort("expected element")
      }
    Err(_) => abort("expected ast")
  }
}

///|
test "ast builder preserves element source range" {
  let range = @markdown.SourceRange::new(2, 9)
  let result = @markdown.AstBuilder::new().build([
    Enter(
      @markdown.element_with_attrs(
        @markdown.Tag::raw("x:note"),
        [],
        range=Some(range),
      ),
    ),
    Text("body"),
    Exit(@markdown.Tag::raw("x:note")),
  ])
  match result {
    Ok(root) => {
      match root.children()[0].range() {
        Some(r) => {
          assert_eq(r.start(), 2)
          assert_eq(r.end(), 9)
        }
        None => abort("expected ast node range")
      }
      match root.children()[0].element() {
        Some(el) =>
          match el.range() {
            Some(r) => {
              assert_eq(r.start(), 2)
              assert_eq(r.end(), 9)
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
test "ast node children accessor does not expose internal arrays" {
  let result = @markdown.to_ast(@markdown.parse("hello"))
  match result {
    Ok(root) => {
      let children = root.children()
      assert_eq(children.length(), 1)
      ignore(children.pop())
      assert_eq(root.children().length(), 1)
      assert_eq(root.children()[0].children().length(), 1)
      let paragraph_children = root.children()[0].children()
      ignore(paragraph_children.pop())
      assert_eq(root.children()[0].children().length(), 1)
    }
    Err(_) => abort("expected ast")
  }
}

///|
test "ast builder converts break and raw html events" {
  let result = @markdown.AstBuilder::new().build([
    Text("a"),
    SoftBreak,
    HardBreak,
    Html("<span>raw</span>"),
  ])
  match result {
    Ok(node) => {
      assert_eq(node.children().length(), 4)
      assert_eq(node.children()[0].text(), "a")
      assert_eq(node.children()[1].text(), "\n")
      match node.children()[2].element() {
        Some(el) => assert_eq(el.tag().to_string(), "cm:hard_break")
        None => abort("expected hard break element")
      }
      match node.children()[3].element() {
        Some(el) => assert_eq(el.tag().to_string(), "cm:html")
        None => abort("expected html element")
      }
      assert_eq(node.children()[3].children()[0].text(), "<span>raw</span>")
    }
    Err(_) => abort("expected ast")
  }
}

///|
test "transform preserves source range while renaming and injecting attrs" {
  let range = @markdown.SourceRange::new(1, 4)
  let events : Array[@markdown.Event] = [
    Enter(
      @markdown.element_with_attrs(
        @markdown.Tag::raw("x:old"),
        [],
        range=Some(range),
      ),
    ),
    Exit(@markdown.Tag::raw("x:old")),
  ]
  let transformed = @markdown.Transform::new(events)
    .rename_tag(@markdown.Tag::raw("x:old"), @markdown.Tag::raw("x:new"))
    .inject_attr(
      @markdown.Tag::raw("x:new"),
      @markdown.attr(@markdown.AttrName::raw("class"), "note"),
    )
    .collect()
  match transformed[0] {
    Enter(el) => {
      assert_eq(el.tag().to_string(), "x:new")
      assert_eq(el.attrs().length(), 1)
      match el.range() {
        Some(r) => {
          assert_eq(r.start(), 1)
          assert_eq(r.end(), 4)
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
      Enter(
        @markdown.element_with_attrs(@markdown.Tag::raw("x:note"), [
          @markdown.attr(@markdown.AttrName::raw("kind"), "tip"),
        ]),
      ),
      Exit(@markdown.Tag::raw("x:note")),
    ])
    .inject_attr(
      @markdown.Tag::raw("x:note"),
      @markdown.attr(@markdown.AttrName::raw("role"), "note"),
    )
    .collect()
  match transformed[0] {
    Enter(el) => {
      assert_eq(el.tag().to_string(), "x:note")
      assert_eq(el.attrs().length(), 2)
      assert_eq(el.attrs()[0].name().to_string(), "kind")
      assert_eq(el.attrs()[0].value(), "tip")
      assert_eq(el.attrs()[1].name().to_string(), "role")
      assert_eq(el.attrs()[1].value(), "note")
    }
    _ => abort("expected transformed enter")
  }
}

///|
test "transform text merge only merges adjacent text" {
  let transformed = @markdown.Transform::new([
      Text("a"),
      Text("b"),
      SoftBreak,
      Text("c"),
      Text("d"),
    ])
    .text_merge()
    .collect()
  assert_eq(transformed.length(), 3)
  match transformed[0] {
    Text(text) => assert_eq(text, "ab")
    _ => abort("expected merged first text")
  }
  match transformed[2] {
    Text(text) => assert_eq(text, "cd")
    _ => abort("expected merged second text")
  }
}

///|
test "transform preserves event order and unknown tags" {
  let events : Array[@markdown.Event] = [
    Enter(@markdown.element(@markdown.Tag::raw("x:unknown"))),
    Text("a"),
    SoftBreak,
    Text("b"),
    Exit(@markdown.Tag::raw("x:unknown")),
  ]
  let transformed = @markdown.Transform::new(events)
    .softbreak_to_hardbreak()
    .collect()
  match transformed[0] {
    Enter(el) => assert_eq(el.tag().to_string(), "x:unknown")
    _ => abort("expected unknown enter")
  }
  match transformed[1] {
    Text(text) => assert_eq(text, "a")
    _ => abort("expected first text")
  }
  match transformed[2] {
    HardBreak => ()
    _ => abort("expected hard break")
  }
  match transformed[4] {
    Exit(tag) => assert_eq(tag.to_string(), "x:unknown")
    _ => abort("expected unknown exit")
  }
}

///|
test "ast builder rejects invalid event stream" {
  let result = @markdown.AstBuilder::new().build([
    Exit(@markdown.Tag::raw("x:missing")),
  ])
  match result {
    Err(UnexpectedExit(tag)) => assert_eq(tag.to_string(), "x:missing")
    _ => abort("expected ast error")
  }
}

///|
test "ast builder rejects mismatched closing tag" {
  let result = @markdown.AstBuilder::new().build([
    Enter(@markdown.element(@markdown.Tag::raw("x:open"))),
    Exit(@markdown.Tag::raw("x:other")),
  ])
  match result {
    Err(UnexpectedExit(tag)) => assert_eq(tag.to_string(), "x:other")
    _ => abort("expected mismatched tag error")
  }
}

///|
test "ast builder rejects unclosed tags" {
  let result = @markdown.AstBuilder::new().build([
    Enter(@markdown.element(@markdown.Tag::raw("x:open"))),
    Text("body"),
  ])
  match result {
    Err(UnclosedTag(tag)) => assert_eq(tag.to_string(), "x:open")
    _ => abort("expected unclosed tag error")
  }
}
