///|
/// A chainable event stream transformer.
pub struct Transform {
  priv events : Array[Event]
}

///|
/// Creates a transform from an event array.
pub fn Transform::new(events : Array[Event]) -> Transform {
  { events, }
}

///|
/// Merges adjacent `Text` events.
pub fn Transform::text_merge(self : Transform) -> Transform {
  let merged : Array[Event] = []
  for event in self.events {
    match event {
      Text(text) =>
        if merged.length() > 0 {
          match merged[merged.length() - 1] {
            Text(prev) => merged[merged.length() - 1] = Text(prev + text)
            _ => merged.push(event)
          }
        } else {
          merged.push(event)
        }
      _ => merged.push(event)
    }
  }
  { events: merged }
}

///|
/// Rewrites every `SoftBreak` event to `HardBreak`.
pub fn Transform::softbreak_to_hardbreak(self : Transform) -> Transform {
  self.map(fn(event) {
    match event {
      SoftBreak => HardBreak
      _ => event
    }
  })
}

///|
/// Renames matching `Enter` and `Exit` tags.
///
/// Element attributes and source ranges are preserved.
pub fn Transform::rename_tag(
  self : Transform,
  from : Tag,
  to : Tag,
) -> Transform {
  self.map(fn(event) {
    match event {
      Enter(el) =>
        if el.tag == from {
          Enter({ tag: to, attrs: el.attrs, range: el.range })
        } else {
          event
        }
      Exit(tag) => if tag == from { Exit(to) } else { event }
      _ => event
    }
  })
}

///|
/// Appends an attribute to matching `Enter` elements.
///
/// Existing attributes and source ranges are preserved.
pub fn Transform::inject_attr(
  self : Transform,
  tag : Tag,
  attr : Attr,
) -> Transform {
  self.map(fn(event) {
    match event {
      Enter(el) =>
        if el.tag == tag {
          let attrs : Array[Attr] = []
          for old in el.attrs {
            attrs.push(old)
          }
          attrs.push(attr)
          Enter({ tag: el.tag, attrs, range: el.range })
        } else {
          event
        }
      _ => event
    }
  })
}

///|
/// Returns the transformed event array.
pub fn Transform::collect(self : Transform) -> Array[Event] {
  self.events
}

///|
fn Transform::map(self : Transform, f : (Event) -> Event) -> Transform {
  let next : Array[Event] = []
  for event in self.events {
    next.push(f(event))
  }
  { events: next }
}
