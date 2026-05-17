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
  if may_contain_reference_definition(input) {
    collect_reference_definitions_with_blocks(input, self.registry, state)
  }
  parse_blocks_into(input, self.registry, downstream, state)
  downstream.finish()
}

///|
fn may_contain_reference_definition(input : String) -> Bool {
  find_char(input, 91, 0) >= 0
}

///|
fn collect_reference_definitions_with_blocks(
  input : String,
  registry : RuleRegistry,
  state : ParseState,
) -> Unit {
  parse_blocks_into(input, registry, Sink::new(fn(_) { () }), state)
}

///|
fn parse_blocks_into(
  input : String,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Unit {
  let source = split_lines(input)
  parse_block_lines_into(
    source.lines,
    source.line_starts,
    registry,
    sink,
    state,
  )
}

///|
fn parse_block_lines_into(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Unit {
  let mut i = 0
  let inline_rules = registry.inline_parse_rules()
  let block_continue_rules = registry.block_continue_rules()
  let block_start_rules = registry.block_rules()
  while i < lines.length() {
    let mut consumed = 0
    let ctx = { lines, line_starts, index: i, registry, inline_rules, state }
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
fn apply_core_rules(sink : Sink, registry : RuleRegistry) -> Sink {
  let mut current = sink
  let rules = registry.core_rules()
  for i = rules.length() - 1; i >= 0; i = i - 1 {
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
  let first_tab = find_char(line, 9, 0)
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
