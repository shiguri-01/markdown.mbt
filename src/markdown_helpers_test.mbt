///|
fn render_html(processor : @markdown.Processor, source : String) -> String {
  let html = @markdown.HtmlBuffer::new()
  processor.parse_into(source, html.sink())
  html.to_string()
}

///|
fn parse_events(
  processor : @markdown.Processor,
  source : String,
) -> Array[@markdown.Event] {
  let buffer = @markdown.EventBuffer::new()
  processor.parse_into(source, buffer.sink())
  buffer.collect()
}

///|
fn push_events(
  events : Array[@markdown.Event],
  sink : @markdown.EventSink,
) -> Unit {
  for event in events {
    sink.emit(event)
  }
  sink.finish()
}

///|
fn render_events(events : Array[@markdown.Event]) -> String {
  let html = @markdown.HtmlBuffer::new()
  push_events(events, html.sink())
  html.to_string()
}

///|
fn ast_from_events(
  events : Array[@markdown.Event],
) -> Result[@markdown.AstNode, @markdown.AstError] {
  let ast = @markdown.AstBuffer::new()
  push_events(events, ast.sink())
  ast.result()
}
