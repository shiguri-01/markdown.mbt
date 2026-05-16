///|
/// Renders Markdown events as HTML.
///
/// CommonMark tags are mapped to their HTML representation. Unknown extension
/// tags are rendered with their tag value, with tag and attribute text escaped.
/// Raw HTML events are passed through unchanged.
pub struct HtmlRenderer {
  priv unit : Int
}

///|
/// Creates an HTML renderer.
pub fn HtmlRenderer::new() -> HtmlRenderer {
  { unit: 0 }
}

///|
/// Renders an event stream as HTML.
pub fn to_html(events : Array[Event]) -> String {
  HtmlRenderer::new().render(events)
}

///|
/// Parses Markdown input with this processor and renders it as HTML.
pub fn Processor::render_html(self : Processor, source : String) -> String {
  self.parse(source).collect() |> to_html
}

///|
/// Renders an event stream as HTML.
pub fn HtmlRenderer::render(
  self : HtmlRenderer,
  events : Array[Event],
) -> String {
  ignore(self.unit)
  let mut out = ""
  let close_stack : Array[String] = []
  for event in events {
    match event {
      Enter(el) => {
        out = out + open_html(el)
        let close = close_html(el)
        close_stack.push(close)
      }
      Exit(tag) =>
        if close_stack.length() > 0 {
          let close = close_stack[close_stack.length() - 1]
          ignore(close_stack.pop())
          out = out + close
        } else {
          out = out + "</" + escape_html(tag.value) + ">"
        }
      Text(text) => out = out + escape_html(text)
      SoftBreak => out = out + "\n"
      HardBreak => out = out + "<br />\n"
      Html(raw) => out = out + raw
    }
  }
  out
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
  let mut out = ""
  for attr in attrs {
    out = out +
      " " +
      escape_html(attr.name.value) +
      "=\"" +
      escape_html(attr.value) +
      "\""
  }
  out
}

///|
fn attrs_html_except(attrs : Array[Attr], excluded : Array[String]) -> String {
  let mut out = ""
  for attr in attrs {
    if !attr_name_in(excluded, attr.name.value) {
      out = out +
        " " +
        escape_html(attr.name.value) +
        "=\"" +
        escape_html(attr.value) +
        "\""
    }
  }
  out
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
  let mut out = ""
  for i in 0..<input.length() {
    match char_at(input, i) {
      38 => out = out + "&amp;"
      60 => out = out + "&lt;"
      62 => out = out + "&gt;"
      34 => out = out + "&quot;"
      _ => out = out + input[i:i + 1].to_owned()
    }
  }
  out
}
