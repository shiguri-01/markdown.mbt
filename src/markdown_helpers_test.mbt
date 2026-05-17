///|
fn render_html(processor : @markdown.Processor, source : String) -> String {
  let html = @markdown.Html::new()
  processor.parse(source, html.sink())
  html.to_string()
}

///|
fn parse_events(
  processor : @markdown.Processor,
  source : String,
) -> Array[@markdown.Event] {
  let buffer = @markdown.Events::new()
  processor.parse(source, buffer.sink())
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
