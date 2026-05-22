///|
fn inline_result(
  consumed : Int,
  fragment : @markdown.EventFragment,
) -> @markdown.InlineRuleResult {
  Match(ConsumedChars(consumed), fragment)
}

///|
fn block_result(
  consumed : Int,
  fragment : @markdown.EventFragment,
) -> @markdown.BlockRuleResult {
  Match(ConsumedLines(consumed), fragment)
}

///|
test "commonmark block and inline html rendering" {
  let html = render_html(
    @markdown.commonmark(),
    "## Hello *MoonBit*\n\n- one\n- two",
  )
  assert_eq(
    html, "<h2>Hello <em>MoonBit</em></h2>\n<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n",
  )
}

///|
test "commonmark inline text keeps ordinary spaces together" {
  let events = @markdown.Events()
  @markdown.Processor().parse("hello world from moonbit", events.sink())
  let collected = events.collect()
  assert_eq(collected.length(), 3)
  match collected[1] {
    Text(text) => assert_eq(text, "hello world from moonbit")
    _ => abort("expected text")
  }
}

///|
test "commonmark inline text keeps long ordinary space runs together" {
  let spaces = StringBuilder::new(size_hint=128)
  for _ in 0..<128 {
    spaces.write_string(" ")
  }
  let events = @markdown.Events()
  @markdown.Processor().parse(
    "hello" + spaces.to_string() + "*world*",
    events.sink(),
  )
  let collected = events.collect()
  assert_eq(collected.length(), 6)
  match collected[1] {
    Text(text) => assert_eq(text, "hello" + spaces.to_string())
    _ => abort("expected leading text")
  }
  match collected[3] {
    Text(text) => assert_eq(text, "world")
    _ => abort("expected emphasis text")
  }
}

///|
test "commonmark list item ast has no renderer-only block attribute" {
  match @markdown.ast("- one\n\n- two\n") {
    Ok(root) => {
      let lists = root.children()
      assert_eq(lists.length(), 1)
      let items = lists[0].children()
      assert_eq(items.length(), 2)
      for item in items {
        match item.element() {
          Some(el) => {
            assert_eq(el.tag().to_string(), "cm:item")
            assert_true(el.attr(@markdown.AttrName::raw("block")) is None)
          }
          None => abort("expected list item element")
        }
      }
    }
    Err(_) => abort("expected ast")
  }
}

///|
fn repeated_paragraphs(count : Int) -> String {
  let out = StringBuilder::new()
  for i in 0..<count {
    out.write_string("padding line ")
    out.write_string(i.to_string())
    out.write_string("\n\n")
  }
  out.to_string()
}

///|
test "canonical parser path is independent of input size" {
  let sample =
    #|# Title
    #|
    #|> quote with [ref]
    #|
    #|- item
    #|- second
    #|
    #|```txt
    #|[ref]: /not-a-definition
    #|```
    #|
    #|[ref]: /url "title"
    #|
  let small = sample + "[ref]\n"
  let large = sample + repeated_paragraphs(900) + "[ref]\n"
  let small_html = render_html(@markdown.commonmark(), small)
  let large_html = render_html(@markdown.commonmark(), large)
  assert_true(
    small_html.has_suffix("<p><a href=\"/url\" title=\"title\">ref</a></p>\n"),
  )
  assert_true(
    large_html.has_suffix("<p><a href=\"/url\" title=\"title\">ref</a></p>\n"),
  )
}

///|
test "reference links resolve forward and ignore code definitions" {
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "[x]\n\n```md\n[x]: /code\n```\n\n[x]: /real\n",
    ),
    "<p><a href=\"/real\">x</a></p>\n<pre><code class=\"language-md\">[x]: /code\n</code></pre>\n",
  )
}

