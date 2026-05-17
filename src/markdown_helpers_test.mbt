///|
fn render_html(rule : @markdown.Rule, source : String) -> String {
  let html = @markdown.Html::new()
  @markdown.Processor::new(rule~).parse(source, html.sink())
  html.to_string()
}

///|
fn parse_events(
  rule : @markdown.Rule,
  source : String,
) -> Array[@markdown.Event] {
  let buffer = @markdown.Events::new()
  @markdown.Processor::new(rule~).parse(source, buffer.sink())
  buffer.collect()
}

///|
fn push_events(events : Array[@markdown.Event], sink : @markdown.Sink) -> Unit {
  for event in events {
    sink.emit(event)
  }
  sink.finish()
}

///|
fn render_events(events : Array[@markdown.Event]) -> String {
  let html = @markdown.Html::new()
  push_events(events, html.sink())
  html.to_string()
}

///|
fn ast_from_events(
  events : Array[@markdown.Event],
) -> Result[@markdown.AstNode, @markdown.AstError] {
  let ast = @markdown.Ast::new()
  push_events(events, ast.sink())
  ast.result()
}
