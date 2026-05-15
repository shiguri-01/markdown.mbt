///|
pub type TagName = String

///|
pub type RuleName = String

///|
pub type TextSpan = String

///|
pub type StringView = String

///|
pub(all) struct SourceRange {
  start : Int
  end : Int
}

///|
pub(all) struct Attr {
  name : String
  value : String
}

///|
pub(all) struct Element {
  tag : TagName
  attrs : Array[Attr]
  range : SourceRange?
}

///|
pub(all) enum Event {
  Enter(Element)
  Exit(TagName)
  Text(TextSpan)
  SoftBreak
  HardBreak
  Html(StringView)
}

///|
pub fn element(tag : TagName) -> Element {
  { tag, attrs: [], range: None }
}

///|
pub fn element_with_attrs(
  tag : TagName,
  attrs : Array[Attr],
  range? : SourceRange? = None,
) -> Element {
  { tag, attrs, range }
}
