///|
fn render_html(rule : @markdown.Rule, source : String) -> String {
  let html = @markdown.Html::new()
  @markdown.Processor::new(rule~).parse(source, html.sink())
  html.to_string()
}
