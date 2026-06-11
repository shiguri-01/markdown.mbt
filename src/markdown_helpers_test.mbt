///|
fn render_html(rule : @markdown.Rule, source : String) -> String {
  let html = @markdown.Html(@commonmark.html_renderers())
  @markdown.Processor(rule).parse(source, html.sink())
  html.to_string()
}

///|
fn render_html_with(
  rule : @markdown.Rule,
  renderers : @markdown.HtmlRenderers,
  source : String,
) -> String {
  let html = @markdown.Html(renderers)
  @markdown.Processor(rule).parse(source, html.sink())
  html.to_string()
}

///|
fn render_gfm_html(rule : @markdown.Rule, source : String) -> String {
  let html = @markdown.Html(@gfm.html_renderers())
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
