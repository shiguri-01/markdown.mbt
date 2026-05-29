///|
fn render_html(rule : @markdown.Rule, source : String) -> String {
  let html = @markdown.Html()
  @markdown.Processor(rule).parse(source, html.sink())
  html.to_string()
}

///|
fn assert_range(
  range : @markdown.SourceRange?,
  start : Int,
  end : Int,
) -> Unit raise {
  match range {
    Some(range) => {
      assert_eq(range.start(), start)
      assert_eq(range.end(), end)
    }
    None => abort("expected source range")
  }
}
