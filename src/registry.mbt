///|
priv struct RuleRegistry {
  mut rules : Array[RuleEntry]
  mut disabled : Array[RuleName]
  mut overrides : Array[RuleEntry]
  mut next_order : Int
}

///|
priv struct PreparedRulePlan {
  registry : RuleRegistry
  block_rules : Array[RuleEntry]
  block_continue_rules : Array[RuleEntry]
  inline_parse_rules : Array[RuleEntry]
  inline_fallback_rules : Array[RuleEntry]
  inline_ascii_rule_buckets : Array[Array[RuleEntry]]
  inline_rule_buckets : Array[InlineRuleBucket]
  inline_mode : InlineParseMode
  inline_trigger_chars : String
  inline_has_triggers_outside_commonmark : Bool
  core_rules : Array[RuleEntry]
}

///|
priv struct InlineRuleBucket {
  trigger : Int
  rules : Array[RuleEntry]
}

///|
fn RuleRegistry::RuleRegistry() -> RuleRegistry {
  { rules: [], disabled: [], overrides: [], next_order: 0 }
}

///|
fn PreparedRulePlan::PreparedRulePlan(
  registry : RuleRegistry,
) -> PreparedRulePlan {
  let block_rules = registry.block_rules()
  let block_continue_rules = registry.block_continue_rules()
  let inline_parse_rules = registry.inline_parse_rules()
  let core_rules = registry.core_rules()
  let inline_trigger_chars = inline_trigger_chars(inline_parse_rules)
  let inline_fallback_rules = inline_fallback_rules(inline_parse_rules)
  {
    registry,
    block_rules,
    block_continue_rules,
    inline_parse_rules,
    inline_fallback_rules,
    inline_ascii_rule_buckets: inline_ascii_rule_buckets(
      inline_parse_rules, inline_trigger_chars, inline_fallback_rules,
    ),
    inline_rule_buckets: inline_non_ascii_rule_buckets(
      inline_parse_rules, inline_trigger_chars,
    ),
    inline_mode: inline_parse_mode(inline_parse_rules),
    inline_trigger_chars,
    inline_has_triggers_outside_commonmark: inline_has_triggers_other_than(
      inline_trigger_chars,
      commonmark_inline_trigger_chars(),
    ),
    core_rules,
  }
}

///|
fn RuleRegistry::register(
  self : RuleRegistry,
  rule : RuleEntry,
) -> RuleRegistry {
  match self.override_for(rule.name) {
    Some(replace) => self.override_registered(replace)
    None => self.register_raw(rule)
  }
}

///|
fn RuleRegistry::register_raw(
  self : RuleRegistry,
  rule : RuleEntry,
) -> RuleRegistry {
  let r = {
    name: rule.name,
    chain: rule.chain,
    before: copy_rule_names(rule.before),
    after: copy_rule_names(rule.after),
    priority: rule.priority,
    order: self.next_order,
    triggers: rule.triggers,
    block: rule.block,
    inline: rule.inline,
    core: rule.core,
  }
  self.next_order = self.next_order + 1
  self.rules.push(r)
  sort_rules(self.rules)
  self
}

///|
fn RuleRegistry::use_rule(self : RuleRegistry, rule : Rule) -> RuleRegistry {
  for op in rule.ops {
    ignore(self.apply_rule_op(op))
  }
  self
}

///|
fn RuleRegistry::apply_rule_op(
  self : RuleRegistry,
  op : RuleOp,
) -> RuleRegistry {
  match op {
    RegisterRule(rule) => self.register(rule)
    DisableRule(name) => self.disable(name)
    EnableRule(name) => self.enable(name)
    ReplaceRule(rule) => self.replace(rule)
  }
}

///|
fn RuleRegistry::enable(self : RuleRegistry, name : RuleName) -> RuleRegistry {
  let next : Array[RuleName] = []
  for disabled in self.disabled {
    if disabled != name {
      next.push(disabled)
    }
  }
  self.disabled = next
  self
}

///|
fn RuleRegistry::disable(self : RuleRegistry, name : RuleName) -> RuleRegistry {
  if !array_contains_string(self.disabled, name) {
    self.disabled.push(name)
  }
  self
}

