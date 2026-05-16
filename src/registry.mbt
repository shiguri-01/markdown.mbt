///|
priv enum RuleChain {
  BlockContinue
  BlockStart
  Inline
  Delimiter
  Core
} derive(Eq)

///|
/// A block rule consumes source lines and emits events.
///
/// The return value is the number of lines consumed. Return `0` when the rule
/// does not match.
pub type BlockRuleFn = (BlockContext, EventSink) -> Int

///|
/// An inline rule consumes characters from inline source and emits events.
///
/// The return value is the number of source positions consumed. Return `0` when the rule
/// does not match.
pub type InlineRuleFn = (InlineContext, EventSink) -> Int

///|
/// A core rule wraps a downstream sink with stream transformation behavior.
pub type CoreRuleFn = (EventSink) -> EventSink

///|
type SourceCoreRuleFn = (String) -> String

///|
/// A parser rule registered by a plugin.
pub struct Rule {
  priv name : RuleName
  priv chain : RuleChain
  priv before : Array[RuleName]
  priv after : Array[RuleName]
  priv priority : Int
  priv order : Int
  priv block : BlockRuleFn?
  priv inline : InlineRuleFn?
  priv core : CoreRuleFn?
  priv source_core : SourceCoreRuleFn?
}

///|
priv enum PluginOp {
  AddRule(Rule)
  DisableRule(RuleName)
  EnableRule(RuleName)
  OverrideRule(Rule)
}

///|
/// A composable collection of parser rule operations.
///
/// Plugins preserve operation order when composed. This makes a plugin a small
/// syntax extension, a larger preset such as CommonMark or GFM, or a local
/// configuration patch that disables or overrides rules from other plugins.
pub struct Plugin {
  priv name : String
  priv ops : Array[PluginOp]
}

///|
priv struct RuleRegistry {
  mut rules : Array[Rule]
  mut disabled : Array[RuleName]
  mut overrides : Array[Rule]
  mut next_order : Int
}

///|
/// Creates a block-start rule.
pub fn Rule::block(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  f : BlockRuleFn,
) -> Rule {
  {
    name,
    chain: BlockStart,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    block: Some(f),
    inline: None,
    core: None,
    source_core: None,
  }
}

///|
/// Creates a block-continuation rule.
///
/// Continuation rules run before block-start rules at each source line.
pub fn Rule::block_continue(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  f : BlockRuleFn,
) -> Rule {
  {
    name,
    chain: BlockContinue,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    block: Some(f),
    inline: None,
    core: None,
    source_core: None,
  }
}

///|
/// Creates an inline rule.
pub fn Rule::inline(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  f : InlineRuleFn,
) -> Rule {
  {
    name,
    chain: Inline,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    block: None,
    inline: Some(f),
    core: None,
    source_core: None,
  }
}

///|
/// Creates a delimiter rule.
///
/// Delimiter rules run in the inline phase before ordinary inline rules.
pub fn Rule::delimiter(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  f : InlineRuleFn,
) -> Rule {
  {
    name,
    chain: Delimiter,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    block: None,
    inline: Some(f),
    core: None,
    source_core: None,
  }
}

///|
/// Creates a core event rule.
pub fn Rule::core(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  f : CoreRuleFn,
) -> Rule {
  {
    name,
    chain: Core,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    block: None,
    inline: None,
    core: Some(f),
    source_core: None,
  }
}

///|
fn Rule::source_core(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  f : SourceCoreRuleFn,
) -> Rule {
  {
    name,
    chain: Core,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    block: None,
    inline: None,
    core: None,
    source_core: Some(f),
  }
}

///|
/// Creates an empty plugin.
pub fn Plugin::new(name : String) -> Plugin {
  { name, ops: [] }
}

///|
/// Returns the plugin name.
pub fn Plugin::name(self : Plugin) -> String {
  self.name
}

///|
/// Adds a rule to the plugin.
pub fn Plugin::add(self : Plugin, rule : Rule) -> Plugin {
  let ops = copy_plugin_ops(self.ops)
  ops.push(AddRule(rule))
  { name: self.name, ops }
}

///|
/// Appends all operations from `plugin` to this plugin.
///
/// Composition is order preserving: operations already in `self` are applied
/// before operations from `plugin`.
pub fn Plugin::with_plugin(self : Plugin, plugin : Plugin) -> Plugin {
  let ops = copy_plugin_ops(self.ops)
  for op in plugin.ops {
    ops.push(op)
  }
  { name: self.name, ops }
}

