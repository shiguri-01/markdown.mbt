///|
/// A Markdown element tag used by events, renderers, and transforms.
///
/// CommonMark tags use the `cm:` namespace. Extension authors should use a
/// custom namespace or an agreed raw value to avoid collisions.
pub struct Tag {
  priv value : String
} derive(Eq)

///|
/// An element attribute name.
///
/// CommonMark attributes such as `level`, `destination`, and `title` are
/// unqualified. Extension attributes can use a custom namespace.
pub struct AttrName {
  priv value : String
} derive(Eq)

///|
/// Text payload carried by `Event::Text`.
pub type TextSpan = String

///|
/// A rule identifier used for ordering, override, enable, and disable.
///
/// Built-in CommonMark rules use the `cm:` namespace.
pub struct RuleName {
  priv value : String
} derive(Eq)

///|
/// Creates a CommonMark tag by prefixing `name` with `cm:`.
pub fn Tag::commonmark(name : String) -> Tag {
  { value: "cm:" + name }
}

///|
/// Creates an extension tag from `ns` and `name` as `ns:name`.
pub fn Tag::custom(ns : String, name : String) -> Tag {
  { value: ns + ":" + name }
}

///|
/// Creates a tag from an already-qualified value.
pub fn Tag::raw(value : String) -> Tag {
  { value, }
}

///|
/// Returns the tag value used in events and rendered extension HTML.
pub fn Tag::to_string(self : Tag) -> String {
  self.value
}

///|
/// Creates a CommonMark attribute name.
///
/// Attribute names are not prefixed with `cm:` because they are interpreted in
/// the context of their element tag.
pub fn AttrName::commonmark(name : String) -> AttrName {
  { value: name }
}

///|
/// Creates an extension attribute name from `ns` and `name` as `ns:name`.
pub fn AttrName::custom(ns : String, name : String) -> AttrName {
  { value: ns + ":" + name }
}

///|
/// Creates an attribute name from an already-qualified value.
pub fn AttrName::raw(value : String) -> AttrName {
  { value, }
}

///|
/// Returns the attribute name value used by renderers.
pub fn AttrName::to_string(self : AttrName) -> String {
  self.value
}

///|
/// Creates a CommonMark rule name by prefixing `name` with `cm:`.
pub fn RuleName::commonmark(name : String) -> RuleName {
  { value: "cm:" + name }
}

///|
/// Creates an extension rule name from `ns` and `name` as `ns:name`.
pub fn RuleName::custom(ns : String, name : String) -> RuleName {
  { value: ns + ":" + name }
}

///|
/// Creates a rule name from an already-qualified value.
pub fn RuleName::raw(value : String) -> RuleName {
  { value, }
}

///|
/// Returns the rule name value used by `Processor` rule controls.
pub fn RuleName::to_string(self : RuleName) -> String {
  self.value
}

///|
fn tag_name(value : String) -> Tag {
  { value, }
}

///|
fn attr_name(value : String) -> AttrName {
  { value, }
}

///|
fn rule_name(value : String) -> RuleName {
  { value, }
}

///|
/// A byte offset range in the original Markdown source.
///
/// `start` is inclusive and `end` is exclusive.
pub struct SourceRange {
  priv start : Int
  priv end : Int
}

///|
/// Creates a source range from inclusive `start` and exclusive `end` offsets.
pub fn SourceRange::new(start : Int, end : Int) -> SourceRange {
  { start, end }
}

///|
/// Returns the inclusive start byte offset.
pub fn SourceRange::start(self : SourceRange) -> Int {
  self.start
}

///|
/// Returns the exclusive end byte offset.
pub fn SourceRange::end(self : SourceRange) -> Int {
  self.end
}

///|
/// An attribute attached to an `Element`.
pub struct Attr {
  priv name : AttrName
  priv value : String
}

///|
/// A Markdown event element.
///
/// Elements carry a tag, attributes, and an optional source range. Extension
/// authors can construct elements with custom tags and attributes.
pub struct Element {
  priv tag : Tag
  priv attrs : Array[Attr]
  priv range : SourceRange?
}

///|
/// A parser event stream.
///
/// `Enter` and `Exit` delimit elements by tag. `Text`, breaks, and raw HTML are
/// leaf events. Extension tags are preserved by the parser, renderer, AST
/// builder, and transforms.
pub(all) enum Event {
  Enter(Element)
  Exit(Tag)
  Text(TextSpan)
  SoftBreak
  HardBreak
  Html(String)
}

///|
/// Creates an attribute.
pub fn attr(name : AttrName, value : String) -> Attr {
  { name, value }
}

///|
/// Returns the attribute name.
pub fn Attr::name(self : Attr) -> AttrName {
  self.name
}

///|
/// Returns the attribute value.
pub fn Attr::value(self : Attr) -> String {
  self.value
}

///|
/// Creates an element without attributes or source range.
pub fn element(tag : Tag) -> Element {
  { tag, attrs: [], range: None }
}

///|
/// Creates an element with attributes and an optional source range.
///
/// The attribute array is stored as provided.
pub fn element_with_attrs(
  tag : Tag,
  attrs : Array[Attr],
  range? : SourceRange? = None,
) -> Element {
  { tag, attrs, range }
}

///|
/// Returns the element tag.
pub fn Element::tag(self : Element) -> Tag {
  self.tag
}

///|
/// Returns the element attributes.
///
/// The returned array is the element's stored array.
pub fn Element::attrs(self : Element) -> Array[Attr] {
  self.attrs
}

///|
/// Returns the source range attached to the element, if any.
pub fn Element::range(self : Element) -> SourceRange? {
  self.range
}
