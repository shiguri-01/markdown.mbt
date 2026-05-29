///|
fn inline_result(
  sink : @markdown.Sink,
  consumed : Int,
  fragment : @markdown.EventFragment,
) -> @markdown.InlineRuleResult {
  fragment.emit_to(sink)
  Match(ConsumedChars(consumed))
}

///|
fn block_result(
  consumed : Int,
  fragment : @markdown.EventFragment,
) -> @markdown.BlockRuleResult {
  Match(ConsumedLines(consumed), fragment)
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
    render_html(@commonmark.rule().extend(blocker), "[x]\n\n[x]: /blocked\n"),
    "<p>[x]</p>\nblocked",
  )
}

///|
test "custom inline rules keep two pass reference behavior" {
  let marker = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    triggers="@",
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@") {
        inline_result(sink, 1, @markdown.EventFragment::text("marker"))
      } else {
        NoMatch
      }
    },
  )
  assert_eq(
    render_html(@commonmark.rule().extend(marker), "[x] @\n\n[x]: /url\n"),
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
    render_html(@commonmark.rule().extend(core), "[x]\n\n[x]: /url\n"),
    "<p><a href=\"/url\">x</a></p>\n",
  )
}

///|
test "inline nomatch cannot emit partial events" {
  let rule = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:nomatch"),
    priority=100,
    triggers="@",
    fn(_ctx, _sink) { NoMatch },
  )
  assert_eq(render_html(@commonmark.rule().extend(rule), "@"), "<p>@</p>\n")
}

///|
test "block nomatch cannot emit partial events" {
  let rule = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:nomatch"),
    priority=100,
    fn(_ctx) { NoMatch },
  )
  assert_eq(
    render_html(@commonmark.rule().extend(rule), "plain"),
    "<p>plain</p>\n",
  )
}

///|
test "matched inline emits fragment and consumes exact chars" {
  let rule = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    triggers="@",
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@@") {
        inline_result(
          sink,
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
    render_html(@commonmark.rule().extend(rule), "@@x"),
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
    render_html(@commonmark.rule().extend(rule), "!!! note\nnext"),
    "<x:admonition kind=\"note\"></x:admonition><p>next</p>\n",
  )
}

///|
test "delimiter rules run before inline rules and honor ordering" {
  let delimiter = @markdown.Rule::delimiter(
    @markdown.RuleName::raw("x:delimiter:first"),
    priority=0,
    triggers="^",
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("^") {
        inline_result(sink, 1, @markdown.EventFragment::text("delimiter"))
      } else {
        NoMatch
      }
    },
  )
  let inline = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:second"),
    priority=100,
    triggers="^",
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("^") {
        inline_result(sink, 1, @markdown.EventFragment::text("inline"))
      } else {
        NoMatch
      }
    },
  )
  let rule = @markdown.Rule("order").extend(inline).extend(delimiter)
  assert_eq(
    render_html(@commonmark.rule().extend(rule), "^"),
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
  assert_eq(render_html(@commonmark.rule().extend(rule), "%"), "continue")
}

///|
test "rule priority disable enable and replace remain intact" {
  let marker = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    triggers="@",
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@") {
        inline_result(sink, 1, @markdown.EventFragment::text("marker"))
      } else {
        NoMatch
      }
    },
  )
  let disabled = @markdown.Rule("config")
    .extend(marker)
    .disable(@markdown.RuleName::raw("x:inline:marker"))
  assert_eq(render_html(@commonmark.rule().extend(disabled), "@"), "<p>@</p>\n")
  let enabled = @markdown.Rule("config")
    .extend(marker)
    .disable(@markdown.RuleName::raw("x:inline:marker"))
    .enable(@markdown.RuleName::raw("x:inline:marker"))
  assert_eq(
    render_html(@commonmark.rule().extend(enabled), "@"),
    "<p>marker</p>\n",
  )
  let replacement = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:marker"),
    priority=100,
    triggers="@",
    fn(ctx, sink) {
      if ctx.scanner().has_prefix("@") {
        inline_result(sink, 1, @markdown.EventFragment::text("replacement"))
      } else {
        NoMatch
      }
    },
  )
  let replaced = @markdown.Rule("config").extend(marker).replace(replacement)
  assert_eq(
    render_html(@commonmark.rule().extend(replaced), "@"),
    "<p>replacement</p>\n",
  )
}
