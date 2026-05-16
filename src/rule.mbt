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
