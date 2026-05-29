///|
type Attr = @markdown.Attr

///|
type BlockContext = @markdown.BlockContext

///|
type BlockRuleResult = @markdown.BlockRuleResult

///|
type Event = @markdown.Event

///|
type EventFragment = @markdown.EventFragment

///|
type InlineContext = @markdown.InlineContext

///|
type InlineRuleResult = @markdown.InlineRuleResult

///|
type ParserServices = @markdown.ParserServices

///|
type Sink = @markdown.Sink

///|
type SourceRange = @markdown.SourceRange

///|
type StateKey = @markdown.StateKey

///|
type Tag = @markdown.Tag

///|
fn tag_name(value : String) -> Tag {
  @markdown.Tag::raw(value)
}

///|
fn attr(name : String, value : String) -> Attr {
  @markdown.Attr(@markdown.AttrName::raw(name), value)
}

///|
fn source_range(start : Int, end : Int) -> SourceRange {
  match @markdown.SourceRange::new(start, end) {
    Some(range) => range
    None => abort("invalid source range")
  }
}

///|
fn block_match(consumed : Int, fragment : EventFragment) -> BlockRuleResult {
  Match(@markdown.ConsumedLines(consumed), fragment)
}

///|
fn inline_match(consumed : Int, fragment : EventFragment) -> InlineRuleResult {
  Match(@markdown.ConsumedChars(consumed), fragment)
}
