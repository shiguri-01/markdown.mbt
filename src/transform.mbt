///|
/// Creates a sink that runs `f` before finishing downstream.
pub fn EventSink::on_finish(
  self : EventSink,
  f : (EventSink) -> Unit,
) -> EventSink {
  EventSink::new(fn(event) { self.emit(event) }, finish=fn() {
    f(self)
    self.finish()
  })
}

///|
/// Creates a sink that maps every event before forwarding it downstream.
pub fn EventSink::map(self : EventSink, f : (Event) -> Event) -> EventSink {
  EventSink::new(fn(event) { self.emit(copy_event(f(event))) }, finish=fn() {
    self.finish()
  })
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
/// Creates a sink that rewrites every `SoftBreak` event to `HardBreak`.
pub fn EventSink::softbreak_to_hardbreak(self : EventSink) -> EventSink {
  self.map(fn(event) {
    match event {
      SoftBreak => HardBreak
      _ => event
    }
  })
}

///|
/// Creates a sink that renames matching `Enter` and `Exit` tags.
pub fn EventSink::rename_tag(
  self : EventSink,
  from : Tag,
  to : Tag,
) -> EventSink {
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
/// Creates a sink that appends an attribute to matching `Enter` elements.
pub fn EventSink::inject_attr(
  self : EventSink,
  tag : Tag,
  attr : Attr,
) -> EventSink {
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
