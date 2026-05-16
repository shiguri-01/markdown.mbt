# shiguri/markdown

An event-driven Markdown parser for MoonBit. The main API pushes Markdown
events into downstream sinks, with HTML rendering, event transforms, and AST
building provided as downstream helpers.

## Design Contract

This package is built around a small, stable event pipeline:

1. `Processor` owns Markdown parsing configuration and pushes `Event` values
   into an `EventSink`.
2. `parse_into(source, sink)` is the core pipeline API.
3. `EventBuffer`, `HtmlBuffer`, `AstBuffer`, and sink transforms are downstream
   consumers. They do not belong to `Processor`, so output formats stay
   downstream of parsing.
4. Extensions are ordinary `Plugin` values that register named `Rule` values.
   Plugin builders and processor builders return new values and leave the
   original value unchanged.
5. Public constructors and accessors copy mutable arrays at API boundaries.
   Callers can mutate returned arrays without mutating parser-owned state.
   Use typed accessors such as `Element::attr` before falling back to raw array
   traversal.

Event streams use a tree-shaped contract. `Enter(element)` opens an element,
`Exit(tag)` closes the most recent open element with the same tag, and text,
break, and raw HTML events are leaves. `AstBuffer` validates this
contract and returns `UnexpectedExit`, `MismatchedExit`, or `UnclosedTag` for
unbalanced streams. `MismatchedExit(expected, actual)` reports the open tag
first and the close tag second. `HtmlBuffer` is a renderer for event streams;
callers that need validation should feed the same stream into `AstBuffer`.

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
  match events.get(0) {
    Some(Enter(el)) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected paragraph")
  }
  match events.get(1) {
    Some(Text(text)) => assert_eq(text, "hello")
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
        0
      } else {
        let mut end = 1
        while scanner.char_at_offset(end) != Some(36) &&
              ctx.offset() + end < ctx.source().length() {
          end = end + 1
        }
        if ctx.offset() + end >= ctx.source().length() {
          0
        } else {
          sink.emit(Enter(@markdown.Element::new(@markdown.Tag::raw("x:math"))))
          match scanner.slice(1, end) {
            Some(text) => {
              sink.emit(Text(text))
              sink.emit(Exit(@markdown.Tag::raw("x:math")))
              end + 1
            }
            None => 0
          }
        }
      }
    },
  )
  let html = @markdown.HtmlBuffer::new()
  @markdown.commonmark()
  .with_plugin(@markdown.Plugin::new("math").add(math))
  .parse_into("Euler: $x + y$", html.sink())
  assert_eq(html.to_string(), "<p>Euler: <x:math>x + y</x:math></p>\n")
}
```

```mbt check
///|
test {
  let no_raw_html = @markdown.Plugin::new("no-raw-html")
    .disable(@markdown.RuleName::commonmark("block:html"))
    .disable(@markdown.RuleName::commonmark("inline:raw_html"))
  let configured = @markdown.commonmark_plugin().with_plugin(no_raw_html)
  let html = @markdown.HtmlBuffer::new()
  @markdown.Processor::new()
  .with_plugin(configured)
  .parse_into("<span>raw</span>", html.sink())
  assert_eq(html.to_string(), "<p>&lt;span&gt;raw&lt;/span&gt;</p>\n")
}
```

## Sink Transforms and AST Helpers

```mbt check
///|
test {
  let ast = @markdown.AstBuffer::new()
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
