///|
test "public names attributes and source ranges are stable" {
  assert_eq(@markdown.Tag::commonmark("paragraph").to_string(), "cm:paragraph")
  assert_eq(@markdown.Tag::custom("x", "note").to_string(), "x:note")
  assert_eq(@markdown.Tag::raw("x:raw").to_string(), "x:raw")
  assert_eq(@markdown.AttrName::commonmark("level").to_string(), "level")
  assert_eq(@markdown.AttrName::custom("x", "role").to_string(), "x:role")
  assert_eq(
    @markdown.RuleName::commonmark("inline:text").to_string(),
    "cm:inline:text",
  )
  assert_eq(@markdown.RuleName::custom("x", "inline").to_string(), "x:inline")
  assert_true(@markdown.SourceRange::new(-1, 0) is None)
  assert_true(@markdown.SourceRange::new(3, 2) is None)
  let range = match @markdown.SourceRange::new(2, 7) {
    Some(range) => range
    None => abort("expected valid range")
  }
  let attrs = [@markdown.Attr(@markdown.AttrName::raw("kind"), "tip")]
  let element = @markdown.Element::with_attrs(
    @markdown.Tag::custom("x", "note"),
    attrs,
    range=Some(range),
  )
  assert_eq(element.tag().to_string(), "x:note")
  assert_true(element.attr(@markdown.AttrName::raw("kind")) is Some("tip"))
  assert_range(element.range(), 2, 7)
  let copied_attrs = element.attrs()
  copied_attrs.push(@markdown.Attr(@markdown.AttrName::raw("extra"), "ignored"))
  assert_eq(element.attrs().length(), 1)
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
test "event fragment builders return balanced defensive copies" {
  let fragment = @markdown.EventFragment::concat([
    @markdown.EventFragment::text("a"),
    @markdown.EventFragment::soft_break(),
    @markdown.EventFragment::hard_break(),
    @markdown.EventFragment::html("<raw>"),
    @markdown.EventFragment::element(
      @markdown.Element(@markdown.Tag::raw("x:note")),
      children=[@markdown.EventFragment::text("b")],
    ),
  ])
  let copied = fragment.events()
  copied.push(Text("ignored"))
  assert_eq(fragment.events().length(), 7)
  assert_true(
    @markdown.EventFragment::from_events([
      Enter(@markdown.Element(@markdown.Tag::raw("x:open"))),
      Text("body"),
      Exit(@markdown.Tag::raw("x:open")),
    ])
    is Some(_),
  )
}
