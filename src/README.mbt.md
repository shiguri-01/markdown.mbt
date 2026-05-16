# shiguri/markdown

An event-driven Markdown parser for MoonBit. The main API is a pull parser that
emits Markdown events, with HTML rendering, event transforms, and AST building
provided as downstream helpers.

## Design Contract

This package is built around a small, stable event pipeline:

1. `Processor` owns Markdown parsing configuration and produces `Event` values.
2. `Parser` is a pull view over an already-produced event stream.
3. `Transform`, `HtmlRenderer`, and `AstBuilder` consume event streams. They do
   not belong to `Processor`, so output formats stay downstream of parsing.
4. Extensions are ordinary `Plugin` values that register named `Rule` values.
   Plugin builders and processor builders return new values and leave the
   original value unchanged.
5. Public constructors and accessors copy mutable arrays at API boundaries.
   Callers can mutate returned arrays without mutating parser-owned state.

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
  let html = "# Hello *MoonBit*" |> @markdown.parse |> @markdown.to_html
  assert_eq(html, "<h1>Hello <em>MoonBit</em></h1>\n")
}
```

## Pull Events

```mbt check
///|
test {
  let parser = @markdown.Processor::commonmark().parse("hello")
  match parser.next() {
    Some(Enter(el)) => assert_eq(el.tag().to_string(), "cm:paragraph")
    _ => abort("expected paragraph")
  }
  match parser.next() {
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
      sink.emit(Enter(@markdown.element(@markdown.Tag::raw("x:math"))))
      sink.emit(Text(scanner.slice(1, end)))
      sink.emit(Exit(@markdown.Tag::raw("x:math")))
      end + 1
    },
  )
  let events = @markdown.commonmark()
    .with_plugin(@markdown.Plugin::new("math").add(math))
    .parse("Euler: $x + y$")
    .collect()
  let html = events |> @markdown.to_html
  assert_eq(html, "<p>Euler: <x:math>x + y</x:math></p>\n")
}
```

```mbt check
///|
test {
  let no_raw_html = @markdown.Plugin::new("no-raw-html")
    .disable(@markdown.RuleName::raw("cm:block:html"))
    .disable(@markdown.RuleName::raw("cm:inline:raw_html"))
  let configured = @markdown.commonmark_plugin().with_plugin(no_raw_html)
  let events = @markdown.Processor::new()
    .with_plugin(configured)
    .parse("<span>raw</span>")
    .collect()
  let html = events |> @markdown.to_html
  assert_eq(html, "<p>&lt;span&gt;raw&lt;/span&gt;</p>\n")
}
```

## Transform and AST Helpers

```mbt check
///|
test {
  let events : Array[@markdown.Event] = [
    Enter(@markdown.element(@markdown.Tag::raw("x:note"))),
    Text("a"),
    Text("b"),
    Exit(@markdown.Tag::raw("x:note")),
  ]
  let transformed = @markdown.Transform::new(events).text_merge().collect()
  match @markdown.to_ast(transformed) {
    Ok(root) => assert_eq(root.children()[0].children()[0].text(), "ab")
    Err(_) => abort("expected AST")
  }
}
```
