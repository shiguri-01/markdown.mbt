# username/markdown

An event-driven Markdown parser for MoonBit. The main API is a pull parser that
emits Markdown events, with HTML rendering, event transforms, and AST building
provided as downstream helpers.

## Parse CommonMark to HTML

```mbt check
///|
test {
  let html = @markdown.commonmark().parse("# Hello *MoonBit*").to_html()
  assert_eq(html, "<h1>Hello <em>MoonBit</em></h1>\n")
}
```

## Pull Events

```mbt check
///|
test {
  let parser = @markdown.ParserBuilder::commonmark().parse("hello")
  match parser.next() {
    Some(@markdown.Enter(el)) => assert_eq(el.tag, "cm:paragraph")
    _ => abort("expected paragraph")
  }
  match parser.next() {
    Some(@markdown.Text(text)) => assert_eq(text, "hello")
    _ => abort("expected text")
  }
}
```

## Add an Inline Extension

Extensions use the same `Plugin` and `Rule` mechanism as the built-in
CommonMark syntax. Rule functions receive a context, scanner, and event sink.

```mbt check
///|
test {
  let math = @markdown.Rule::inline("x:inline:math", priority=100, fn(
    ctx,
    sink,
  ) {
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
    sink.emit(@markdown.Enter(@markdown.element("x:math")))
    sink.emit(@markdown.Text(scanner.slice(1, end)))
    sink.emit(@markdown.Exit("x:math"))
    end + 1
  })
  let html = @markdown.commonmark()
    .use(@markdown.Plugin::new("math").add(math))
    .parse("Euler: $x + y$")
    .to_html()
  assert_eq(html, "<p>Euler: <x:math>x + y</x:math></p>\n")
}
```

## Transform and AST Helpers

```mbt check
///|
test {
  let events = [
    @markdown.Enter(@markdown.element("x:note")),
    @markdown.Text("a"),
    @markdown.Text("b"),
    @markdown.Exit("x:note"),
  ]
  let transformed = @markdown.Transform::new(events).text_merge().collect()
  match @markdown.AstBuilder::new().build(transformed) {
    Ok(root) => assert_eq(root.children[0].children[0].text, "ab")
    Err(_) => abort("expected AST")
  }
}
```