///|
/// Disables a rule by name when this plugin is installed.
pub fn Plugin::disable(self : Plugin, name : RuleName) -> Plugin {
  let ops = copy_plugin_ops(self.ops)
  ops.push(DisableRule(name))
  { name: self.name, ops }
}

///|
/// Re-enables a rule by name when this plugin is installed.
pub fn Plugin::enable(self : Plugin, name : RuleName) -> Plugin {
  let ops = copy_plugin_ops(self.ops)
  ops.push(EnableRule(name))
  { name: self.name, ops }
}

///|
/// Overrides rules with the same name.
///
/// Overrides are remembered by the registry, so they apply to both current and
/// later matching rules from composed plugins. If no base rule is ever
/// registered, the override rule still participates as an ordinary rule.
pub fn Plugin::override_rule(self : Plugin, rule : Rule) -> Plugin {
  let ops = copy_plugin_ops(self.ops)
  ops.push(OverrideRule(rule))
  { name: self.name, ops }
}

///|
fn RuleRegistry::new() -> RuleRegistry {
  { rules: [], disabled: [], overrides: [], next_order: 0 }
}

///|
fn RuleRegistry::copy(self : RuleRegistry) -> RuleRegistry {
  {
    rules: copy_rules(self.rules),
    disabled: copy_rule_names(self.disabled),
    overrides: copy_rules(self.overrides),
    next_order: self.next_order,
  }
}

///|
fn RuleRegistry::register(self : RuleRegistry, rule : Rule) -> RuleRegistry {
  match self.override_for(rule.name) {
    Some(override_rule) => self.override_registered(override_rule)
    None => self.register_raw(rule)
  }
}

///|
fn RuleRegistry::register_raw(self : RuleRegistry, rule : Rule) -> RuleRegistry {
  let r = {
    name: rule.name,
    chain: rule.chain,
    before: copy_rule_names(rule.before),
    after: copy_rule_names(rule.after),
    priority: rule.priority,
    order: self.next_order,
    block: rule.block,
    inline: rule.inline,
    core: rule.core,
    source_core: rule.source_core,
  }
  self.next_order = self.next_order + 1
  self.rules.push(r)
  sort_rules(self.rules)
  self
}

///|
fn RuleRegistry::use_plugin(
  self : RuleRegistry,
  plugin : Plugin,
) -> RuleRegistry {
  for op in plugin.ops {
    ignore(self.apply_plugin_op(op))
  }
  self
}

