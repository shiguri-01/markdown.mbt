///|
fn render_html(rule : @markdown.Rule, source : String) -> String {
  let html = @markdown.Html()
  @markdown.Processor(rule~).parse(source, html.sink())
  html.to_string()
}
