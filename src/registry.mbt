///|
enum RuleChain {
  BlockContinue
  BlockStart
  Inline
  Delimiter
  Core
} derive(Eq)

///|
pub struct EventSink {
  priv events : Array[Event]
}

///|
pub fn EventSink::emit(self : EventSink, event : Event) -> Unit {
  self.events.push(event)
}

///|
pub struct BlockContext {
  priv lines : Array[String]
  priv line_starts : Array[Int]
  priv index : Int
  priv registry : RuleRegistry
}

///|
pub struct InlineContext {
  priv text : String
  priv index : Int
  priv scanner : InlineScanner
  priv registry : RuleRegistry
}

///|
pub fn BlockContext::current_line(self : BlockContext) -> String {
  if self.index >= 0 && self.index < self.lines.length() {
    self.lines[self.index]
  } else {
    ""
  }
}

///|
pub fn BlockContext::line_at(self : BlockContext, index : Int) -> String? {
  if index >= 0 && index < self.lines.length() {
    Some(self.lines[index])
  } else {
    None
  }
}

///|
pub fn BlockContext::line_index(self : BlockContext) -> Int {
  self.index
}

///|
pub fn BlockContext::current_line_start(self : BlockContext) -> Int {
  if self.index >= 0 && self.index < self.line_starts.length() {
    self.line_starts[self.index]
  } else {
    0
  }
}

///|
pub fn InlineContext::source(self : InlineContext) -> String {
  self.text
}

///|
pub fn InlineContext::offset(self : InlineContext) -> Int {
  self.index
}

///|
pub fn InlineContext::scanner(self : InlineContext) -> InlineScanner {
  self.scanner
}

///|
pub struct InlineScanner {
  priv text : String
  priv index : Int
}

///|
pub fn InlineScanner::new(text : String, index : Int) -> InlineScanner {
  { text, index }
}

///|
pub fn InlineScanner::has_prefix(self : InlineScanner, prefix : String) -> Bool {
  self.index + prefix.length() <= self.text.length() &&
  self.text[self.index:self.index + prefix.length()].to_owned() == prefix
}

///|
pub fn InlineScanner::char(self : InlineScanner) -> Int? {
  if self.index < self.text.length() {
    Some(self.text[self.index].to_int())
  } else {
    None
  }
}

///|
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
pub fn InlineScanner::slice(
  self : InlineScanner,
  start_offset : Int,
  end_offset : Int,
) -> String {
  let start = self.index + start_offset
  let end = self.index + end_offset
  if start < 0 || end < start || end > self.text.length() {
    ""
  } else {
    self.text[start:end].to_owned()
  }
}

///|
pub fn InlineScanner::find_char(self : InlineScanner, needle : Int) -> Int {
  for i in self.index..<self.text.length() {
    if self.text[i].to_int() == needle {
      return i - self.index
    }
  }
  -1
}

///|
pub type BlockRuleFn = (BlockContext, EventSink) -> Int

///|
pub type InlineRuleFn = (InlineContext, EventSink) -> Int

///|
pub type CoreRuleFn = (Array[Event]) -> Array[Event]

///|
type SourceCoreRuleFn = (String) -> String

///|
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
pub struct Plugin {
  priv name : String
  priv rules : Array[Rule]
}

///|
struct RuleRegistry {
  mut rules : Array[Rule]
  mut disabled : Array[RuleName]
  mut next_order : Int
}

///|
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
    before,
    after,
    priority,
    order: 0,
    block: Some(f),
    inline: None,
    core: None,
    source_core: None,
  }
}

///|
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
    before,
    after,
    priority,
    order: 0,
    block: Some(f),
    inline: None,
    core: None,
    source_core: None,
  }
}

///|
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
    before,
    after,
    priority,
    order: 0,
    block: None,
    inline: Some(f),
    core: None,
    source_core: None,
  }
}

///|
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
    before,
    after,
    priority,
    order: 0,
    block: None,
    inline: Some(f),
    core: None,
    source_core: None,
  }
}

///|
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
    before,
    after,
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
    before,
    after,
    priority,
    order: 0,
    block: None,
    inline: None,
    core: None,
    source_core: Some(f),
  }
}

///|
pub fn Plugin::new(name : String) -> Plugin {
  { name, rules: [] }
}

///|
pub fn Plugin::name(self : Plugin) -> String {
  self.name
}

///|
pub fn Plugin::add(self : Plugin, rule : Rule) -> Plugin {
  self.rules.push(rule)
  self
}

///|
fn RuleRegistry::new() -> RuleRegistry {
  { rules: [], disabled: [], next_order: 0 }
}

///|
fn RuleRegistry::register(self : RuleRegistry, rule : Rule) -> RuleRegistry {
  let r = {
    name: rule.name,
    chain: rule.chain,
    before: rule.before,
    after: rule.after,
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
  for rule in plugin.rules {
    ignore(self.register(rule))
  }
  self
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
fn RuleRegistry::replace(self : RuleRegistry, rule : Rule) -> RuleRegistry {
  let next : Array[Rule] = []
  for old in self.rules {
    if old.name != rule.name {
      next.push(old)
    }
  }
  self.rules = next
  self.register(rule)
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
