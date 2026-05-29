///|
fn parse_inlines_with_rules(
  text : String,
  registry : RuleRegistry,
  plan : PreparedRulePlan,
  rules : Array[RuleEntry],
  inline_mode : InlineParseMode,
  inline_trigger_chars : String,
  sink : Sink,
  state : ParseState,
) -> Unit {
  if rules.length() == 0 {
    if text.length() > 0 {
      sink.emit(Text(text))
    }
    return
  }
  let text_length = text.length()
  let ctx = {
    text,
    index: 0,
    registry,
    plan,
    inline_rules: rules,
    inline_mode,
    inline_trigger_chars,
    state,
  }
  let mut i = 0
  while i < text_length {
    ctx.index = i
    let candidates = plan.inline_rules_for(char_at(text, i))
    let consumed = try_inline_rules(ctx, candidates, sink)
    if consumed == 0 {
      sink.emit(Text(text[i:i + 1].to_owned()))
      i = i + 1
    } else {
      i = i + consumed
    }
  }
}

///|
fn try_inline_rules(
  ctx : InlineContext,
  rules : Array[RuleEntry],
  sink : Sink,
) -> Int {
  for rule in rules {
    if rule.inline is Some(f) {
      if f(ctx, sink) is Match(chars) {
        return chars.to_int()
      }
    }
  }
  0
}
