# shiguri/markdown

An event-driven Markdown parser for MoonBit.

The core idea is simple: Markdown parsing produces `Event` values, and every
output format is a `Sink`. `Processor` owns the syntax rules, `parse` pushes
events into a sink, and renderers, AST builders, collectors, and transforms all
compose downstream.

For common tasks, use the two shortcuts:

```mbt check
///|
test {
  assert_eq(
    @markdown.to_html("# Hello *MoonBit*"),
    "<h1>Hello <em>MoonBit</em></h1>\n",
  )
}
```

```mbt check
///|
test {
  match @markdown.to_ast("hello") {
    Ok(root) => assert_eq(root.children().length(), 1)
    Err(_) => abort("expected AST")
  }
}
```

For everything else, build a processor and choose a sink:

```mbt check
///|
test {
  let html = @markdown.Html::new()
  @markdown.Processor::new().parse("# Hello", html.sink())
  assert_eq(html.to_string(), "<h1>Hello</h1>\n")
}
```

```mbt check
///|
test {
  let events = @markdown.Events::new()
  @markdown.Processor::new().parse("hello", events.sink())
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

```mbt check
///|
test {
  let math = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:math"),
    priority=100,
    fn(ctx) {
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
            Some(text) =>
              match @markdown.ConsumedChars::new(end + 1) {
                Some(chars) =>
                  Match(
                    chars,
                    @markdown.EventFragment::element(
                      @markdown.Element::new(@markdown.Tag::raw("x:math")),
                      children=[@markdown.EventFragment::text(text)],
                    ),
                  )
                None => NoMatch
              }
            None => NoMatch
          }
        }
      }
    },
  )

  let html = @markdown.Html::new()
  let rule = @markdown.commonmark().extend(math)
  @markdown.Processor::new(rule~).parse("Euler: $x + y$", html.sink())
  assert_eq(html.to_string(), "<p>Euler: <x:math>x + y</x:math></p>\n")
}
```

```mbt check
///|
test {
  let no_raw_html = @markdown.Rule::new("no-raw-html")
    .disable(@markdown.RuleName::commonmark("block:html"))
    .disable(@markdown.RuleName::commonmark("inline:raw_html"))

  let html = @markdown.Html::new()
  let rule = @markdown.commonmark().extend(no_raw_html)
  @markdown.Processor::new(rule~).parse("<span>raw</span>", html.sink())
  assert_eq(html.to_string(), "<p>&lt;span&gt;raw&lt;/span&gt;</p>\n")
}
```

## Sinks

`Sink` is the only downstream contract. You can create one directly, use the
built-in sinks, or transform an existing sink.

```mbt check
///|
test {
  let ast = @markdown.Ast::new()
  let sink = ast.sink().text_merge()
  sink.emit(Enter(@markdown.Element::new(@markdown.Tag::raw("x:note"))))
  sink.emit(Text("a"))
  sink.emit(Text("b"))
  sink.emit(Exit(@markdown.Tag::raw("x:note")))
  sink.finish()

  match ast.result() {
    Ok(root) =>
      match root.children().get(0) {
        Some(note) =>
          match note.children().get(0) {
            Some(child) =>
              match child.text() {
                Some(text) => assert_eq(text, "ab")
                None => abort("expected text node")
              }
            None => abort("expected child node")
          }
        None => abort("expected note node")
      }
    Err(_) => abort("expected AST")
  }
}
```

Event streams are tree-shaped. `Enter(element)` opens an element, `Exit(tag)`
closes the most recent open element with the same tag, and text, breaks, and raw
HTML events are leaves. `Ast` validates that contract. `Html` renders the stream
as it arrives.
