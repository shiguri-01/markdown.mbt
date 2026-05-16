///|
/// A configured Markdown processor.
///
/// A processor owns the rule registry used to turn Markdown input into events.
/// Add plugins before calling `parse`.
pub struct Processor {
  priv registry : RuleRegistry
}

///|
/// A pull parser over an already-produced event stream.
pub struct Parser {
  priv events : Array[Event]
  priv mut index : Int
}

///|
/// Creates an empty processor with no registered rules.
///
/// Parsing with an empty processor still emits a fallback paragraph for plain
/// text input.
pub fn Processor::new() -> Processor {
  { registry: RuleRegistry::new() }
}

///|
/// Creates a processor with the built-in CommonMark plugin installed.
pub fn Processor::commonmark() -> Processor {
  Processor::new().with_plugin(commonmark_plugin())
}

///|
/// Creates a processor with the built-in CommonMark plugin installed.
pub fn commonmark() -> Processor {
  Processor::commonmark()
}

///|
/// Parses Markdown input with the built-in CommonMark processor.
pub fn parse(source : String) -> Array[Event] {
  commonmark().parse(source).collect()
}

///|
/// Registers all rules from `plugin` on this processor.
///
/// Plugin operations are applied in order. Registered rules are ordered by
/// priority, registration order, and same-chain `before`/`after` edges.
pub fn Processor::with_plugin(self : Processor, plugin : Plugin) -> Processor {
  let registry = self.registry.copy().use_plugin(plugin)
  { registry, }
}

///|
/// Parses Markdown input into a pull parser of events.
///
/// Source core rules run before block parsing. Core event rules run after block
/// and inline parsing.
pub fn Processor::parse(self : Processor, input : String) -> Parser {
  let source = apply_source_core_rules(input, self.registry)
  {
    events: apply_core_rules(parse_blocks(source, self.registry), self.registry),
    index: 0,
  }
}

///|
/// Returns the next event, or `None` after the stream is exhausted.
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
/// Collects the remaining events and advances the parser to the end.
pub fn Parser::collect(self : Parser) -> Array[Event] {
  let remaining : Array[Event] = []
  while self.index < self.events.length() {
    remaining.push(copy_event(self.events[self.index]))
    self.index = self.index + 1
  }
  remaining
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
  if registry.has_commonmark_block_rules_only() {
    return parse_commonmark_block_lines(lines, line_starts, registry)
  }
  let sink : EventSink = { events: [] }
  let mut i = 0
  let inline_rules = registry.inline_parse_rules()
  let block_continue_rules = registry.block_continue_rules()
  let block_start_rules = registry.block_rules()
  while i < lines.length() {
    let mut consumed = 0
    let ctx = { lines, line_starts, index: i, registry, inline_rules }
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
fn parse_commonmark_block_lines(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
) -> Array[Event] {
  let sink : EventSink = { events: [] }
  let mut i = 0
  let inline_rules = registry.inline_parse_rules()
  while i < lines.length() {
    let ctx = { lines, line_starts, index: i, registry, inline_rules }
    let mut consumed = commonmark_block_dispatch(ctx, sink)
    if consumed == 0 {
      consumed = cm_paragraph_block(ctx, sink)
    }
    if consumed <= 0 {
      consumed = 1
    }
    i = i + consumed
  }
  sink.events
}

///|
fn commonmark_block_dispatch(ctx : BlockContext, sink : EventSink) -> Int {
  let line = ctx.lines[ctx.index]
  let trimmed = trim(line)
  if trimmed == "" {
    ignore(sink)
    return 1
  }
  let leading = count_leading_spaces(line)
  let c = char_at(trimmed, 0)
  if leading <= 3 && (c == 96 || c == 126) {
    let consumed = cm_fenced_code_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if leading >= 4 {
    return cm_indented_code_block(ctx, sink)
  }
  if c == 45 || c == 42 || c == 95 {
    let consumed = cm_thematic_break_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if ctx.index + 1 < ctx.lines.length() {
    let next = trim(ctx.lines[ctx.index + 1])
    if next != "" {
      let marker = char_at(next, 0)
      if marker == 45 || marker == 61 {
        let consumed = cm_setext_heading_block(ctx, sink)
        if consumed != 0 {
          return consumed
        }
      }
    }
  }
  if c == 60 {
    let consumed = cm_html_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if c == 35 {
    let consumed = cm_atx_heading_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if c == 62 {
    let consumed = cm_blockquote_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if c == 45 || c == 42 || c == 43 || (c >= 48 && c <= 57) {
    let consumed = cm_list_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  0
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
