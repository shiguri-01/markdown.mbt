# shiguri/markdown

An event-driven Markdown parser for MoonBit. The main API pushes Markdown
events into downstream sinks, with HTML rendering, event transforms, and AST
building provided as downstream helpers.

## Design Contract

This package is built around a small, stable event pipeline:

1. `Processor` owns Markdown parsing configuration and pushes `Event` values
   into an `EventSink`.
2. `parse_into(source, sink)` is the core pipeline API. `parse(source)` is a
   convenience that collects the same event stream into an array.
3. `Transform`, `HtmlRenderer`, and `AstBuilder` consume event streams. They do
   not belong to `Processor`, so output formats stay downstream of parsing.
4. Extensions are ordinary `Plugin` values that register named `Rule` values.
   Plugin builders and processor builders return new values and leave the
   original value unchanged.
5. Public constructors and accessors copy mutable arrays at API boundaries.
   Callers can mutate returned arrays without mutating parser-owned state.
   Use typed accessors such as `Element::attr` before falling back to raw array
   traversal.

Event streams use a tree-shaped contract. `Enter(element)` opens an element,
`Exit(tag)` closes the most recent open element with the same tag, and text,
break, and raw HTML events are leaves. `AstBuilder::build` validates this
contract and returns `UnexpectedExit`, `MismatchedExit`, or `UnclosedTag` for
unbalanced streams. `MismatchedExit(expected, actual)` reports the open tag
first and the close tag second. `HtmlRenderer` is a renderer for event streams;
callers that need validation should run `to_ast(events)` before rendering.

Rule functions return the amount of input they consumed. Returning `0` means the
rule did not match and lets later rules try the same source position. Positive
values mean the rule matched and emitted any events it owns. Rule names and tags
use `cm:` for built-in CommonMark behavior and custom namespaces such as `x:`
for extensions.

## Parse CommonMark to HTML

```mbt check
///|
test {
  let html = @markdown.HtmlBuffer::new()
  @markdown.parse_into("# Hello *MoonBit*", html.sink())
  assert_eq(html.to_string(), "<h1>Hello <em>MoonBit</em></h1>\n")
}
```

## Push Events

```mbt check
///|
test {
  let buffer = @markdown.EventBuffer::new()
  @markdown.Processor::commonmark().parse_into("hello", buffer.sink())
  let events = buffer.collect()
  match events[0] {
    Enter(el) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected paragraph")
  }
  match events[1] {
    Text(text) => assert_eq(text, "hello")
    _ => abort("expected text")
  }
}
```

## Add an Inline Extension

Extensions use the same `Plugin` and `Rule` mechanism as the built-in
CommonMark syntax. Plugins are composable, so larger presets can be built from
smaller syntax plugins. Rule functions receive a context, scanner, and event
sink.

```mbt check
///|
test {
  let math = @markdown.Rule::inline(
    @markdown.RuleName::raw("x:inline:math"),
    priority=100,
    fn(ctx, sink) {
      let scanner = ctx.scanner()
      if !scanner.has_prefix("$") {
        return 0
      }
      let mut end = 1
      while scanner.char_at_offset(end) != Some(36) &&
            ctx.offset() + end < ctx.source().length() {
        end = end + 1
      }
      if ctx.offset() + end >= ctx.source().length() {
        return 0
      }
      sink.emit(Enter(@markdown.Element::new(@markdown.Tag::raw("x:math"))))
      match scanner.slice(1, end) {
        Some(text) => sink.emit(Text(text))
        None => return 0
      }
      sink.emit(Exit(@markdown.Tag::raw("x:math")))
      end + 1
    },
  )
  let events = @markdown.commonmark()
    .with_plugin(@markdown.Plugin::new("math").add(math))
    .parse("Euler: $x + y$")
  let html = events |> @markdown.to_html
  assert_eq(html, "<p>Euler: <x:math>x + y</x:math></p>\n")
}
```

```mbt check
///|
test {
  let no_raw_html = @markdown.Plugin::new("no-raw-html")
    .disable(@markdown.RuleName::commonmark("block:html"))
    .disable(@markdown.RuleName::commonmark("inline:raw_html"))
  let configured = @markdown.commonmark_plugin().with_plugin(no_raw_html)
  let events = @markdown.Processor::new()
    .with_plugin(configured)
    .parse("<span>raw</span>")
  let html = events |> @markdown.to_html
  assert_eq(html, "<p>&lt;span&gt;raw&lt;/span&gt;</p>\n")
}
```

## Transform and AST Helpers

```mbt check
///|
test {
  let events : Array[@markdown.Event] = [
    Enter(@markdown.Element::new(@markdown.Tag::raw("x:note"))),
    Text("a"),
    Text("b"),
    Exit(@markdown.Tag::raw("x:note")),
  ]
  let transformed = @markdown.Transform::new(events).text_merge().collect()
  match @markdown.to_ast(transformed) {
    Ok(root) =>
      match root.children()[0].children()[0].text() {
        Some(text) => assert_eq(text, "ab")
        None => abort("expected text node")
      }
    Err(_) => abort("expected AST")
  }
}
```

```mbt check
///|
test {
  let ast = @markdown.AstBuffer::new()
  @markdown.parse_into("hello", ast.sink())
  match ast.result() {
    Ok(root) => assert_eq(root.children().length(), 1)
    Err(_) => abort("expected AST")
  }
}
```
