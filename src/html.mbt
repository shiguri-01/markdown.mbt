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
  priv mut pending_item_attrs : Array[Attr]
}

///|
/// Creates an empty streaming HTML renderer.
pub fn Html::Html(size_hint? : Int = 0) -> Html {
  {
    out: StringBuilder::new(size_hint~),
    close_stack: [],
    pending_item_open: false,
    pending_item_attrs: [],
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
        self.pending_item_open = true
        self.pending_item_attrs = el.attrs
        self.close_stack.push("</li>\n")
      } else {
        self.flush_pending_item_open(is_list_item_block_child(el.tag))
        self.close_stack.push(write_open_html(self.out, el))
      }
    Exit(tag) => {
      if tag.value == "cm:item" && self.pending_item_open {
        self.flush_pending_item_open(false)
      }
      if self.close_stack.length() > 0 {
        let close = self.close_stack[self.close_stack.length() - 1]
        ignore(self.close_stack.pop())
        self.out.write_string(close)
      } else {
        self.out
        ..write_string("</")
        ..write_escaped_html(tag.value)
        .write_string(">")
      }
    }
    Text(text) =>
      match self.pending_task_marker_text(text) {
        Some(result) => {
          self.flush_pending_item_open(false)
          self.out.write_escaped_html(result.text)
        }
        None => {
          self.flush_pending_item_open(false)
          self.out.write_escaped_html(text)
        }
      }
    SoftBreak => {
      self.flush_pending_item_open(false)
      self.out.write_string("\n")
    }
    HardBreak => {
      self.flush_pending_item_open(false)
      self.out.write_string("<br />\n")
    }
    RawHtml(raw) => {
      self.flush_pending_item_open(contains_char(raw, '\n'))
      self.out.write_string(raw)
    }
  }
}

///|
fn Html::flush_pending_item_open(self : Html, block_child : Bool) -> Unit {
  if self.pending_item_open {
    if block_child {
      self.out.write_string("<li>\n")
    } else {
      self.out.write_string("<li>")
    }
    self.write_pending_task_checkbox()
    self.pending_item_attrs = []
    self.pending_item_open = false
  }
}

///|
fn Html::write_pending_task_checkbox(self : Html) -> Unit {
  let checked = attr_value(self.pending_item_attrs, "gfm:checked", "")
  if checked != "" {
    self.write_task_checkbox(checked == "true")
  }
}

///|
fn Html::write_task_checkbox(self : Html, checked : Bool) -> Unit {
  if checked {
    self.out.write_string(
      "<input checked=\"\" disabled=\"\" type=\"checkbox\"> ",
    )
  } else {
    self.out.write_string("<input disabled=\"\" type=\"checkbox\"> ")
  }
}

///|
priv struct HtmlTaskMarkerResult {
  text : String
}

///|
fn Html::pending_task_marker_text(
  self : Html,
  text : String,
) -> HtmlTaskMarkerResult? {
  guard self.pending_item_open else { None }
  guard attr_value(self.pending_item_attrs, "gfm:checked", "") == "" else {
    None
  }
  guard text.length() >= 3 else { None }
  guard char_at(text, 0) == '[' && char_at(text, 2) == ']' else { None }
  let mark = char_at(text, 1)
  guard mark == ' ' || mark == 'x' || mark == 'X' else { None }
  guard text.length() == 3 || is_space(char_at(text, 3)) else { None }
  self.pending_item_attrs = attrs_with_html(
    self.pending_item_attrs,
    Attr(
      AttrName::raw("gfm:checked"),
      if mark == 'x' || mark == 'X' {
        "true"
      } else {
        "false"
      },
    ),
  )
  let start = if text.length() > 3 { 4 } else { 3 }
  Some({ text: text[start:].to_owned() })
}

