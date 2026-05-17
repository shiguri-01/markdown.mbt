///|
/// Creates a sink that runs `f` before finishing downstream.
pub fn Sink::on_finish(self : Sink, f : (Sink) -> Unit) -> Sink {
  Sink::new(fn(event) { self.emit(event) }, finish=fn() {
    f(self)
    self.finish()
  })
}

///|
/// Creates a sink that maps every event before forwarding it downstream.
pub fn Sink::map(self : Sink, f : (Event) -> Event) -> Sink {
  Sink::new(fn(event) { self.emit(copy_event(f(event))) }, finish=fn() {
    self.finish()
  })
}

///|
/// Creates a sink that merges adjacent `Text` events before forwarding.
pub fn Sink::text_merge(self : Sink) -> Sink {
  let mut pending : String? = None
  Sink::new(
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
pub fn Sink::softbreak_to_hardbreak(self : Sink) -> Sink {
  self.map(fn(event) {
    match event {
      SoftBreak => HardBreak
      _ => event
    }
  })
}

///|
/// Creates a sink that renames matching `Enter` and `Exit` tags.
pub fn Sink::rename_tag(self : Sink, from : Tag, to : Tag) -> Sink {
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
pub fn Sink::inject_attr(self : Sink, tag : Tag, attr : Attr) -> Sink {
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
