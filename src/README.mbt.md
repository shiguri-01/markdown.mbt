# shiguri/markdown

An event-driven Markdown parser for MoonBit.

The core idea is simple: Markdown parsing produces `Event` values, and every
output format is a `Sink`. `Processor` owns the syntax rules, `parse` pushes
events into a sink, and renderers, AST builders, collectors, and transforms all
compose downstream.

Use the CommonMark rule with the sink for the output you want:

```mbt check
///|
test {
  let html = @markdown.Html(@commonmark.html_renderers())
  @markdown.Processor(@commonmark.rule()).parse(
    "# Hello *MoonBit*",
    html.sink(),
  )
  assert_eq(html.to_string(), "<h1>Hello <em>MoonBit</em></h1>\n")
}
```

```mbt check
///|
test {
  let ast = @markdown.Ast()
  @markdown.Processor(@commonmark.rule()).parse("hello", ast.sink())
  let root = ast.result()
  assert_eq(
    root.to_json().stringify(),
    (
      #|{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","value":"hello"}]}]}
    ),
  )
}
```

You can also keep a processor and reuse it:

```mbt check
///|
test {
  let html = @markdown.Html(@commonmark.html_renderers())
  @markdown.Processor(@commonmark.rule()).parse("# Hello", html.sink())
  assert_eq(html.to_string(), "<h1>Hello</h1>\n")
}
```

```mbt check
///|
test {
  let events = @markdown.Events()
  @markdown.Processor(@commonmark.rule()).parse("hello", events.sink())
  match events.collect().get(1) {
    Some(Text(text)) => assert_eq(text, "hello")
    _ => abort("expected text")
  }
}
```

## Extensions

Rules are composable syntax definitions. A rule can register parser entries or
apply controls such as `disable`, `enable`, and `replace`. Processors and rules
are immutable builders: each method returns a new value.

Syntax extensions and HTML renderers are configured separately. For example,
GFM tables and strikethrough emit GFM event tags, and `@gfm.html_renderers()`
provides CommonMark plus GFM renderers.

```mbt check
///|
test {
  let rule = @gfm.rule()
  let html = @markdown.Html(@gfm.html_renderers())
  @markdown.Processor(rule).parse("~~done~~", html.sink())
  assert_eq(html.to_string(), "<p><del>done</del></p>\n")
}
```

```mbt check
///|
test {
  let math = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:math"),
    priority=100,
    triggers="$",
    fn(ctx, sink) {
      let scanner = ctx.scanner()
      if !scanner.has_prefix("$") {
        NoMatch
      } else {
        let mut end = 1
        while scanner.char_at_offset(end) != Some(36) &&
              ctx.offset() + end < ctx.source().length() {
          end = end + 1
        }
        if ctx.offset() + end >= ctx.source().length() {
          NoMatch
        } else {
          match scanner.slice(1, end) {
            Some(text) => {
              @markdown.EventFragment::element(
                Element(@markdown.Tag::raw("x:math")),
                children=[@markdown.EventFragment::text(text)],
              ).emit_to(sink)
              Match(ConsumedChars(end + 1))
            }
            None => NoMatch
          }
        }
      }
    },
  )

  let html = @markdown.Html(@commonmark.html_renderers())
  let rule = @commonmark.rule().extend(math)
  @markdown.Processor(rule).parse("Euler: $x + y$", html.sink())
  assert_eq(html.to_string(), "<p>Euler: <x:math>x + y</x:math></p>\n")
}
```

```mbt check
///|
test {
  let no_raw_html = @markdown.Rule("no-raw-html")
    .disable(@markdown.RuleName::commonmark("block:html"))
    .disable(@markdown.RuleName::commonmark("inline:raw_html"))

  let html = @markdown.Html(@commonmark.html_renderers())
  let rule = @commonmark.rule().extend(no_raw_html)
  @markdown.Processor(rule).parse("<span>raw</span>", html.sink())
  assert_eq(html.to_string(), "<p>&lt;span&gt;raw&lt;/span&gt;</p>\n")
}
```

## Sinks

`Sink` is the only downstream contract. You can create one directly, use the
built-in sinks, or transform an existing sink.

```mbt check
///|
test {
  let ast = @markdown.Ast()
  let sink = ast.sink().text_merge()
  sink.emit(Enter(Element(@markdown.Tag::raw("x:note"))))
  sink.emit(Text("a"))
  sink.emit(Text("b"))
  sink.emit(Exit(@markdown.Tag::raw("x:note")))
  sink.finish()

  let root = ast.result()
  assert_eq(
    root.to_json().stringify(),
    (
      #|{"type":"root","children":[{"type":"mdastExtension","name":"x:note","attributes":{},"children":[{"type":"text","value":"ab"}]}]}
    ),
  )
}
```

Event streams are tree-shaped. `Enter(element)` opens an element, `Exit(tag)`
closes the most recent open element with the same tag, and text, breaks, and raw
HTML events are leaves. `Ast` validates that contract. `Html` renders the stream
as it arrives.

## Development

Use `just` from the Nix development shell:

```bash
nix develop
just
```

```bash
just check # all MoonBit modules
just fmt   # all MoonBit modules
just test  # library tests
just verify
just conformance
just bench
```
