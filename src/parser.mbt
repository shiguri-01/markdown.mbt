///|
pub struct ParserBuilder {
  priv registry : RuleRegistry
}

///|
pub struct Parser {
  priv events : Array[Event]
  priv mut index : Int
}

///|
pub fn ParserBuilder::new() -> ParserBuilder {
  { registry: RuleRegistry::new() }
}

///|
pub fn new() -> ParserBuilder {
  ParserBuilder::new()
}

///|
pub fn ParserBuilder::commonmark() -> ParserBuilder {
  ParserBuilder::new().use(commonmark_plugin())
}

///|
pub fn commonmark() -> ParserBuilder {
  ParserBuilder::commonmark()
}

///|
pub fn ParserBuilder::use(
  self : ParserBuilder,
  plugin : Plugin,
) -> ParserBuilder {
  ignore(self.registry.use_plugin(plugin))
  self
}

///|
pub fn ParserBuilder::enable(
  self : ParserBuilder,
  name : RuleName,
) -> ParserBuilder {
  ignore(self.registry.enable(name))
  self
}

///|
pub fn ParserBuilder::disable(
  self : ParserBuilder,
  name : RuleName,
) -> ParserBuilder {
  ignore(self.registry.disable(name))
  self
}

///|
pub fn ParserBuilder::replace(
  self : ParserBuilder,
  rule : Rule,
) -> ParserBuilder {
  ignore(self.registry.replace(rule))
  self
}

///|
pub fn ParserBuilder::parse(self : ParserBuilder, input : String) -> Parser {
  let source = apply_source_core_rules(input, self.registry)
  {
    events: apply_core_rules(parse_blocks(source, self.registry), self.registry),
    index: 0,
  }
}

///|
pub fn Parser::next(self : Parser) -> Event? {
  if self.index >= self.events.length() {
    None
  } else {
    let event = self.events[self.index]
    self.index = self.index + 1
    Some(event)
  }
}

///|
pub fn Parser::collect(self : Parser) -> Array[Event] {
  self.events
}

///|
pub fn Parser::to_html(self : Parser) -> String {
  HtmlRenderer::new().render(self.events)
}

///|
fn parse_blocks(input : String, registry : RuleRegistry) -> Array[Event] {
  let source = split_lines(input)
  parse_block_lines(source.lines, source.line_starts, registry)
}

///|
fn parse_block_lines(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
) -> Array[Event] {
  let sink : EventSink = { events: [] }
  let mut i = 0
  let block_continue_rules = registry.block_continue_rules()
  let block_start_rules = registry.block_rules()
  while i < lines.length() {
    let mut consumed = 0
    let ctx = { lines, line_starts, index: i, registry }
    for rule in block_continue_rules {
      match rule.block {
        Some(f) => if consumed == 0 { consumed = f(ctx, sink) }
        None => ()
      }
    }
    for rule in block_start_rules {
      match rule.block {
        Some(f) => if consumed == 0 { consumed = f(ctx, sink) }
        None => ()
      }
    }
    if consumed <= 0 {
      consumed = if registry.has_enabled_block_rules() {
        emit_fallback_text(ctx, sink)
      } else {
        cm_paragraph_block(ctx, sink)
      }
    }
    i = i + consumed
  }
  sink.events
}

///|
fn apply_source_core_rules(input : String, registry : RuleRegistry) -> String {
  let mut current = input
  for rule in registry.core_rules() {
    match rule.source_core {
      Some(f) => current = f(current)
      None => ()
    }
  }
  current
}

///|
fn apply_core_rules(
  events : Array[Event],
  registry : RuleRegistry,
) -> Array[Event] {
  let mut current = events
  for rule in registry.core_rules() {
    match rule.core {
      Some(f) => current = f(current)
      None => ()
    }
  }
  current
}

///|
priv struct LineSource {
  lines : Array[String]
  line_starts : Array[Int]
}

///|
fn split_lines(input : String) -> LineSource {
  let lines : Array[String] = []
  let line_starts : Array[Int] = []
  let mut offset = 0
  for line in input.split("\n") {
    lines.push(line.to_owned())
    line_starts.push(offset)
    offset = offset + line.length() + 1
  }
  if input.length() == 0 {
    { lines: [], line_starts: [] }
  } else {
    { lines, line_starts }
  }
}
