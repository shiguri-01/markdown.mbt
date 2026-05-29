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
  inline_mode : InlineParseMode
  core_rules : Array[RuleEntry]
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
  {
    registry,
    block_rules,
    block_continue_rules,
    inline_parse_rules,
    inline_mode: inline_parse_mode(inline_parse_rules),
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
fn inline_parse_mode(_rules : Array[RuleEntry]) -> InlineParseMode {
  CustomInlinePipeline
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
