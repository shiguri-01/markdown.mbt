///|
/// A streaming HTML sink.
///
/// CommonMark tags are mapped to their HTML representation. Unknown extension
/// tags are rendered with their tag value, with tag and attribute text escaped.
/// Raw HTML events are passed through unchanged.
pub struct Html {
  priv out : StringBuilder
  priv close_stack : Array[String]
  priv mut pending_item_open : Bool
}

///|
/// Creates an empty streaming HTML renderer.
pub fn Html::new() -> Html {
  { out: StringBuilder::new(), close_stack: [], pending_item_open: false }
}

///|
/// Returns a sink that renders events as they arrive.
pub fn Html::sink(self : Html) -> Sink {
  Sink::new(fn(event) { write_html_event(self, event) })
}

///|
/// Returns the rendered HTML.
pub fn Html::to_string(self : Html) -> String {
  self.out.to_string()
}

///|
fn write_html_event(buffer : Html, event : Event) -> Unit {
  match event {
    Enter(el) =>
      if el.tag.value == "cm:item" {
        buffer.pending_item_open = true
        buffer.close_stack.push("</li>\n")
      } else {
        flush_pending_item_open(buffer, is_list_item_block_child(el.tag))
        buffer.close_stack.push(write_open_html(buffer.out, el))
      }
    Exit(tag) => {
      if tag.value == "cm:item" && buffer.pending_item_open {
        flush_pending_item_open(buffer, false)
      }
      if buffer.close_stack.length() > 0 {
        let close = buffer.close_stack[buffer.close_stack.length() - 1]
        ignore(buffer.close_stack.pop())
        buffer.out.write_string(close)
      } else {
        buffer.out.write_string("</")
        buffer.out.write_string(escape_html(tag.value))
        buffer.out.write_string(">")
      }
    }
    Text(text) => {
      flush_pending_item_open(buffer, false)
      buffer.out.write_string(escape_html(text))
    }
    SoftBreak => {
      flush_pending_item_open(buffer, false)
      buffer.out.write_string("\n")
    }
    HardBreak => {
      flush_pending_item_open(buffer, false)
      buffer.out.write_string("<br />\n")
    }
    Html(raw) => {
      flush_pending_item_open(buffer, false)
      buffer.out.write_string(raw)
    }
  }
}

