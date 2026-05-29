///|
/// A configured Markdown processor.
///
/// A processor owns the rule registry used to turn Markdown input into events.
/// Build it from a rule before calling `parse`.
pub struct Processor {
  priv plan : PreparedRulePlan
}

///|
/// Creates a processor from `rule`.
pub fn Processor::Processor(rule : Rule) -> Processor {
  let registry = RuleRegistry().use_rule(rule)
  { plan: PreparedRulePlan(registry) }
}

///|
/// Parses Markdown input and pushes events into `sink`.
///
/// Core event rules wrap the downstream sink, so transforms can participate in
/// the parse pipeline.
pub fn Processor::parse(self : Processor, input : String, sink : Sink) -> Unit {
  let downstream = apply_core_rules(sink, self.plan)
  let state = ParseState()
  let source = split_lines(input)
  if source.may_contain_reference {
    collect_reference_definitions_with_block_lines(
      source.lines,
      source.line_starts,
      self.plan,
      state,
    )
  }
  parse_block_lines_into(
    source.lines,
    source.line_starts,
    self.plan,
    downstream,
    state,
  )
  downstream.finish()
}

///|
fn may_contain_reference_definition(input : String) -> Bool {
  let first_label_opener = find_char(input, '[', 0)
  first_label_opener >= 0 &&
  find_substring(input, "]:", first_label_opener + 1) >= 0
}

///|
fn collect_reference_definitions_with_block_lines(
  lines : Array[String],
  line_starts : Array[Int],
  plan : PreparedRulePlan,
  state : ParseState,
) -> Unit {
  parse_block_lines_range_into(
    lines,
    line_starts,
    0,
    lines.length(),
    plan,
    Sink(fn(_) { () }),
    state,
    collect_only=true,
  )
}

///|
fn parse_block_lines_into(
  lines : Array[String],
  line_starts : Array[Int],
  plan : PreparedRulePlan,
  sink : Sink,
  state : ParseState,
  collect_only? : Bool = false,
) -> Unit {
  parse_block_lines_range_into(
    lines,
    line_starts,
    0,
    lines.length(),
    plan,
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
  plan : PreparedRulePlan,
  sink : Sink,
  state : ParseState,
  collect_only? : Bool = false,
) -> Unit {
  let mut i = start
  let stop = if end > lines.length() { lines.length() } else { end }
  let inline_rules = if collect_only { [] } else { plan.inline_parse_rules }
  let inline_mode = if collect_only {
    CustomInlinePipeline
  } else {
    plan.inline_mode
  }
  let block_continue_rules = plan.block_continue_rules
  let block_start_rules = plan.block_rules
  while i < stop {
    let ctx = {
      lines,
      line_starts,
      index: i,
      registry: plan.registry,
      plan,
      inline_rules,
      inline_mode,
      state,
      collect_only,
    }
    let mut consumed = try_block_rules(ctx, block_continue_rules, sink)
    if consumed == 0 {
      consumed = try_block_rules(ctx, block_start_rules, sink)
    }
    if consumed <= 0 {
      consumed = emit_block_rule_result(emit_fallback_text(ctx), sink)
    }
    i = i + consumed
  }
}

///|
fn try_block_rules(
  ctx : BlockContext,
  rules : Array[RuleEntry],
  sink : Sink,
) -> Int {
  for rule in rules {
    if rule.block is Some(f) {
      let consumed = emit_block_rule_result(f(ctx), sink, fallback=0)
      if consumed > 0 {
        return consumed
      }
    }
  }
  0
}

///|
fn emit_block_rule_result(
  result : BlockRuleResult,
  sink : Sink,
  fallback? : Int = 1,
) -> Int {
  match result {
    Match(lines, fragment) => {
      fragment.emit_to(sink)
      lines.to_int()
    }
    NoMatch => fallback
  }
}

///|
fn emit_fallback_text(ctx : BlockContext) -> BlockRuleResult {
  Match(ConsumedLines(1), EventFragment::text(ctx.current_line()))
}

///|
fn apply_core_rules(sink : Sink, plan : PreparedRulePlan) -> Sink {
  let mut current = sink
  let rules = plan.core_rules
  for i in (rules.length() - 1)>=..0 {
    let rule = rules[i]
    if rule.core is Some(f) {
      current = f(current)
    }
  }
  current
}

///|
priv struct LineSource {
  lines : Array[String]
  line_starts : Array[Int]
  may_contain_reference : Bool
}

///|
fn split_lines(input : String) -> LineSource {
  if input.length() == 0 {
    return { lines: [], line_starts: [], may_contain_reference: false }
  }
  if find_char(input, '\n', 0) < 0 {
    return {
      lines: [expand_leading_tabs(input)],
      line_starts: [0],
      may_contain_reference: may_contain_reference_definition(input),
    }
  }
  let lines : Array[String] = []
  let line_starts : Array[Int] = []
  let mut line_start = 0
  let mut seen_label_opener = false
  let mut may_contain_reference = false
  let input_length = input.length()
  for i in 0..<input_length {
    let c = char_at(input, i)
    if !may_contain_reference {
      if c == '[' {
        seen_label_opener = true
      } else if seen_label_opener &&
        c == ']' &&
        i + 1 < input_length &&
        char_at(input, i + 1) == ':' {
        may_contain_reference = true
      }
    }
    if c == '\n' {
      lines.push(expand_leading_tabs(input[line_start:i].to_owned()))
      line_starts.push(line_start)
      line_start = i + 1
    }
  }
  if line_start < input_length || char_at(input, input_length - 1) != '\n' {
    let line = if line_start == 0 {
      input
    } else {
      input[line_start:].to_owned()
    }
    lines.push(expand_leading_tabs(line))
    line_starts.push(line_start)
  }
  { lines, line_starts, may_contain_reference }
}

///|
fn expand_leading_tabs(line : String) -> String {
  let first_tab = for i in 0..<line.length() {
    let c = char_at(line, i)
    match c {
      '\t' => break i
      ' ' => ()
      _ => break -1
    }
  } nobreak {
    -1
  }
  if first_tab < 0 {
    return line
  }
  let out = StringBuilder::new(size_hint=line.length() + 4)
  for i = 0, column = 0; i < line.length(); {
    let c = char_at(line, i)
    match c {
      ' ' => {
        out.write_string(" ")
        continue i + 1, column + 1
      }
      '\t' => {
        let spaces = 4 - column % 4
        for _ in 0..<spaces {
          out.write_string(" ")
        }
        continue i + 1, column + spaces
      }
      _ => {
        out.write_view(line[i:])
        break out.to_string()
      }
    }
  } nobreak {
    out.to_string()
  }
}