///|
fn RuleRegistry::replace(self : RuleRegistry, rule : RuleEntry) -> RuleRegistry {
  self.remember_override(rule)
  self.override_registered(rule)
}

///|
fn RuleRegistry::remember_override(
  self : RuleRegistry,
  rule : RuleEntry,
) -> Unit {
  let next : Array[RuleEntry] = []
  for old in self.overrides {
    if old.name != rule.name {
      next.push(old)
    }
  }
  next.push(rule)
  self.overrides = next
}

///|
fn RuleRegistry::override_for(
  self : RuleRegistry,
  name : RuleName,
) -> RuleEntry? {
  for rule in self.overrides {
    if rule.name == name {
      return Some(rule)
    }
  }
  None
}

///|
fn RuleRegistry::override_registered(
  self : RuleRegistry,
  rule : RuleEntry,
) -> RuleRegistry {
  let next : Array[RuleEntry] = []
  for old in self.rules {
    if old.name != rule.name {
      next.push(old)
    }
  }
  self.rules = next
  self.register_raw(rule)
}

///|
fn RuleRegistry::block_rules(self : RuleRegistry) -> Array[RuleEntry] {
  self.rules_for(BlockStart)
}

///|
fn RuleRegistry::block_continue_rules(self : RuleRegistry) -> Array[RuleEntry] {
  self.rules_for(BlockContinue)
}

///|
fn RuleRegistry::inline_rules(self : RuleRegistry) -> Array[RuleEntry] {
  self.rules_for(Inline)
}

///|
fn RuleRegistry::delimiter_rules(self : RuleRegistry) -> Array[RuleEntry] {
  self.rules_for(Delimiter)
}

///|
fn RuleRegistry::core_rules(self : RuleRegistry) -> Array[RuleEntry] {
  self.rules_for(Core)
}

///|
fn RuleRegistry::inline_parse_rules(self : RuleRegistry) -> Array[RuleEntry] {
  let rules = self.delimiter_rules()
  for rule in self.inline_rules() {
    rules.push(rule)
  }
  rules
}

///|
fn inline_trigger_chars(rules : Array[RuleEntry]) -> String {
  let out = StringBuilder::new()
  let seen : Array[Int] = []
  for rule in rules {
    for i in 0..<rule.triggers.length() {
      let c = char_at(rule.triggers, i)
      if !array_contains_int(seen, c) {
        seen.push(c)
        out <+ "\{rule.triggers[i:i + 1].to_owned()}"
      }
    }
  }
  out.to_string()
}

///|
fn inline_fallback_rules(rules : Array[RuleEntry]) -> Array[RuleEntry] {
  let selected : Array[RuleEntry] = []
  for rule in rules {
    if rule.triggers == "" {
      selected.push(rule)
    }
  }
  selected
}

///|
fn inline_ascii_rule_buckets(
  rules : Array[RuleEntry],
  triggers : String,
  fallback : Array[RuleEntry],
) -> Array[Array[RuleEntry]] {
  let buckets : Array[Array[RuleEntry]] = []
  for _ in 0..<128 {
    buckets.push(fallback)
  }
  for i in 0..<triggers.length() {
    let trigger = char_at(triggers, i)
    if trigger >= 0 && trigger < buckets.length() {
      buckets[trigger] = inline_rules_for_trigger(rules, trigger)
    }
  }
  buckets
}

///|
fn inline_non_ascii_rule_buckets(
  rules : Array[RuleEntry],
  triggers : String,
) -> Array[InlineRuleBucket] {
  let buckets : Array[InlineRuleBucket] = []
  for i in 0..<triggers.length() {
    let trigger = char_at(triggers, i)
    if trigger >= 128 {
      buckets.push({ trigger, rules: inline_rules_for_trigger(rules, trigger) })
    }
  }
  buckets
}

///|
fn inline_rules_for_trigger(
  rules : Array[RuleEntry],
  trigger : Int,
) -> Array[RuleEntry] {
  let selected : Array[RuleEntry] = []
  for rule in rules {
    if rule.triggers == "" || contains_char(rule.triggers, trigger) {
      selected.push(rule)
    }
  }
  selected
}