///|
fn flush_pending_item_open(buffer : Html, block_child : Bool) -> Unit {
  if buffer.pending_item_open {
    if block_child {
      buffer.out.write_string("<li>\n")
    } else {
      buffer.out.write_string("<li>")
    }
    buffer.pending_item_open = false
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
fn write_open_html(out : StringBuilder, el : Element) -> String {
  match html_tag_name(el.tag) {
    Some(name) =>
      if el.tag.value == "cm:paragraph" && el.attrs.length() == 0 {
        out.write_string("<p>")
        "</p>\n"
      } else if el.tag.value == "cm:strong" && el.attrs.length() == 0 {
        out.write_string("<strong>")
        "</strong>"
      } else if el.tag.value == "cm:emphasis" && el.attrs.length() == 0 {
        out.write_string("<em>")
        "</em>"
      } else if el.tag.value == "cm:code_span" && el.attrs.length() == 0 {
        out.write_string("<code>")
        "</code>"
      } else if el.tag.value == "cm:block_quote" && el.attrs.length() == 0 {
        out.write_string("<blockquote>\n")
        "</blockquote>\n"
      } else if el.tag.value == "cm:heading" {
        let level = attr_value(el.attrs, "level", "1")
        out.write_string("<h")
        out.write_string(level)
        out.write_string(attrs_html_except(el.attrs, ["level"]))
        out.write_string(">")
        "</h" + level + ">\n"
      } else if el.tag.value == "cm:list" &&
        attr_value(el.attrs, "ordered", "false") == "true" {
        out.write_string("<ol")
        out.write_string(ordered_start_attr(el.attrs))
        out.write_string(attrs_html_except(el.attrs, ["ordered", "start"]))
        out.write_string(">\n")
        "</ol>\n"
      } else if el.tag.value == "cm:list" {
        out.write_string("<ul")
        out.write_string(attrs_html_except(el.attrs, ["ordered", "start"]))
        out.write_string(">\n")
        "</ul>\n"
      } else if el.tag.value == "cm:code_block" {
        out.write_string("<pre><code")
        out.write_string(code_info_attr(el.attrs))
        out.write_string(attrs_html_except(el.attrs, ["info"]))
        out.write_string(">")
        "</code></pre>\n"
      } else if el.tag.value == "cm:link" {
        out.write_string("<a href=\"")
        out.write_string(escape_html(attr_value(el.attrs, "destination", "")))
        out.write_string("\"")
        out.write_string(title_attr(el.attrs))
        out.write_string(attrs_html_except(el.attrs, ["destination", "title"]))
        out.write_string(">")
        "</a>"
      } else if el.tag.value == "cm:image" {
        out.write_string(open_html(el))
        ""
      } else if el.tag.value == "cm:thematic_break" {
        out.write_string(open_html(el))
        ""
      } else if is_block_tag(el.tag) {
        out.write_string("<")
        out.write_string(name)
        out.write_string(attrs_html(el.attrs))
        out.write_string(">")
        "</" + name + ">\n"
      } else {
        out.write_string("<")
        out.write_string(name)
        out.write_string(attrs_html(el.attrs))
        out.write_string(">")
        "</" + name + ">"
      }
    None => {
      out.write_string(open_html(el))
      close_html(el)
    }
  }
}

///|
fn open_html(el : Element) -> String {
  match html_tag_name(el.tag) {
    Some(name) =>
      if el.tag.value == "cm:heading" {
        "<h" +
        attr_value(el.attrs, "level", "1") +
        attrs_html_except(el.attrs, ["level"]) +
        ">"
      } else if el.tag.value == "cm:list" &&
        attr_value(el.attrs, "ordered", "false") == "true" {
        "<ol" +
        ordered_start_attr(el.attrs) +
        attrs_html_except(el.attrs, ["ordered", "start"]) +
        ">\n"
      } else if el.tag.value == "cm:list" {
        "<ul" + attrs_html_except(el.attrs, ["ordered", "start"]) + ">\n"
      } else if el.tag.value == "cm:link" {
        "<a href=\"" +
        escape_html(attr_value(el.attrs, "destination", "")) +
        "\"" +
        title_attr(el.attrs) +
        attrs_html_except(el.attrs, ["destination", "title"]) +
        ">"
      } else if el.tag.value == "cm:image" {
        "<img src=\"" +
        escape_html(attr_value(el.attrs, "destination", "")) +
        "\" alt=\"" +
        escape_html(attr_value(el.attrs, "alt", "")) +
        "\"" +
        title_attr(el.attrs) +
        attrs_html_except(el.attrs, ["destination", "alt", "title"]) +
        " />"
      } else if el.tag.value == "cm:thematic_break" {
        "<hr" + attrs_html(el.attrs) + " />\n"
      } else if el.tag.value == "cm:code_block" {
        "<pre><code" +
        code_info_attr(el.attrs) +
        attrs_html_except(el.attrs, ["info"]) +
        ">"
      } else {
        let suffix = if needs_open_newline(el.tag) { "\n" } else { "" }
        "<" + name + attrs_html(el.attrs) + ">" + suffix
      }
    None => "<" + escape_html(el.tag.value) + attrs_html(el.attrs) + ">"
  }
}

///|
fn close_html(el : Element) -> String {
  match html_tag_name(el.tag) {
    Some(name) =>
      if el.tag.value == "cm:heading" {
        "</h" + attr_value(el.attrs, "level", "1") + ">\n"
      } else if el.tag.value == "cm:list" &&
        attr_value(el.attrs, "ordered", "false") == "true" {
        "</ol>\n"
      } else if el.tag.value == "cm:list" {
        "</ul>\n"
      } else if el.tag.value == "cm:code_block" {
        "\n</code></pre>\n"
      } else if el.tag.value == "cm:image" ||
        el.tag.value == "cm:thematic_break" {
        ""
      } else if is_block_tag(el.tag) {
        "</" + name + ">\n"
      } else {
        "</" + name + ">"
      }
    None => "</" + escape_html(el.tag.value) + ">"
  }
}

///|
fn html_tag_name(tag : Tag) -> String? {
  match tag.value {
    "cm:paragraph" => Some("p")
    "cm:strong" => Some("strong")
    "cm:emphasis" => Some("em")
    "cm:code_span" => Some("code")
    "cm:code_block" => Some("pre")
    "cm:block_quote" => Some("blockquote")
    "cm:list" => Some("ul")
    "cm:item" => Some("li")
    "cm:link" => Some("a")
    "cm:image" => Some("img")
    "cm:thematic_break" => Some("hr")
    "cm:heading" => Some("h1")
    _ => None
  }
}

///|
fn is_block_tag(tag : Tag) -> Bool {
  tag.value == "cm:paragraph" ||
  tag.value == "cm:block_quote" ||
  tag.value == "cm:list" ||
  tag.value == "cm:item"
}

///|
fn needs_open_newline(tag : Tag) -> Bool {
  tag.value == "cm:block_quote" || tag.value == "cm:list"
}

///|
fn attrs_html(attrs : Array[Attr]) -> String {
  let out = StringBuilder::new()
  for attr in attrs {
    out.write_string(" ")
    out.write_string(escape_html(attr.name.value))
    out.write_string("=\"")
    out.write_string(escape_html(attr.value))
    out.write_string("\"")
  }
  out.to_string()
}

///|
fn attrs_html_except(attrs : Array[Attr], excluded : Array[String]) -> String {
  let out = StringBuilder::new()
  for attr in attrs {
    if !attr_name_in(excluded, attr.name.value) {
      out.write_string(" ")
      out.write_string(escape_html(attr.name.value))
      out.write_string("=\"")
      out.write_string(escape_html(attr.value))
      out.write_string("\"")
    }
  }
  out.to_string()
}

///|
fn attr_name_in(names : Array[String], needle : String) -> Bool {
  for name in names {
    if name == needle {
      return true
    }
  }
  false
}

///|
fn attr_value(attrs : Array[Attr], name : String, default : String) -> String {
  for attr in attrs {
    if attr.name.value == name {
      return attr.value
    }
  }
  default
}

///|
fn title_attr(attrs : Array[Attr]) -> String {
  let title = attr_value(attrs, "title", "")
  if title == "" {
    ""
  } else {
    " title=\"" + escape_html(title) + "\""
  }
}

///|
fn ordered_start_attr(attrs : Array[Attr]) -> String {
  let start = attr_value(attrs, "start", "1")
  if start == "1" {
    ""
  } else {
    " start=\"" + escape_html(start) + "\""
  }
}

///|
fn code_info_attr(attrs : Array[Attr]) -> String {
  let info = attr_value(attrs, "info", "")
  if info == "" {
    ""
  } else {
    " class=\"language-" + escape_html(info) + "\""
  }
}

///|
fn escape_html(input : String) -> String {
  let mut first = -1
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if c == 38 || c == 60 || c == 62 || c == 34 {
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
      38 => {
        if start < i {
          out.write_view(input[start:i])
        }
        out.write_string("&amp;")
        start = i + 1
      }
      60 => {
        if start < i {
          out.write_view(input[start:i])
        }
        out.write_string("&lt;")
        start = i + 1
      }
      62 => {
        if start < i {
          out.write_view(input[start:i])
        }
        out.write_string("&gt;")
        start = i + 1
      }
      34 => {
        if start < i {
          out.write_view(input[start:i])
        }
        out.write_string("&quot;")
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
