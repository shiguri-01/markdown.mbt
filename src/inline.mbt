///|
fn parse_inlines_with_rules(
  text : String,
  registry : RuleRegistry,
  rules : Array[RuleEntry],
  inline_mode : InlineParseMode,
  sink : Sink,
  state : ParseState,
) -> Unit {
  if rules.length() == 0 {
    if text.length() > 0 {
      sink.emit(Text(text))
    }
    return
  }
  let mut i = 0
  while i < text.length() {
    let ctx = {
      text,
      index: i,
      scanner: inline_scanner(text, i),
      registry,
      inline_rules: rules,
      inline_mode,
      state,
    }
    let consumed = try_inline_rules(ctx, rules, sink)
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
    if rule.triggers != "" &&
      !contains_char(rule.triggers, char_at(ctx.text, ctx.index)) {
      continue
    }
    if rule.inline is Some(f) {
      if f(ctx) is Match(chars, fragment) {
        fragment.emit_to(sink)
        return chars.to_int()
      }
    }
  }
  0
}