///|
fn PreparedRulePlan::inline_rules_for(
  self : PreparedRulePlan,
  trigger : Int,
) -> Array[RuleEntry] {
  if trigger >= 0 && trigger < self.inline_ascii_rule_buckets.length() {
    return self.inline_ascii_rule_buckets[trigger]
  }
  for bucket in self.inline_rule_buckets {
    if bucket.trigger == trigger {
      return bucket.rules
    }
  }
  self.inline_fallback_rules
}

///|
fn inline_parse_mode(_rules : Array[RuleEntry]) -> InlineParseMode {
  CustomInlinePipeline
}

///|
fn inline_has_triggers_other_than(triggers : String, ignored : String) -> Bool {
  for i in 0..<triggers.length() {
    if !contains_char(ignored, char_at(triggers, i)) {
      return true
    }
  }
  false
}

///|
fn commonmark_inline_trigger_chars() -> String {
  " ![<&`*_\\\n"
}

///|
fn RuleRegistry::rules_for(
  self : RuleRegistry,
  chain : RuleChain,
) -> Array[RuleEntry] {
  let selected : Array[RuleEntry] = []
  for rule in self.rules {
    if rule.chain == chain && !array_contains_string(self.disabled, rule.name) {
      selected.push(rule)
    }
  }
  selected
}

///|
fn sort_rules(rules : Array[RuleEntry]) -> Unit {
  let n = rules.length()
  for i in 1..<n {
    let current = rules[i]
    let mut j = i
    while j > 0 && rule_less(current, rules[j - 1]) {
      rules[j] = rules[j - 1]
      j = j - 1
    }
    rules[j] = current
  }
  apply_rule_edges(rules)
}

///|
fn apply_rule_edges(rules : Array[RuleEntry]) -> Unit {
  let n = rules.length()
  for _ in 0..<n {
    for i in 0..<rules.length() {
      let rule = rules[i]
      for name in rule.before {
        let j = find_rule_index(rules, name, rule.chain)
        if j >= 0 && i > j {
          move_rule(rules, i, j)
        }
      }
      for name in rule.after {
        let j = find_rule_index(rules, name, rule.chain)
        if j >= 0 && i < j {
          move_rule(rules, i, j)
        }
      }
    }
  }
}

///|
fn rule_less(left : RuleEntry, right : RuleEntry) -> Bool {
  if left.priority != right.priority {
    left.priority > right.priority
  } else {
    left.order < right.order
  }
}

///|
fn find_rule_index(
  rules : Array[RuleEntry],
  name : RuleName,
  chain : RuleChain,
) -> Int {
  for i in 0..<rules.length() {
    if rules[i].name == name && rules[i].chain == chain {
      return i
    }
  }
  -1
}

///|
fn move_rule(rules : Array[RuleEntry], from : Int, to : Int) -> Unit {
  let rule = rules[from]
  if from < to {
    for i in from..<to {
      rules[i] = rules[i + 1]
    }
  } else {
    for i in from>=..(to + 1) {
      rules[i] = rules[i - 1]
    }
  }
  rules[to] = rule
}

///|
fn array_contains_string(items : Array[RuleName], needle : RuleName) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}

///|
fn array_contains_int(items : Array[Int], needle : Int) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}

///|
fn copy_rule_names(names : Array[RuleName]) -> Array[RuleName] {
  let copied : Array[RuleName] = []
  for name in names {
    copied.push(name)
  }
  copied
}

///|
fn copy_rule_entry(rule : RuleEntry) -> RuleEntry {
  {
    name: rule.name,
    chain: rule.chain,
    before: copy_rule_names(rule.before),
    after: copy_rule_names(rule.after),
    priority: rule.priority,
    order: rule.order,
    triggers: rule.triggers,
    block: rule.block,
    inline: rule.inline,
    core: rule.core,
  }
}

///|
fn copy_rule_op(op : RuleOp) -> RuleOp {
  match op {
    RegisterRule(rule) => RegisterRule(copy_rule_entry(rule))
    DisableRule(name) => DisableRule(name)
    EnableRule(name) => EnableRule(name)
    ReplaceRule(rule) => ReplaceRule(copy_rule_entry(rule))
  }
}

///|
fn copy_rule_ops(ops : Array[RuleOp]) -> Array[RuleOp] {
  let copied : Array[RuleOp] = []
  for op in ops {
    copied.push(copy_rule_op(op))
  }
  copied
}
