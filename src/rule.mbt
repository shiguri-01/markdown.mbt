///|
priv enum RuleChain {
  BlockContinue
  BlockStart
  Inline
  Delimiter
  Core
} derive(Eq)

///|
/// A positive count of inline source characters consumed by a matched rule.
pub struct ConsumedChars {
  priv value : Int
}

///|
/// Creates a positive consumed-character count.
pub fn ConsumedChars::ConsumedChars(value : Int) -> ConsumedChars {
  if value <= 0 {
    abort("ConsumedChars must be positive")
  }
  { value, }
}

///|
/// Returns the consumed-character count.
pub fn ConsumedChars::to_int(self : ConsumedChars) -> Int {
  self.value
}

///|
/// A positive count of block source lines consumed by a matched rule.
pub struct ConsumedLines {
  priv value : Int
}

///|
/// Creates a positive consumed-line count.
pub fn ConsumedLines::ConsumedLines(value : Int) -> ConsumedLines {
  if value <= 0 {
    abort("ConsumedLines must be positive")
  }
  { value, }
}

///|
/// Returns the consumed-line count.
pub fn ConsumedLines::to_int(self : ConsumedLines) -> Int {
  self.value
}

///|
pub(all) enum InlineRuleResult {
  NoMatch
  Match(ConsumedChars)
}

///|
pub(all) enum BlockRuleResult {
  NoMatch
  Match(ConsumedLines, EventFragment)
}

///|
/// A block rule consumes source lines and returns events for accepted matches.
pub type BlockRuleFn = (BlockContext) -> BlockRuleResult

///|
/// An inline rule consumes characters from inline source and emits events for accepted matches.
pub type InlineRuleFn = (InlineContext, Sink) -> InlineRuleResult

///|
/// A core rule wraps a downstream sink with stream transformation behavior.
pub type CoreRuleFn = (Sink) -> Sink

///|
/// An atomic parser entry installed into the rule registry.
priv struct RuleEntry {
  name : RuleName
  chain : RuleChain
  before : Array[RuleName]
  after : Array[RuleName]
  priority : Int
  order : Int
  triggers : String
  block : BlockRuleFn?
  inline : InlineRuleFn?
  core : CoreRuleFn?
}

///|
priv enum InlineParseMode {
  CustomInlinePipeline
}

///|
priv enum RuleOp {
  RegisterRule(RuleEntry)
  DisableRule(RuleName)
  EnableRule(RuleName)
  ReplaceRule(RuleEntry)
}

///|
/// A composable Markdown syntax rule.
///
/// A rule can be a single block, inline, delimiter, or core parser entry, or a
/// larger rule made by composing smaller rules. Rules preserve operation order
/// when composed, so a rule can model one extension or a whole rule.
pub struct Rule {
  priv name : String
  priv ops : Array[RuleOp]
}

///|
/// Creates an empty composable rule.
pub fn Rule::Rule(name : String) -> Rule {
  { name, ops: [] }
}

///|
/// Returns the rule name.
pub fn Rule::name(self : Rule) -> String {
  self.name
}

///|
/// Creates a block-start rule.
pub fn Rule::block(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  triggers? : String = "",
  f : BlockRuleFn,
) -> Rule {
  Rule::from_entry({
    name,
    chain: BlockStart,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    triggers,
    block: Some(f),
    inline: None,
    core: None,
  })
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
  triggers? : String = "",
  f : BlockRuleFn,
) -> Rule {
  Rule::from_entry({
    name,
    chain: BlockContinue,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    triggers,
    block: Some(f),
    inline: None,
    core: None,
  })
}

///|
/// Creates an inline rule.
pub fn Rule::inline(
  name : RuleName,
  priority? : Int = 0,
  before? : Array[RuleName] = [],
  after? : Array[RuleName] = [],
  triggers? : String = "",
  f : InlineRuleFn,
) -> Rule {
  Rule::from_entry({
    name,
    chain: Inline,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    triggers,
    block: None,
    inline: Some(f),
    core: None,
  })
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
  triggers? : String = "",
  f : InlineRuleFn,
) -> Rule {
  Rule::from_entry({
    name,
    chain: Delimiter,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    triggers,
    block: None,
    inline: Some(f),
    core: None,
  })
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
  Rule::from_entry({
    name,
    chain: Core,
    before: copy_rule_names(before),
    after: copy_rule_names(after),
    priority,
    order: 0,
    triggers: "",
    block: None,
    inline: None,
    core: Some(f),
  })
}

///|
fn Rule::from_entry(entry : RuleEntry) -> Rule {
  { name: entry.name.to_string(), ops: [RegisterRule(entry)] }
}

///|
/// Appends all operations from `rule` to this rule.
pub fn Rule::extend(self : Rule, rule : Rule) -> Rule {
  let ops = copy_rule_ops(self.ops)
  for op in rule.ops {
    ops.push(copy_rule_op(op))
  }
  { name: self.name, ops }
}

///|
/// Disables a named parser entry when this rule is installed.
pub fn Rule::disable(self : Rule, name : RuleName) -> Rule {
  let ops = copy_rule_ops(self.ops)
  ops.push(DisableRule(name))
  { name: self.name, ops }
}

///|
/// Re-enables a named parser entry when this rule is installed.
pub fn Rule::enable(self : Rule, name : RuleName) -> Rule {
  let ops = copy_rule_ops(self.ops)
  ops.push(EnableRule(name))
  { name: self.name, ops }
}

///|
/// Replaces parser entries with the same names as entries in `rule`.
///
/// Replacements are remembered by the registry, so they apply to both current
/// and later matching entries from composed rules. If no base entry is ever
/// registered, the replacement rule still participates as an ordinary rule.
pub fn Rule::replace(self : Rule, rule : Rule) -> Rule {
  let ops = copy_rule_ops(self.ops)
  for op in rule.ops {
    match op {
      RegisterRule(entry) => ops.push(ReplaceRule(copy_rule_entry(entry)))
      ReplaceRule(entry) => ops.push(ReplaceRule(copy_rule_entry(entry)))
      DisableRule(name) => ops.push(DisableRule(name))
      EnableRule(name) => ops.push(EnableRule(name))
    }
  }
  { name: self.name, ops }
}

///|
