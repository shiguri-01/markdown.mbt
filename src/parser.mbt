///|
/// A configured Markdown processor.
///
/// A processor owns the rule registry used to turn Markdown input into events.
/// Build it from a rule before calling `parse`.
pub struct Processor {
  priv registry : RuleRegistry
}

///|
/// Creates a processor from `rule`, defaulting to CommonMark.
pub fn Processor::new(rule? : Rule = commonmark()) -> Processor {
  { registry: RuleRegistry::new().use_rule(rule) }
}

///|
/// Parses CommonMark and renders it to HTML.
pub fn html(source : String) -> String {
  let html = Html::new()
  Processor::new().parse(source, html.sink())
  html.to_string()
}

///|
/// Parses CommonMark and returns the event-derived AST.
pub fn ast(source : String) -> Result[AstNode, AstError] {
  let ast = Ast::new()
  Processor::new().parse(source, ast.sink())
  ast.result()
}

///|
/// Parses Markdown input and pushes events into `sink`.
///
/// Core event rules wrap the downstream sink, so transforms can participate in
/// the parse pipeline.
pub fn Processor::parse(self : Processor, input : String, sink : Sink) -> Unit {
  let downstream = apply_core_rules(sink, self.registry)
  let state = ParseState::new()
  let source = split_lines(input)
  if may_contain_reference_definition(input) {
    if self.registry.can_use_commonmark_deferred_block_parse() {
      parse_commonmark_deferred_blocks_into(
        source.lines,
        source.line_starts,
        self.registry,
        downstream,
        state,
      )
      downstream.finish()
      return
    }
    collect_reference_definitions_with_block_lines(
      source.lines,
      source.line_starts,
      self.registry,
      state,
    )
  }
  parse_block_lines_into(
    source.lines,
    source.line_starts,
    self.registry,
    downstream,
    state,
  )
  downstream.finish()
}

///|
fn may_contain_reference_definition(input : String) -> Bool {
  let first_label_opener = find_char(input, 91, 0)
  first_label_opener >= 0 &&
  find_substring(input, "]:", first_label_opener + 1) >= 0
}

///|
fn collect_reference_definitions_with_block_lines(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
  state : ParseState,
) -> Unit {
  parse_block_lines_range_into(
    lines,
    line_starts,
    0,
    lines.length(),
    registry,
    Sink::new(fn(_) { () }),
    state,
    collect_only=true,
  )
}

///|
fn parse_block_lines_into(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  collect_only? : Bool = false,
) -> Unit {
  parse_block_lines_range_into(
    lines,
    line_starts,
    0,
    lines.length(),
    registry,
    sink,
    state,
    collect_only~,
  )
}

///|
fn parse_block_lines_range_into(
  lines : Array[String],
  line_starts : Array[Int],
  start : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  collect_only? : Bool = false,
) -> Unit {
  let mut i = start
  let stop = if end > lines.length() { lines.length() } else { end }
  let inline_rules = if collect_only {
    []
  } else {
    registry.inline_parse_rules()
  }
  let inline_mode = if collect_only {
    CustomInlinePipeline
  } else {
    inline_parse_mode(inline_rules)
  }
  let block_continue_rules = registry.block_continue_rules()
  let block_start_rules = registry.block_rules()
  while i < stop {
    let mut consumed = 0
    let ctx = {
      lines,
      line_starts,
      index: i,
      registry,
      inline_rules,
      inline_mode,
      state,
      collect_only,
    }
    for rule in block_continue_rules {
      match rule.block {
        Some(f) =>
          if consumed == 0 {
            match f(ctx) {
              Match(lines, fragment) => {
                emit_fragment(sink, fragment)
                consumed = lines.to_int()
              }
              NoMatch => ()
            }
          }
        None => ()
      }
    }
    for rule in block_start_rules {
      match rule.block {
        Some(f) =>
          if consumed == 0 {
            match f(ctx) {
              Match(lines, fragment) => {
                emit_fragment(sink, fragment)
                consumed = lines.to_int()
              }
              NoMatch => ()
            }
          }
        None => ()
      }
    }
    if consumed <= 0 {
      consumed = if registry.has_enabled_block_rules() {
        match emit_fallback_text(ctx) {
          Match(lines, fragment) => {
            emit_fragment(sink, fragment)
            lines.to_int()
          }
          NoMatch => 1
        }
      } else {
        match cm_paragraph_block(ctx) {
          Match(lines, fragment) => {
            emit_fragment(sink, fragment)
            lines.to_int()
          }
          NoMatch => 1
        }
      }
    }
    i = i + consumed
  }
}

///|
priv struct BlockPayload {
  first : String
  mut lines : Array[String]?
  mut line_starts : Array[Int]?
  mut next_start : Int
  mut length : Int
  mut may_contain_reference : Bool
}

