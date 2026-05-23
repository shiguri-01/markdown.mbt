///|
fn ast_result_from_events(
  events : Array[@markdown.Event],
) -> Result[@markdown.AstNode, Error] {
  let ast = @markdown.Ast()
  let sink = ast.sink()
  for event in events {
    sink.emit(event)
  }
  sink.finish()
  try? ast.result()
}

///|
test "commonmark list item ast has no renderer-only block attribute" {
  let root = @markdown.ast("- one\n\n- two\n")
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

///|
test "ast reports invalid event streams" {
  let unexpected = ast_result_from_events([
    Exit(@markdown.Tag::raw("x:missing")),
  ])
  match unexpected {
    Err(@markdown.AstError::UnexpectedExit(tag)) =>
      assert_eq(tag.to_string(), "x:missing")
    _ => abort("expected unexpected exit")
  }

  let mismatched = ast_result_from_events([
    Enter(@markdown.Element(@markdown.Tag::raw("x:open"))),
    Exit(@markdown.Tag::raw("x:other")),
  ])
  match mismatched {
    Err(@markdown.AstError::MismatchedExit(opened, closed)) => {
      assert_eq(opened.to_string(), "x:open")
      assert_eq(closed.to_string(), "x:other")
    }
    _ => abort("expected mismatched exit")
  }

  let unclosed = ast_result_from_events([
    Enter(@markdown.Element(@markdown.Tag::raw("x:open"))),
    Text("body"),
  ])
  match unclosed {
    Err(@markdown.AstError::UnclosedTag(tag)) =>
      assert_eq(tag.to_string(), "x:open")
    _ => abort("expected unclosed tag")
  }
}

///|
test "ast preserves source ranges and returns defensive children copies" {
  let root = @markdown.ast("# Hi\n\ntext\n")
  let children = root.children()
  assert_eq(children.length(), 2)
  match children[0].element() {
    Some(el) => {
      assert_eq(el.tag().to_string(), "cm:heading")
      assert_range(children[0].range(), 0, 4)
      assert_range(el.range(), 0, 4)
    }
    None => abort("expected heading element")
  }
  match children[1].element() {
    Some(el) => {
      assert_eq(el.tag().to_string(), "cm:paragraph")
      assert_range(children[1].range(), 6, 10)
      assert_range(el.range(), 6, 10)
    }
    None => abort("expected paragraph element")
  }
  children.push(children[0])
  assert_eq(root.children().length(), 2)
}
