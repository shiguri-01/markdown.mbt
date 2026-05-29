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
/// A parser source range measured in MoonBit string offsets.
///
/// `start` is inclusive and `end` is exclusive.
/// These offsets are compatible with the parser's `String` indexing and line
/// normalization; they are not UTF-8 byte offsets.
pub struct SourceRange {
  priv start : Int
  priv end : Int
}

///|
/// Creates a source range from inclusive `start` and exclusive `end` parser
/// offsets.
pub fn SourceRange::new(
  start : Int,
  end : Int,
) -> SourceRange? where {
  proof_ensure: result => {
    match result {
      Some(range) =>
        range.start == start &&
        range.end == end &&
        range.start >= 0 &&
        range.end >= range.start
      None => start < 0 || end < start
    }
  },
} {
  if start < 0 || end < start {
    None
  } else {
    Some(source_range(start, end))
  }
}

///|
/// Returns the inclusive start parser offset.
pub fn SourceRange::start(self : SourceRange) -> Int {
  self.start
}

///|
/// Returns the exclusive end parser offset.
pub fn SourceRange::end(self : SourceRange) -> Int {
  self.end
}

///|
fn source_range(
  start : Int,
  end : Int,
) -> SourceRange where {
  proof_require: start >= 0 && end >= start,
  proof_ensure: result => result.start == start && result.end == end,
} {
  { start, end }
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
  Text(String)
  SoftBreak
  HardBreak
  RawHtml(String)
}

///|
/// Creates an attribute.
pub fn Attr::Attr(name : AttrName, value : String) -> Attr {
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
pub fn Element::Element(tag : Tag) -> Element {
  { tag, attrs: [], range: None }
}

///|
/// Creates an element with attributes and an optional source range.
pub fn Element::with_attrs(
  tag : Tag,
  attrs : Array[Attr],
  range? : SourceRange? = None,
) -> Element {
  { tag, attrs: copy_attrs(attrs), range }
}

///|
/// Returns the element tag.
pub fn Element::tag(self : Element) -> Tag {
  self.tag
}

///|
/// Returns the element attributes.
pub fn Element::attrs(self : Element) -> Array[Attr] {
  copy_attrs(self.attrs)
}

///|
/// Returns the first attribute value for `name`, if present.
pub fn Element::attr(self : Element, name : AttrName) -> String? {
  for attr in self.attrs {
    if attr.name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
/// Returns the source range attached to the element, if any.
pub fn Element::range(self : Element) -> SourceRange? {
  self.range
}

///|
fn copy_attrs(attrs : Array[Attr]) -> Array[Attr] {
  let copied : Array[Attr] = []
  for attr in attrs {
    copied.push(attr)
  }
  copied
}

///|
fn copy_element(el : Element) -> Element {
  { tag: el.tag, attrs: copy_attrs(el.attrs), range: el.range }
}

///|
fn copy_event(event : Event) -> Event {
  match event {
    Enter(el) => Enter(copy_element(el))
    Exit(tag) => Exit(tag)
    Text(text) => Text(text)
    SoftBreak => SoftBreak
    HardBreak => HardBreak
    RawHtml(raw) => RawHtml(raw)
  }
}

///|
fn copy_events(events : Array[Event]) -> Array[Event] {
  let copied : Array[Event] = []
  for event in events {
    copied.push(copy_event(event))
  }
  copied
}

///|
/// A balanced event sequence produced by a parser rule.
pub struct EventFragment {
  priv events : Array[Event]
}

///|
/// Creates an empty event fragment.
pub fn EventFragment::empty() -> EventFragment {
  { events: [] }
}

///|
/// Creates a text event fragment.
pub fn EventFragment::text(text : String) -> EventFragment {
  { events: [Text(text)] }
}

///|
/// Creates a soft-break event fragment.
pub fn EventFragment::soft_break() -> EventFragment {
  { events: [SoftBreak] }
}

///|
/// Creates a hard-break event fragment.
pub fn EventFragment::hard_break() -> EventFragment {
  { events: [HardBreak] }
}

///|
/// Creates a raw HTML event fragment.
pub fn EventFragment::html(raw : String) -> EventFragment {
  { events: [RawHtml(raw)] }
}

///|
/// Creates a balanced element event fragment.
pub fn EventFragment::element(
  element : Element,
  children? : Array[EventFragment] = [],
) -> EventFragment {
  let events : Array[Event] = [Enter(copy_element(element))]
  for child in children {
    for event in child.events {
      events.push(copy_event(event))
    }
  }
  events.push(Exit(element.tag))
  { events, }
}

///|
/// Concatenates event fragments.
pub fn EventFragment::concat(fragments : Array[EventFragment]) -> EventFragment {
  let events : Array[Event] = []
  for fragment in fragments {
    for event in fragment.events {
      events.push(copy_event(event))
    }
  }
  { events, }
}

///|
/// Creates a fragment from events if all element enter/exit pairs are balanced.
pub fn EventFragment::from_events(events : Array[Event]) -> EventFragment? {
  match validate_balanced_events(events) {
    true => Some({ events: copy_events(events) })
    false => None
  }
}

///|
fn event_fragment_from_owned_events(events : Array[Event]) -> EventFragment? {
  match validate_balanced_events(events) {
    true => Some({ events, })
    false => None
  }
}

///|
fn validate_balanced_events(events : Array[Event]) -> Bool {
  let stack : Array[Tag] = []
  for event in events {
    match event {
      Enter(element) => stack.push(element.tag)
      Exit(tag) => {
        if stack.length() == 0 {
          return false
        }
        let top = stack[stack.length() - 1]
        if top != tag {
          return false
        }
        ignore(stack.pop())
      }
      _ => ()
    }
  }
  stack.length() == 0
}

///|
/// Returns a copy of the events in this fragment.
pub fn EventFragment::events(self : EventFragment) -> Array[Event] {
  copy_events(self.events)
}

///|
fn EventFragment::emit_to(self : EventFragment, sink : Sink) -> Unit {
  for event in self.events {
    sink.emit(copy_event(event))
  }
}

///|
/// A downstream sink that collects events into an array.
pub struct Events {
  priv events : Array[Event]
}

///|
/// Creates an empty event collector.
pub fn Events::Events() -> Events {
  { events: [] }
}

///|
/// Returns a sink that appends emitted events to this collector.
pub fn Events::sink(self : Events) -> Sink {
  Sink(fn(event) { self.events.push(copy_event(event)) })
}

///|
pub fn Events::owned_sink(self : Events) -> Sink {
  Sink(fn(event) { self.events.push(event) })
}

///|
/// Returns a copy of collected events.
pub fn Events::collect(self : Events) -> Array[Event] {
  copy_events(self.events)
}

///|
pub fn Events::owned_events(self : Events) -> Array[Event] {
  self.events
}

///|
pub fn Events::into_fragment(self : Events) -> EventFragment {
  match event_fragment_from_owned_events(self.events) {
    Some(fragment) => fragment
    None => EventFragment::empty()
  }
}
