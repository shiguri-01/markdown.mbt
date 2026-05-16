///|
/// A chainable event stream transformer.
pub struct Transform {
  priv events : Array[Event]
}

///|
/// Creates a transform from an event array.
pub fn Transform::new(events : Array[Event]) -> Transform {
  { events: copy_events(events) }
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
  copy_events(self.events)
}

///|
/// Creates a sink that appends `suffix` after upstream parsing finishes.
pub fn EventSink::with_suffix(
  self : EventSink,
  suffix : Array[Event],
) -> EventSink {
  let copied = copy_events(suffix)
  EventSink::new(
    fn(event) { self.emit(event) },
    finish=fn() {
      for event in copied {
        self.emit(event)
      }
      self.finish()
    },
  )
}

///|
/// Creates a sink that maps every event before forwarding it downstream.
pub fn EventSink::map(self : EventSink, f : (Event) -> Event) -> EventSink {
  EventSink::new(
    fn(event) { self.emit(copy_event(f(event))) },
    finish=fn() { self.finish() },
  )
}

///|
/// Creates a sink that merges adjacent `Text` events before forwarding.
pub fn EventSink::text_merge(self : EventSink) -> EventSink {
  let mut pending : String? = None
  EventSink::new(
    fn(event) {
      match event {
        Text(text) =>
          match pending {
            Some(prev) => pending = Some(prev + text)
            None => pending = Some(text)
          }
        _ => {
          match pending {
            Some(text) => self.emit(Text(text))
            None => ()
          }
          pending = None
          self.emit(event)
        }
      }
    },
    finish=fn() {
      match pending {
        Some(text) => self.emit(Text(text))
        None => ()
      }
      pending = None
      self.finish()
    },
  )
}

///|
fn Transform::map(self : Transform, f : (Event) -> Event) -> Transform {
  let next : Array[Event] = []
  for event in self.events {
    next.push(copy_event(f(event)))
  }
  { events: next }
}