///|
fn BlockPayload::new(first : String) -> BlockPayload {
  {
    first,
    lines: None,
    line_starts: None,
    next_start: first.length() + 1,
    length: 1,
    may_contain_reference: may_contain_reference_definition(first),
  }
}

///|
fn BlockPayload::append(self : BlockPayload, line : String) -> Unit {
  self.materialize()
  match self.lines {
    Some(lines) => lines.push(line)
    None => ()
  }
  match self.line_starts {
    Some(line_starts) => line_starts.push(self.next_start)
    None => ()
  }
  self.next_start = self.next_start + line.length() + 1
  self.length = self.length + 1
  if !self.may_contain_reference && may_contain_reference_definition(line) {
    self.may_contain_reference = true
  }
}

///|
fn BlockPayload::materialize(self : BlockPayload) -> Unit {
  match self.lines {
    Some(_) => ()
    None => {
      self.lines = Some([self.first])
      self.line_starts = Some([0])
    }
  }
}

///|
fn BlockPayload::source(self : BlockPayload) -> LineSource {
  match (self.lines, self.line_starts) {
    (Some(lines), Some(line_starts)) => { lines, line_starts }
    _ => { lines: [self.first], line_starts: [0] }
  }
}

///|
fn BlockPayload::to_text(self : BlockPayload) -> String {
  match self.lines {
    Some(lines) => block_lines_text(lines)
    None => self.first
  }
}

///|
fn BlockPayload::is_not_empty(self : BlockPayload) -> Bool {
  match self.lines {
    Some(lines) => block_lines_not_empty(lines)
    None => self.first != ""
  }
}

///|
fn BlockPayload::parse_into(
  self : BlockPayload,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  collect_only? : Bool = false,
) -> Unit {
  let source = self.source()
  parse_block_lines_range_into(
    source.lines,
    source.line_starts,
    0,
    source.lines.length(),
    registry,
    sink,
    state,
    collect_only~,
  )
}

///|
fn BlockPayload::collect_references(
  self : BlockPayload,
  registry : RuleRegistry,
  state : ParseState,
) -> Unit {
  self.parse_into(registry, Sink::new(fn(_) { () }), state, collect_only=true)
}

///|
fn block_lines_not_empty(lines : Array[String]) -> Bool {
  for line in lines {
    if line != "" {
      return true
    }
  }
  false
}

///|
fn block_lines_text(lines : Array[String]) -> String {
  block_lines_text_range(lines, 0, lines.length())
}

///|
fn block_lines_text_range(
  lines : Array[String],
  start : Int,
  end : Int,
) -> String {
  if end <= start {
    return ""
  }
  if end == start + 1 {
    return lines[start]
  }
  let text = StringBuilder::new()
  for i in start..<end {
    if i > start {
      text.write_string("\n")
    }
    text.write_string(lines[i])
  }
  text.to_string()
}

///|
fn apply_core_rules(sink : Sink, registry : RuleRegistry) -> Sink {
  let mut current = sink
  let rules = registry.core_rules()
  for i in (rules.length() - 1)>=..0 {
    let rule = rules[i]
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
  if input.length() == 0 {
    return { lines: [], line_starts: [] }
  }
  if find_char(input, 10, 0) < 0 {
    return { lines: [expand_leading_tabs(input)], line_starts: [0] }
  }
  let lines : Array[String] = []
  let line_starts : Array[Int] = []
  let mut offset = 0
  for line in input.split("\n") {
    lines.push(expand_leading_tabs(line.to_owned()))
    line_starts.push(offset)
    offset = offset + line.length() + 1
  }
  if input.length() > 0 &&
    char_at(input, input.length() - 1) == 10 &&
    lines.length() > 0 &&
    lines[lines.length() - 1] == "" {
    ignore(lines.pop())
    ignore(line_starts.pop())
  }
  { lines, line_starts }
}

///|
fn expand_leading_tabs(line : String) -> String {
  let mut first_tab = -1
  let mut leading_end = 0
  while leading_end < line.length() {
    let c = char_at(line, leading_end)
    if c == 9 {
      first_tab = leading_end
      break
    } else if c == 32 {
      leading_end = leading_end + 1
    } else {
      break
    }
  }
  if first_tab < 0 {
    return line
  }
  let out = StringBuilder::new(size_hint=line.length() + 4)
  let mut column = 0
  let mut i = 0
  while i < line.length() {
    let c = char_at(line, i)
    if c == 32 {
      out.write_string(" ")
      column = column + 1
      i = i + 1
    } else if c == 9 {
      let spaces = 4 - column % 4
      for _ in 0..<spaces {
        out.write_string(" ")
      }
      column = column + spaces
      i = i + 1
    } else {
      out.write_view(line[i:])
      return out.to_string()
    }
  }
  out.to_string()
}
