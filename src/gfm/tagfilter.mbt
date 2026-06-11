///|
fn tagfilter_core(downstream : Sink) -> Sink {
  Sink(
    fn(event) {
      match event {
        @markdown.RawHtml(raw) =>
          downstream.emit(@markdown.RawHtml(filter_disallowed_html(raw)))
        _ => downstream.emit(event)
      }
    },
    finish=fn() { downstream.finish() },
  )
}

///|
fn filter_disallowed_html(raw : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < raw.length() {
    if char_at(raw, i) == '<' && disallowed_html_tag_at(raw, i) > i {
      out <+ "&lt;"
      i = i + 1
    } else {
      out <+ "\{raw[i:i + 1].to_owned()}"
      i = i + 1
    }
  }
  out.to_string()
}

///|
fn disallowed_html_tag_at(raw : String, start : Int) -> Int {
  let mut i = start + 1
  if i < raw.length() && char_at(raw, i) == '/' {
    i = i + 1
  }
  let name_start = i
  while i < raw.length() {
    let c = char_at(raw, i)
    if is_ascii_alnum(c) || c == '-' {
      i = i + 1
    } else {
      break
    }
  }
  guard i > name_start else { -1 }
  if is_disallowed_html_tag(raw[name_start:i].to_owned()) {
    i
  } else {
    -1
  }
}

///|
fn is_disallowed_html_tag(name : String) -> Bool {
  let lower = ascii_lower(name)
  lower == "title" ||
  lower == "textarea" ||
  lower == "style" ||
  lower == "xmp" ||
  lower == "iframe" ||
  lower == "noembed" ||
  lower == "noframes" ||
  lower == "script" ||
  lower == "plaintext"
}

///|
fn ascii_lower(text : String) -> String {
  let out = StringBuilder::new()
  for i in 0..<text.length() {
    let c = to_lower_ascii(char_at(text, i))
    out <+ "\{ascii_char(c)}"
  }
  out.to_string()
}
