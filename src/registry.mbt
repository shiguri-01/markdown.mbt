///|
priv enum RuleChain {
  BlockContinue
  BlockStart
  Inline
  Delimiter
  Core
} derive(Eq)

///|
/// A sink used by rules to append parser events.
pub struct EventSink {
  priv events : Array[Event]
}

///|
/// Emits an event from a rule.
pub fn EventSink::emit(self : EventSink, event : Event) -> Unit {
  self.events.push(event)
}

///|
/// Context passed to block rules.
pub struct BlockContext {
  priv lines : Array[String]
  priv line_starts : Array[Int]
  priv index : Int
  priv registry : RuleRegistry
}

///|
/// Context passed to inline and delimiter rules.
pub struct InlineContext {
  priv text : String
  priv index : Int
  priv scanner : InlineScanner
  priv registry : RuleRegistry
}

///|
/// Returns the line currently being considered by a block rule.
pub fn BlockContext::current_line(self : BlockContext) -> String {
  if self.index >= 0 && self.index < self.lines.length() {
    self.lines[self.index]
  } else {
    ""
  }
}

///|
/// Returns the source line at `index`, if it exists.
pub fn BlockContext::line_at(self : BlockContext, index : Int) -> String? {
  if index >= 0 && index < self.lines.length() {
    Some(self.lines[index])
  } else {
    None
  }
}

///|
/// Returns the current zero-based source line index.
pub fn BlockContext::line_index(self : BlockContext) -> Int {
  self.index
}

///|
/// Returns the byte offset where the current source line starts.
pub fn BlockContext::current_line_start(self : BlockContext) -> Int {
  if self.index >= 0 && self.index < self.line_starts.length() {
    self.line_starts[self.index]
  } else {
    0
  }
}

///|
/// Returns the full inline source being scanned.
pub fn InlineContext::source(self : InlineContext) -> String {
  self.text
}

///|
/// Returns the current byte offset in the inline source.
pub fn InlineContext::offset(self : InlineContext) -> Int {
  self.index
}

///|
/// Returns a scanner positioned at the current inline offset.
pub fn InlineContext::scanner(self : InlineContext) -> InlineScanner {
  self.scanner
}

///|
/// A small scanner for inline rule implementations.
pub struct InlineScanner {
  priv text : String
  priv index : Int
}

///|
/// Creates an inline scanner positioned at `index`.
pub fn InlineScanner::new(text : String, index : Int) -> InlineScanner? {
  if index < 0 || index > text.length() {
    None
  } else {
    Some(inline_scanner(text, index))
  }
}

///|
fn inline_scanner(text : String, index : Int) -> InlineScanner {
  { text, index }
}

///|
/// Returns whether the scanner position starts with `prefix`.
pub fn InlineScanner::has_prefix(self : InlineScanner, prefix : String) -> Bool {
  self.index >= 0 &&
  self.index + prefix.length() <= self.text.length() &&
  self.text[self.index:self.index + prefix.length()].to_owned() == prefix
}

///|
/// Returns the character code at the scanner position.
pub fn InlineScanner::char(self : InlineScanner) -> Int? {
  if self.index >= 0 && self.index < self.text.length() {
    Some(self.text[self.index].to_int())
  } else {
    None
  }
}

///|
/// Returns the character code at an offset from the scanner position.
pub fn InlineScanner::char_at_offset(
  self : InlineScanner,
  offset : Int,
) -> Int? {
  let target = self.index + offset
  if target >= 0 && target < self.text.length() {
    Some(self.text[target].to_int())
  } else {
    None
  }
}

///|
/// Returns a slice relative to the scanner position.
pub fn InlineScanner::slice(
  self : InlineScanner,
  start_offset : Int,
  end_offset : Int,
) -> String? {
  let start = self.index + start_offset
  let end = self.index + end_offset
  if start < 0 || end < start || end > self.text.length() {
    None
  } else {
    Some(self.text[start:end].to_owned())
  }
}

///|
/// Finds `needle` from the scanner position and returns a relative offset.
pub fn InlineScanner::find_char(self : InlineScanner, needle : Int) -> Int? {
  for i in self.index..<self.text.length() {
    if self.text[i].to_int() == needle {
      return Some(i - self.index)
    }
  }
  None
}

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
/// A core rule transforms a complete event stream.
pub type CoreRuleFn = (Array[Event]) -> Array[Event]

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