///|
fn RuleRegistry::apply_plugin_op(
  self : RuleRegistry,
  op : PluginOp,
) -> RuleRegistry {
  match op {
    AddRule(rule) => self.register(rule)
    DisableRule(name) => self.disable(name)
    EnableRule(name) => self.enable(name)
    OverrideRule(rule) => self.override_rule(rule)
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
fn RuleRegistry::override_rule(
  self : RuleRegistry,
  rule : Rule,
) -> RuleRegistry {
  self.remember_override(rule)
  self.override_registered(rule)
}

///|
fn RuleRegistry::remember_override(self : RuleRegistry, rule : Rule) -> Unit {
  let next : Array[Rule] = []
  for old in self.overrides {
    if old.name != rule.name {
      next.push(old)
    }
  }
  next.push(rule)
  self.overrides = next
}

///|
fn RuleRegistry::override_for(self : RuleRegistry, name : RuleName) -> Rule? {
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
  rule : Rule,
) -> RuleRegistry {
  let next : Array[Rule] = []
  for old in self.rules {
    if old.name != rule.name {
      next.push(old)
    }
  }
  self.rules = next
  self.register_raw(rule)
}

///|
fn RuleRegistry::block_rules(self : RuleRegistry) -> Array[Rule] {
  self.rules_for(BlockStart)
}

///|
fn RuleRegistry::block_continue_rules(self : RuleRegistry) -> Array[Rule] {
  self.rules_for(BlockContinue)
}

///|
fn RuleRegistry::inline_rules(self : RuleRegistry) -> Array[Rule] {
  self.rules_for(Inline)
}

///|
fn RuleRegistry::delimiter_rules(self : RuleRegistry) -> Array[Rule] {
  self.rules_for(Delimiter)
}

///|
fn RuleRegistry::core_rules(self : RuleRegistry) -> Array[Rule] {
  self.rules_for(Core)
}

///|
fn RuleRegistry::inline_parse_rules(self : RuleRegistry) -> Array[Rule] {
  let rules = self.delimiter_rules()
  for rule in self.inline_rules() {
    rules.push(rule)
  }
  rules
}

///|
fn RuleRegistry::has_enabled_block_rules(self : RuleRegistry) -> Bool {
  for rule in self.rules {
    if rule.chain == BlockStart &&
      !array_contains_string(self.disabled, rule.name) {
      return true
    }
  }
  false
}

///|
fn RuleRegistry::has_commonmark_block_rules_only(self : RuleRegistry) -> Bool {
  if self.overrides.length() > 0 {
    return false
  }
  let mut count = 0
  for rule in self.rules {
    if rule.chain == BlockContinue {
      return false
    }
    if rule.chain == BlockStart {
      if array_contains_string(self.disabled, rule.name) ||
        !is_commonmark_block_rule_name(rule.name) {
        return false
      }
      count = count + 1
    }
  }
  count == 10
}

///|
fn RuleRegistry::has_commonmark_preset_only(self : RuleRegistry) -> Bool {
  if self.overrides.length() > 0 || self.disabled.length() > 0 {
    return false
  }
  let mut count = 0
  for rule in self.rules {
    if !is_commonmark_rule_name(rule.name) {
      return false
    }
    count = count + 1
  }
  count == 22
}

///|
fn is_commonmark_rule_name(name : RuleName) -> Bool {
  name.value == "cm:core:reference_definitions" ||
  is_commonmark_block_rule_name(name) ||
  name.value == "cm:inline:image" ||
  name.value == "cm:inline:link" ||
  name.value == "cm:inline:autolink" ||
  name.value == "cm:inline:raw_html" ||
  name.value == "cm:inline:entity" ||
  name.value == "cm:inline:code_span" ||
  name.value == "cm:delimiter:emphasis" ||
  name.value == "cm:inline:hard_break" ||
  name.value == "cm:inline:escape" ||
  name.value == "cm:inline:soft_break" ||
  name.value == "cm:inline:text"
}

///|
fn is_commonmark_block_rule_name(name : RuleName) -> Bool {
  name.value == "cm:block:blank" ||
  name.value == "cm:block:fenced_code" ||
  name.value == "cm:block:indented_code" ||
  name.value == "cm:block:thematic_break" ||
  name.value == "cm:block:setext_heading" ||
  name.value == "cm:block:html" ||
  name.value == "cm:block:atx_heading" ||
  name.value == "cm:block:block_quote" ||
  name.value == "cm:block:list" ||
  name.value == "cm:block:paragraph"
}

///|
fn RuleRegistry::rules_for(
  self : RuleRegistry,
  chain : RuleChain,
) -> Array[Rule] {
  let selected : Array[Rule] = []
  for rule in self.rules {
    if rule.chain == chain && !array_contains_string(self.disabled, rule.name) {
      selected.push(rule)
    }
  }
  selected
}

///|
fn sort_rules(rules : Array[Rule]) -> Unit {
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
fn apply_rule_edges(rules : Array[Rule]) -> Unit {
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
fn rule_less(left : Rule, right : Rule) -> Bool {
  if left.priority != right.priority {
    left.priority > right.priority
  } else {
    left.order < right.order
  }
}

///|
fn find_rule_index(
  rules : Array[Rule],
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
fn move_rule(rules : Array[Rule], from : Int, to : Int) -> Unit {
  let rule = rules[from]
  if from < to {
    for i in from..<to {
      rules[i] = rules[i + 1]
    }
  } else {
    for i = from; i > to; i = i - 1 {
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
fn copy_rules(rules : Array[Rule]) -> Array[Rule] {
  let copied : Array[Rule] = []
  for rule in rules {
    copied.push({
      name: rule.name,
      chain: rule.chain,
      before: copy_rule_names(rule.before),
      after: copy_rule_names(rule.after),
      priority: rule.priority,
      order: rule.order,
      block: rule.block,
      inline: rule.inline,
      core: rule.core,
      source_core: rule.source_core,
    })
  }
  copied
}

///|
fn copy_plugin_ops(ops : Array[PluginOp]) -> Array[PluginOp] {
  let copied : Array[PluginOp] = []
  for op in ops {
    copied.push(op)
  }
  copied
}