///|
fn attrs_with_html(attrs : Array[Attr], added : Attr) -> Array[Attr] {
  let out : Array[Attr] = []
  for attr in attrs {
    out.push(attr)
  }
  out.push(added)
  out
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
        out
        ..write_string("<h")
        ..write_string(level)
        ..write_attrs_except1(el.attrs, "level")
        .write_string(">")
        heading_close_html(level)
      } else if el.tag.value == "cm:list" &&
        attr_value(el.attrs, "ordered", "false") == "true" {
        out
        ..write_string("<ol")
        ..write_ordered_start_attr(el.attrs)
        ..write_attrs_except2(el.attrs, "ordered", "start")
        .write_string(">\n")
        "</ol>\n"
      } else if el.tag.value == "cm:list" {
        out
        ..write_string("<ul")
        ..write_attrs_except2(el.attrs, "ordered", "start")
        .write_string(">\n")
        "</ul>\n"
      } else if el.tag.value == "cm:code_block" {
        out
        ..write_string("<pre><code")
        ..write_code_info_attr(el.attrs)
        ..write_attrs_except1(el.attrs, "info")
        .write_string(">")
        "</code></pre>\n"
      } else if el.tag.value == "cm:link" {
        out
        ..write_string("<a href=\"")
        ..write_escaped_html(attr_value(el.attrs, "destination", ""))
        ..write_string("\"")
        ..write_title_attr(el.attrs)
        ..write_attrs_except2(el.attrs, "destination", "title")
        .write_string(">")
        "</a>"
      } else if el.tag.value == "cm:image" {
        out.write_image_html(el)
        ""
      } else if el.tag.value == "cm:thematic_break" {
        out.write_thematic_break_html(el)
        ""
      } else if is_gfm_table_tag(el.tag) {
        out.write_gfm_table_open_html(el)
        gfm_table_close_html(el)
      } else if el.tag.value == "gfm:strikethrough" && el.attrs.length() == 0 {
        out.write_string("<del>")
        "</del>"
      } else if is_block_tag(el.tag) {
        out
        ..write_string("<")
        ..write_string(name)
        ..write_attrs(el.attrs)
        .write_string(">")
        "</" + name + ">\n"
      } else {
        out
        ..write_string("<")
        ..write_string(name)
        ..write_attrs(el.attrs)
        .write_string(">")
        "</" + name + ">"
      }
    None => {
      out
      ..write_string("<")
      ..write_escaped_html(el.tag.value)
      ..write_attrs(el.attrs)
      .write_string(">")
      close_html(el)
    }
  }
}

///|
fn close_html(el : Element) -> String {
  match html_tag_name(el.tag) {
    Some(name) =>
      if el.tag.value == "cm:heading" {
        heading_close_html(attr_value(el.attrs, "level", "1"))
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
      } else if is_gfm_table_tag(el.tag) {
        gfm_table_close_html(el)
      } else if el.tag.value == "gfm:strikethrough" {
        "</del>"
      } else if is_block_tag(el.tag) {
        "</" + name + ">\n"
      } else {
        "</" + name + ">"
      }
    None => "</" + escape_html(el.tag.value) + ">"
  }
}

///|
fn heading_close_html(level : String) -> String {
  match level {
    "1" => "</h1>\n"
    "2" => "</h2>\n"
    "3" => "</h3>\n"
    "4" => "</h4>\n"
    "5" => "</h5>\n"
    "6" => "</h6>\n"
    _ => "</h" + level + ">\n"
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
    "gfm:strikethrough" => Some("del")
    "gfm:table" => Some("table")
    "gfm:thead" => Some("thead")
    "gfm:tbody" => Some("tbody")
    "gfm:tr" => Some("tr")
    "gfm:th" => Some("th")
    "gfm:td" => Some("td")
    _ => None
  }
}

///|
fn is_gfm_table_tag(tag : Tag) -> Bool {
  tag.value == "gfm:table" ||
  tag.value == "gfm:thead" ||
  tag.value == "gfm:tbody" ||
  tag.value == "gfm:tr" ||
  tag.value == "gfm:th" ||
  tag.value == "gfm:td"
}