///|
test "deferred commonmark path resolves nested definitions after block parse" {
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "[t]\n\n[b]\n\n[l]\n\n[i]\n\n[h]\n\n[t]: /top\n\n    [i]: /code\n\n<div>\n[h]: /html\n</div>\n\n> [b]: /quote\n> [b]\n\n- [l]: /list\n- [l]\n",
    ),
    "<p><a href=\"/top\">t</a></p>\n<p><a href=\"/quote\">b</a></p>\n<p><a href=\"/list\">l</a></p>\n<p>[i]</p>\n<p>[h]</p>\n<pre><code>[i]: /code\n</code></pre>\n<div>\n[h]: /html\n</div>\n<blockquote>\n<p><a href=\"/quote\">b</a></p>\n</blockquote>\n<ul>\n<li></li>\n<li><a href=\"/list\">l</a></li>\n</ul>\n",
  )
}

///|
test "reference definitions in block quotes and lists do not emit" {
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "[l]\n\n> [b]: /b\n> [b]\n\n- [l]: /l\n- [l]\n",
    ),
    "<p><a href=\"/l\">l</a></p>\n<blockquote>\n<p><a href=\"/b\">b</a></p>\n</blockquote>\n<ul>\n<li></li>\n<li><a href=\"/l\">l</a></li>\n</ul>\n",
  )
}

///|
test "multiline reference labels resolve forward references" {
  assert_eq(
    render_html(@markdown.commonmark(), "[foo bar]\n\n[foo\nbar]: /url\n"),
    "<p><a href=\"/url\">foo bar</a></p>\n",
  )
}

///|
test "block quotes preserve lazy nested and reference content" {
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "> lazy\ncontinuation\n\n> > nested\n\n> [q]: /q\n> [q]\n",
    ),
    "<blockquote>\n<p>lazy\ncontinuation</p>\n</blockquote>\n<blockquote>\n<blockquote>\n<p>nested</p>\n</blockquote>\n</blockquote>\n<blockquote>\n<p><a href=\"/q\">q</a></p>\n</blockquote>\n",
  )
}

///|
test "lists preserve tight loose and normalized child blocks" {
  assert_eq(
    render_html(@markdown.commonmark(), "- tight\n  continuation\n- next\n"),
    "<ul>\n<li>tight\ncontinuation</li>\n<li>next</li>\n</ul>\n",
  )
  assert_eq(
    render_html(@markdown.commonmark(), "- loose\n\n  continuation\n"),
    "<ul>\n<li>\n<p>loose</p>\n<p>continuation</p>\n</li>\n</ul>\n",
  )
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "- > quoted\n- ```\n  [x]: /code\n  ```\n- [x]: /real\n- [x]\n",
    ),
    "<ul>\n<li>\n<blockquote>\n<p>quoted</p>\n</blockquote>\n</li>\n<li>\n<pre><code>[x]: /code\n</code></pre>\n</li>\n<li></li>\n<li><a href=\"/real\">x</a></li>\n</ul>\n",
  )
}

///|
test "custom block rules keep two pass reference behavior" {
  let blocker = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:block-reference"),
    priority=100,
    fn(ctx) {
      if ctx.current_line().has_prefix("[x]:") {
        block_result(1, @markdown.EventFragment::text("blocked"))
      } else {
        NoMatch
      }
    },
  )
  assert_eq(
    render_html(
      @markdown.commonmark().extend(blocker),
      "[x]\n\n[x]: /blocked\n",
    ),
    "<p>[x]</p>\nblocked",
  )
}

///|
test "custom inline rules keep two pass reference behavior" {
  let marker = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    fn(ctx) {
      if ctx.scanner().has_prefix("@") {
        inline_result(1, @markdown.EventFragment::text("marker"))
      } else {
        NoMatch
      }
    },
  )
  assert_eq(
    render_html(@markdown.commonmark().extend(marker), "[x] @\n\n[x]: /url\n"),
    "<p><a href=\"/url\">x</a> marker</p>\n",
  )
}

