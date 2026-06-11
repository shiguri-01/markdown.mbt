///|
/// A streaming HTML sink.
///
/// Known tags are mapped by the configured renderers. Unknown extension tags are
/// rendered with their tag value, with tag and attribute text escaped. Raw HTML
/// events are passed through unchanged.
pub struct Html {
  priv out : StringBuilder
  priv close_stack : Array[String]
  priv plan : PreparedHtmlRenderers
  priv mut pending_item : Element?
}

///|
/// Creates an empty streaming HTML renderer.
pub fn Html::Html(renderers : HtmlRenderers, size_hint? : Int = 0) -> Html {
  {
    out: StringBuilder::new(size_hint~),
    close_stack: [],
    plan: PreparedHtmlRenderers(renderers),
    pending_item: None,
  }
}

///|
/// Returns a sink that renders events as they arrive.
pub fn Html::sink(self : Html) -> Sink {
  Sink(fn(event) { self.write_event(event) })
}

///|
/// Returns the rendered HTML.
pub fn Html::to_string(self : Html) -> String {
  self.out.to_string()
}

///|
fn Html::write_event(self : Html, event : Event) -> Unit {
  match event {
    Enter(el) =>
      if el.tag.value == "cm:item" {
        self.pending_item = Some(el)
      } else {
        self.flush_pending_item_open(is_list_item_block_child(el.tag))
        self.close_stack.push(
          write_open_html(self.out, el, self.plan, block_child=false),
        )
      }
    Exit(tag) => {
      if tag.value == "cm:item" && self.pending_item is Some(_) {
        self.flush_pending_item_open(false)
      }
      if self.close_stack.length() > 0 {
        let close = self.close_stack[self.close_stack.length() - 1]
        ignore(self.close_stack.pop())
        self.out <+ "\{close}"
      } else {
        self.out <+ "</"
        self.out.write_escaped_html(tag.value)
        self.out <+ ">"
      }
    }
    Text(text) => {
      self.flush_pending_item_open(false)
      self.out.write_escaped_html(text)
    }
    SoftBreak => {
      self.flush_pending_item_open(false)
      self.out <+ "\n"
    }
    HardBreak => {
      self.flush_pending_item_open(false)
      self.out <+ "<br />\n"
    }
    RawHtml(raw) => {
      self.flush_pending_item_open(contains_char(raw, '\n'))
      self.out <+ "\{raw}"
    }
  }
}

///|
fn Html::flush_pending_item_open(self : Html, block_child : Bool) -> Unit {
  match self.pending_item {
    Some(el) => {
      self.close_stack.push(
        write_open_html(self.out, el, self.plan, block_child~),
      )
      self.pending_item = None
    }
    None => ()
  }
}

///|
fn is_list_item_block_child(tag : Tag) -> Bool {
  tag.value == "cm:paragraph" ||
  tag.value == "cm:block_quote" ||
  tag.value == "cm:list" ||
  tag.value == "cm:code_block" ||
  tag.value == "cm:thematic_break" ||
  tag.value == "cm:heading"
}

///|
fn write_open_html(
  out : StringBuilder,
  el : Element,
  plan : PreparedHtmlRenderers,
  block_child~ : Bool,
) -> String {
  match plan.find(el.tag) {
    Some(f) => f({ out, block_child }, el)
    None => {
      out <+ "<"
      out.write_escaped_html(el.tag.value)
      out.write_attrs(el.attrs)
      out <+ ">"
      "</" + escape_html(el.tag.value) + ">"
    }
  }
}

///|
fn StringBuilder::write_attrs(
  self : StringBuilder,
  attrs : Array[Attr],
) -> Unit {
  for attr in attrs {
    self.write_attr(attr)
  }
}

///|
fn StringBuilder::write_attrs_except1(
  self : StringBuilder,
  attrs : Array[Attr],
  excluded : String,
) -> Unit {
  for attr in attrs {
    if attr.name.value != excluded {
      self.write_attr(attr)
    }
  }
}

///|
fn StringBuilder::write_attrs_except2(
  self : StringBuilder,
  attrs : Array[Attr],
  first : String,
  second : String,
) -> Unit {
  for attr in attrs {
    let name = attr.name.value
    if name != first && name != second {
      self.write_attr(attr)
    }
  }
}

///|
fn StringBuilder::write_attrs_except3(
  self : StringBuilder,
  attrs : Array[Attr],
  first : String,
  second : String,
  third : String,
) -> Unit {
  for attr in attrs {
    let name = attr.name.value
    if name != first && name != second && name != third {
      self.write_attr(attr)
    }
  }
}

///|
fn StringBuilder::write_attr(self : StringBuilder, attr : Attr) -> Unit {
  self <+ " "
  self.write_escaped_html(attr.name.value)
  self <+ "=\""
  self.write_escaped_html(attr.value)
  self <+ "\""
}

///|
fn StringBuilder::write_escaped_html(
  self : StringBuilder,
  input : String,
) -> Unit {
  let mut first = -1
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if c == '&' || c == '<' || c == '>' || c == '"' {
      first = i
      break
    }
  }
  if first < 0 {
    self <+ "\{input}"
    return
  }
  let mut start = 0
  let mut i = first
  while i < input.length() {
    match char_at(input, i) {
      '&' => {
        if start < i {
          self.write_view(input[start:i])
        }
        self <+ "&amp;"
        start = i + 1
      }
      '<' => {
        if start < i {
          self.write_view(input[start:i])
        }
        self <+ "&lt;"
        start = i + 1
      }
      '>' => {
        if start < i {
          self.write_view(input[start:i])
        }
        self <+ "&gt;"
        start = i + 1
      }
      '"' => {
        if start < i {
          self.write_view(input[start:i])
        }
        self <+ "&quot;"
        start = i + 1
      }
      _ => ()
    }
    i = i + 1
  }
  if start < input.length() {
    self.write_view(input[start:])
  }
}

///|
fn escape_html(input : String) -> String {
  let mut first = -1
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if c == '&' || c == '<' || c == '>' || c == '"' {
      first = i
      break
    }
  }
  if first < 0 {
    return input
  }
  let out = StringBuilder::new(size_hint=input.length())
  let mut start = 0
  let mut i = first
  while i < input.length() {
    match char_at(input, i) {
      '&' => {
        if start < i {
          out.write_view(input[start:i])
        }
        out <+ "&amp;"
        start = i + 1
      }
      '<' => {
        if start < i {
          out.write_view(input[start:i])
        }
        out <+ "&lt;"
        start = i + 1
      }
      '>' => {
        if start < i {
          out.write_view(input[start:i])
        }
        out <+ "&gt;"
        start = i + 1
      }
      '"' => {
        if start < i {
          out.write_view(input[start:i])
        }
        out <+ "&quot;"
        start = i + 1
      }
      _ => ()
    }
    i = i + 1
  }
  if start < input.length() {
    out.write_view(input[start:])
  }
  out.to_string()
}
