///|
fn mdast_from_commonmark(
  source : String,
) -> @markdown.MdastNode raise @markdown.AstError {
  let mdast = @markdown.Mdast()
  @markdown.Processor(@commonmark.rule()).parse(source, mdast.sink())
  mdast.result()
}

///|
fn mdast_from_gfm(
  source : String,
  rule : @markdown.Rule,
) -> @markdown.MdastNode raise @markdown.AstError {
  let mdast = @markdown.Mdast()
  @markdown.Processor(rule).parse(source, mdast.sink())
  mdast.result()
}

///|
test "commonmark mdast serializes root heading paragraph and phrasing nodes" {
  let root = mdast_from_commonmark(
    "# Hi\n\nA *small* **test** with `code` and [a](https://example.com \"t\").\n",
  )
  inspect(
    root.to_json().stringify(),
    content=(
      #|{"type":"root","children":[{"type":"heading","depth":1,"children":[{"type":"text","value":"Hi"}]},{"type":"paragraph","children":[{"type":"text","value":"A "},{"type":"emphasis","children":[{"type":"text","value":"small"}]},{"type":"text","value":" "},{"type":"strong","children":[{"type":"text","value":"test"}]},{"type":"text","value":" with "},{"type":"inlineCode","value":"code"},{"type":"text","value":" and "},{"type":"link","url":"https://example.com","title":"t","children":[{"type":"text","value":"a"}]},{"type":"text","value":"."}]}]}
    ),
  )
}

///|
test "commonmark mdast wraps tight list phrasing in paragraphs" {
  let root = mdast_from_commonmark("- one\n- two\n")
  inspect(
    root.to_json().stringify(),
    content=(
      #|{"type":"root","children":[{"type":"list","ordered":false,"start":null,"spread":false,"children":[{"type":"listItem","spread":false,"checked":null,"children":[{"type":"paragraph","children":[{"type":"text","value":"one"}]}]},{"type":"listItem","spread":false,"checked":null,"children":[{"type":"paragraph","children":[{"type":"text","value":"two"}]}]}]}]}
    ),
  )
}

///|
test "commonmark mdast serializes code html break image and thematic break" {
  let root = mdast_from_commonmark(
    "![alt](img.png)\n\n```moonbit\nprintln(1)\n```\n\nline\\\nbreak\n\n<div>x</div>\n\n---\n",
  )
  inspect(
    root.to_json().stringify(),
    content=(
      #|{"type":"root","children":[{"type":"paragraph","children":[{"type":"image","url":"img.png","title":null,"alt":"alt"}]},{"type":"code","lang":"moonbit","meta":null,"value":"println(1)\n"},{"type":"paragraph","children":[{"type":"text","value":"line"},{"type":"break"},{"type":"text","value":"break"}]},{"type":"html","value":"<div>x</div>\n"},{"type":"thematicBreak"}]}
    ),
  )
}

///|
test "gfm mdast serializes table strikethrough and task list checked" {
  let rule = @commonmark.rule()
    .extend(@gfm.tables())
    .extend(@gfm.strikethrough())
    .extend(@gfm.task_list_items())
  let root = mdast_from_gfm(
    "| a | b |\n| :- | -: |\n| ~~x~~ | y |\n\n- [x] done\n", rule,
  )
  inspect(
    root.to_json().stringify(),
    content=(
      #|{"type":"root","children":[{"type":"table","align":["left","right"],"children":[{"type":"tableRow","children":[{"type":"tableCell","children":[{"type":"text","value":"a"}]},{"type":"tableCell","children":[{"type":"text","value":"b"}]}]},{"type":"tableRow","children":[{"type":"tableCell","children":[{"type":"delete","children":[{"type":"text","value":"x"}]}]},{"type":"tableCell","children":[{"type":"text","value":"y"}]}]}]},{"type":"list","ordered":false,"start":null,"spread":false,"children":[{"type":"listItem","spread":false,"checked":true,"children":[{"type":"paragraph","children":[{"type":"text","value":"done"}]}]}]}]}
    ),
  )
}

///|
test "mdast reports invalid event streams like ast" {
  let mdast = @markdown.Mdast()
  let sink = mdast.sink()
  sink.emit(@markdown.Exit(@markdown.Tag::raw("x:missing")))
  sink.finish()
  let result = try? mdast.result()
  match result {
    Err(@markdown.AstError::UnexpectedExit(tag)) =>
      assert_eq(tag.to_string(), "x:missing")
    _ => abort("expected unexpected exit")
  }
}