///|
test "custom core rules keep two pass reference behavior" {
  let core = @markdown.Rule::core(@markdown.RuleName::raw("x:core:identity"), fn(
    sink,
  ) {
    sink
  })
  assert_eq(
    render_html(@markdown.commonmark().extend(core), "[x]\n\n[x]: /url\n"),
    "<p><a href=\"/url\">x</a></p>\n",
  )
}

///|
test "collapsed full and image references resolve without source rewriting" {
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "[full][label] and [collapsed][] and ![img][label]\n\n[label]: /url\n[collapsed]: /collapsed\n",
    ),
    "<p><a href=\"/url\">full</a> and <a href=\"/collapsed\">collapsed</a> and <img src=\"/url\" alt=\"img\" /></p>\n",
  )
}

///|
test "reference definitions in code spans stay literal" {
  assert_eq(
    render_html(@markdown.commonmark(), "`[x]: /code` and [x]\n\n[x]: /real\n"),
    "<p><code>[x]: /code</code> and <a href=\"/real\">x</a></p>\n",
  )
}

///|
test "duplicate reference labels keep first definition" {
  assert_eq(
    render_html(@markdown.commonmark(), "[x]\n\n[x]: /first\n[x]: /second\n"),
    "<p><a href=\"/first\">x</a></p>\n",
  )
}

///|
test "normalized duplicate reference labels keep first definition" {
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "[foo bar]\n\n[Foo\tBar]: /first\n[foo bar]: /second\n",
    ),
    "<p><a href=\"/first\">foo bar</a></p>\n",
  )
}

///|
test "consumption wrappers expose positive values" {
  assert_eq(@markdown.ConsumedChars(2).to_int(), 2)
  assert_eq(@markdown.ConsumedLines(3).to_int(), 3)
}

///|
test "panic consumed chars must be positive" {
  ignore(@markdown.ConsumedChars(0))
}

///|
test "panic consumed lines must be positive" {
  ignore(@markdown.ConsumedLines(0))
}

///|
test "event fragment element is balanced" {
  let fragment = @markdown.EventFragment::element(
    Element(@markdown.Tag::raw("x:note")),
    children=[@markdown.EventFragment::text("body")],
  )
  let events = fragment.events()
  assert_eq(events.length(), 3)
  match events[0] {
    Enter(el) => assert_eq(el.tag().to_string(), "x:note")
    _ => abort("expected enter")
  }
  match events[1] {
    Text(text) => assert_eq(text, "body")
    _ => abort("expected text")
  }
  match events[2] {
    Exit(tag) => assert_eq(tag.to_string(), "x:note")
    _ => abort("expected exit")
  }
}

///|
test "event fragment rejects invalid event streams" {
  assert_true(
    @markdown.EventFragment::from_events([Exit(@markdown.Tag::raw("x:missing"))])
    is None,
  )
  assert_true(
    @markdown.EventFragment::from_events([
      Enter(Element(@markdown.Tag::raw("x:open"))),
      Exit(@markdown.Tag::raw("x:other")),
    ])
    is None,
  )
  assert_true(
    @markdown.EventFragment::from_events([
      Enter(Element(@markdown.Tag::raw("x:open"))),
      Text("body"),
    ])
    is None,
  )
}

///|
test "inline nomatch cannot emit partial events" {
  let rule = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:nomatch"),
    priority=100,
    fn(_ctx) { NoMatch },
  )
  assert_eq(render_html(@markdown.commonmark().extend(rule), "@"), "<p>@</p>\n")
}

///|
test "block nomatch cannot emit partial events" {
  let rule = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:nomatch"),
    priority=100,
    fn(_ctx) { NoMatch },
  )
  assert_eq(
    render_html(@markdown.commonmark().extend(rule), "plain"),
    "<p>plain</p>\n",
  )
}

///|
test "matched inline emits fragment and consumes exact chars" {
  let rule = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    fn(ctx) {
      if ctx.scanner().has_prefix("@@") {
        inline_result(
          2,
          @markdown.EventFragment::element(
            Element(@markdown.Tag::raw("x:marker")),
            children=[@markdown.EventFragment::text("marked")],
          ),
        )
      } else {
        NoMatch
      }
    },
  )
  assert_eq(
    render_html(@markdown.commonmark().extend(rule), "@@x"),
    "<p><x:marker>marked</x:marker>x</p>\n",
  )
}

