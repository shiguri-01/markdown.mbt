///|
fn task_list_core(downstream : Sink) -> Sink {
  let mut buffering = false
  let mut depth = 0
  let buffer : Array[Event] = []
  Sink(
    fn(event) {
      if buffering {
        buffer.push(event)
        match event {
          @markdown.Enter(_) => depth = depth + 1
          @markdown.Exit(_) => depth = depth - 1
          _ => ()
        }
        if depth == 0 {
          emit_task_item_buffer(buffer, downstream)
          buffer.clear()
          buffering = false
        }
      } else {
        match event {
          @markdown.Enter(el) if el.tag().to_string() == "cm:item" => {
            buffering = true
            depth = 1
            buffer.push(event)
          }
          _ => downstream.emit(event)
        }
      }
    },
    finish=fn() {
      for event in buffer {
        downstream.emit(event)
      }
      buffer.clear()
      downstream.finish()
    },
  )
}

///|
fn emit_task_item_buffer(events : Array[Event], sink : Sink) -> Unit {
  mark_task_items(events)
  for event in events {
    sink.emit(event)
  }
}

///|
fn mark_task_items(events : Array[Event]) -> Unit {
  for i in 0..<events.length() {
    match events[i] {
      @markdown.Enter(el) if i == 0 && el.tag().to_string() == "cm:item" =>
        match detect_and_strip_task_marker(events, i, events.length()) {
          Some(checked) => events[i] = task_item_enter(el, checked)
          None => ()
        }
      @markdown.Enter(el) if el.tag().to_string() == "cm:item" => {
        let end = matching_item_end(events, i)
        match detect_and_strip_task_marker(events, i, end) {
          Some(checked) => events[i] = task_item_enter(el, checked)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn task_item_enter(el : @markdown.Element, checked : Bool) -> Event {
  @markdown.Enter(
    @markdown.Element::with_attrs(
      el.tag(),
      attrs_with(
        el.attrs(),
        attr("gfm:checked", if checked { "true" } else { "false" }),
      ),
      range=el.range(),
    ),
  )
}

///|
fn matching_item_end(events : Array[Event], start : Int) -> Int {
  let mut depth = 0
  for i in start..<events.length() {
    match events[i] {
      @markdown.Enter(_) => depth = depth + 1
      @markdown.Exit(_) => {
        depth = depth - 1
        if depth == 0 {
          return i + 1
        }
      }
      _ => ()
    }
  }
  events.length()
}

///|
fn detect_and_strip_task_marker(
  events : Array[Event],
  start : Int,
  end : Int,
) -> Bool? {
  let mut item_depth = 0
  for i in start..<end {
    match events[i] {
      @markdown.Enter(_) => item_depth = item_depth + 1
      @markdown.Exit(_) => item_depth = item_depth - 1
      @markdown.Text(text) =>
        if item_depth <= 2 {
          match strip_task_marker(text) {
            Some(result) => {
              events[i] = @markdown.Text(result.text)
              return Some(result.checked)
            }
            None if text == "[" =>
              match detect_split_task_marker(events, i, end) {
                Some(value) => return Some(value)
                None => return None
              }
            None => if text.length() > 0 { return None }
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn detect_split_task_marker(
  events : Array[Event],
  start : Int,
  end : Int,
) -> Bool? {
  let mut text = "["
  let used : Array[Int] = [start]
  let mut i = start + 1
  while i < end && text.length() < 5 {
    match events[i] {
      @markdown.Text(next) => {
        text = text + next
        used.push(i)
        match strip_task_marker(text) {
          Some(result) => {
            events[start] = @markdown.Text(result.text)
            for j in 1..<used.length() {
              events[used[j]] = @markdown.Text("")
            }
            return Some(result.checked)
          }
          None => ()
        }
      }
      _ => return None
    }
    i = i + 1
  }
  None
}

///|
priv struct TaskMarkerResult {
  checked : Bool
  text : String
}

///|
fn strip_task_marker(text : String) -> TaskMarkerResult? {
  guard text.length() >= 3 else { None }
  guard char_at(text, 0) == '[' && char_at(text, 2) == ']' else { None }
  let mark = char_at(text, 1)
  guard mark == ' ' || mark == 'x' || mark == 'X' else { None }
  guard text.length() == 3 || is_space(char_at(text, 3)) else { None }
  let start = if text.length() > 3 { 4 } else { 3 }
  Some({ checked: mark == 'x' || mark == 'X', text: text[start:].to_owned() })
}