///|
fn StringBuilder::write_gfm_table_open_html(
  self : StringBuilder,
  el : Element,
) -> Unit {
  match el.tag.value {
    "gfm:table" => self.write_string("<table>\n")
    "gfm:thead" => self.write_string("<thead>\n")
    "gfm:tbody" => self.write_string("<tbody>\n")
    "gfm:tr" => self.write_string("<tr>\n")
    "gfm:th" => {
      self.write_string("<th")
      self.write_attrs(el.attrs)
      self.write_string(">")
    }
    "gfm:td" => {
      self.write_string("<td")
      self.write_attrs(el.attrs)
      self.write_string(">")
    }
    _ => ()
  }
}

///|
fn gfm_table_close_html(el : Element) -> String {
  match el.tag.value {
    "gfm:table" => "</table>\n"
    "gfm:thead" => "</thead>\n"
    "gfm:tbody" => "</tbody>\n"
    "gfm:tr" => "</tr>\n"
    "gfm:th" => "</th>\n"
    "gfm:td" => "</td>\n"
    _ => ""
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
  self
  ..write_string(" ")
  ..write_escaped_html(attr.name.value)
  ..write_string("=\"")
  ..write_escaped_html(attr.value)
  .write_string("\"")
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
fn StringBuilder::write_title_attr(
  self : StringBuilder,
  attrs : Array[Attr],
) -> Unit {
  let title = attr_value(attrs, "title", "")
  if title != "" {
    self
    ..write_string(" title=\"")
    ..write_escaped_html(title)
    .write_string("\"")
  }
}

///|
fn StringBuilder::write_ordered_start_attr(
  self : StringBuilder,
  attrs : Array[Attr],
) -> Unit {
  let start = attr_value(attrs, "start", "1")
  if start != "1" {
    self
    ..write_string(" start=\"")
    ..write_escaped_html(start)
    .write_string("\"")
  }
}

///|
fn StringBuilder::write_code_info_attr(
  self : StringBuilder,
  attrs : Array[Attr],
) -> Unit {
  let info = attr_value(attrs, "info", "")
  if info != "" {
    self
    ..write_string(" class=\"language-")
    ..write_escaped_html(info)
    .write_string("\"")
  }
}

///|
fn StringBuilder::write_image_html(self : StringBuilder, el : Element) -> Unit {
  self
  ..write_string("<img src=\"")
  ..write_escaped_html(attr_value(el.attrs, "destination", ""))
  ..write_string("\" alt=\"")
  ..write_escaped_html(attr_value(el.attrs, "alt", ""))
  ..write_string("\"")
  ..write_title_attr(el.attrs)
  ..write_attrs_except3(el.attrs, "destination", "alt", "title")
  .write_string(" />")
}

///|
fn StringBuilder::write_thematic_break_html(
  self : StringBuilder,
  el : Element,
) -> Unit {
  self..write_string("<hr")..write_attrs(el.attrs).write_string(" />\n")
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
    self.write_string(input)
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
        self.write_string("&amp;")
        start = i + 1
      }
      '<' => {
        if start < i {
          self.write_view(input[start:i])
        }
        self.write_string("&lt;")
        start = i + 1
      }
      '>' => {
        if start < i {
          self.write_view(input[start:i])
        }
        self.write_string("&gt;")
        start = i + 1
      }
      '"' => {
        if start < i {
          self.write_view(input[start:i])
        }
        self.write_string("&quot;")
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
        out.write_string("&amp;")
        start = i + 1
      }
      '<' => {
        if start < i {
          out.write_view(input[start:i])
        }
        out.write_string("&lt;")
        start = i + 1
      }
      '>' => {
        if start < i {
          out.write_view(input[start:i])
        }
        out.write_string("&gt;")
        start = i + 1
      }
      '"' => {
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