///|
test "matched block emits fragment and consumes exact lines" {
  let rule = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:admonition"),
    priority=100,
    fn(ctx) {
      if ctx.current_line().has_prefix("!!! ") {
        block_result(
          1,
          @markdown.EventFragment::element(
            @markdown.Element::with_attrs(@markdown.Tag::raw("x:admonition"), [
              Attr(
                @markdown.AttrName::raw("kind"),
                ctx.current_line()[4:].to_owned(),
              ),
            ]),
          ),
        )
      } else {
        NoMatch
      }
    },
  )
  assert_eq(
    render_html(@markdown.commonmark().extend(rule), "!!! note\nnext"),
    "<x:admonition kind=\"note\"></x:admonition><p>next</p>\n",
  )
}

///|
test "delimiter rules run before inline rules and honor ordering" {
  let delimiter = @markdown.Rule::delimiter(
    @markdown.RuleName::raw("x:delimiter:first"),
    priority=0,
    fn(ctx) {
      if ctx.scanner().has_prefix("^") {
        inline_result(1, @markdown.EventFragment::text("delimiter"))
      } else {
        NoMatch
      }
    },
  )
  let inline = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:second"),
    priority=100,
    fn(ctx) {
      if ctx.scanner().has_prefix("^") {
        inline_result(1, @markdown.EventFragment::text("inline"))
      } else {
        NoMatch
      }
    },
  )
  let rule = @markdown.Rule("order").extend(inline).extend(delimiter)
  assert_eq(
    render_html(@markdown.commonmark().extend(rule), "^"),
    "<p>delimiter</p>\n",
  )
}

///|
test "block continue runs before block start" {
  let continuation = @markdown.Rule::block_continue(
    @markdown.RuleName::raw("x:block_continue:first"),
    priority=0,
    fn(ctx) {
      if ctx.current_line() == "%" {
        block_result(1, @markdown.EventFragment::text("continue"))
      } else {
        NoMatch
      }
    },
  )
  let start = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:start"),
    priority=100,
    fn(ctx) {
      if ctx.current_line() == "%" {
        block_result(1, @markdown.EventFragment::text("start"))
      } else {
        NoMatch
      }
    },
  )
  let rule = @markdown.Rule("block-continue").extend(start).extend(continuation)
  assert_eq(render_html(@markdown.commonmark().extend(rule), "%"), "continue")
}

///|
test "rule priority disable enable and replace remain intact" {
  let marker = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    fn(ctx) {
      if ctx.scanner().has_prefix("@") {
        inline_result(1, @markdown.EventFragment::text("marker"))
      } else {
        NoMatch
      }
    },
  )
  let disabled = @markdown.Rule("config")
    .extend(marker)
    .disable(@markdown.RuleName::raw("x:inline:marker"))
  assert_eq(
    render_html(@markdown.commonmark().extend(disabled), "@"),
    "<p>@</p>\n",
  )
  let enabled = @markdown.Rule("config")
    .extend(marker)
    .disable(@markdown.RuleName::raw("x:inline:marker"))
    .enable(@markdown.RuleName::raw("x:inline:marker"))
  assert_eq(
    render_html(@markdown.commonmark().extend(enabled), "@"),
    "<p>marker</p>\n",
  )
  let replacement = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    fn(ctx) {
      if ctx.scanner().has_prefix("@") {
        inline_result(1, @markdown.EventFragment::text("replacement"))
      } else {
        NoMatch
      }
    },
  )
  let replaced = @markdown.Rule("config").extend(marker).replace(replacement)
  assert_eq(
    render_html(@markdown.commonmark().extend(replaced), "@"),
    "<p>replacement</p>\n",
  )
}
