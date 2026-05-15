///|
pub struct Tag {
  priv value : String
} derive(Eq)

///|
pub struct AttrName {
  priv value : String
} derive(Eq)

///|
pub type TextSpan = String

///|
pub struct RuleName {
  priv value : String
} derive(Eq)

///|
pub fn Tag::commonmark(name : String) -> Tag {
  { value: "cm:" + name }
}

///|
pub fn Tag::custom(ns : String, name : String) -> Tag {
  { value: ns + ":" + name }
}

///|
pub fn Tag::raw(value : String) -> Tag {
  { value, }
}

///|
pub fn Tag::to_string(self : Tag) -> String {
  self.value
}

///|
pub fn AttrName::commonmark(name : String) -> AttrName {
  { value: name }
}

///|
pub fn AttrName::custom(ns : String, name : String) -> AttrName {
  { value: ns + ":" + name }
}

///|
pub fn AttrName::raw(value : String) -> AttrName {
  { value, }
}

///|
pub fn AttrName::to_string(self : AttrName) -> String {
  self.value
}

///|
pub fn RuleName::commonmark(name : String) -> RuleName {
  { value: "cm:" + name }
}

///|
pub fn RuleName::custom(ns : String, name : String) -> RuleName {
  { value: ns + ":" + name }
}

///|
pub fn RuleName::raw(value : String) -> RuleName {
  { value, }
}

///|
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
pub(all) struct SourceRange {
  start : Int
  end : Int
}

///|
pub(all) struct Attr {
  name : AttrName
  value : String
}

///|
pub(all) struct Element {
  tag : Tag
  attrs : Array[Attr]
  range : SourceRange?
}

///|
pub(all) enum Event {
  Enter(Element)
  Exit(Tag)
  Text(TextSpan)
  SoftBreak
  HardBreak
  Html(String)
}

///|
pub fn element(tag : Tag) -> Element {
  { tag, attrs: [], range: None }
}

///|
pub fn element_with_attrs(
  tag : Tag,
  attrs : Array[Attr],
  range? : SourceRange? = None,
) -> Element {
  { tag, attrs, range }
}
