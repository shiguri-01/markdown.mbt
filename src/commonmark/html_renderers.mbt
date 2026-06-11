///|
/// Returns the standard CommonMark HTML renderers.
pub fn html_renderers() -> @markdown.HtmlRenderers {
  @markdown.HtmlRenderers()
  .register(tag_name("cm:paragraph"), render_paragraph_html)
  .register(tag_name("cm:strong"), render_strong_html)
  .register(tag_name("cm:emphasis"), render_emphasis_html)
  .register(tag_name("cm:code_span"), render_code_span_html)
  .register(tag_name("cm:block_quote"), render_block_quote_html)
  .register(tag_name("cm:heading"), render_heading_html)
  .register(tag_name("cm:list"), render_list_html)
  .register(tag_name("cm:item"), render_item_html)
  .register(tag_name("cm:code_block"), render_code_block_html)
  .register(tag_name("cm:link"), render_link_html)
  .register(tag_name("cm:image"), render_image_html)
  .register(tag_name("cm:thematic_break"), render_thematic_break_html)
}

///|
fn render_paragraph_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer.write_string("<p>")
  } else {
    writer.write_string("<p")
    writer.write_attrs(el.attrs())
    writer.write_string(">")
  }
  "</p>\n"
}

///|
fn render_strong_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer.write_string("<strong>")
  } else {
    writer.write_string("<strong")
    writer.write_attrs(el.attrs())
    writer.write_string(">")
  }
  "</strong>"
}

///|
fn render_emphasis_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer.write_string("<em>")
  } else {
    writer.write_string("<em")
    writer.write_attrs(el.attrs())
    writer.write_string(">")
  }
  "</em>"
}

///|
fn render_code_span_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer.write_string("<code>")
  } else {
    writer.write_string("<code")
    writer.write_attrs(el.attrs())
    writer.write_string(">")
  }
  "</code>"
}

///|
fn render_block_quote_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer.write_string("<blockquote>\n")
  } else {
    writer.write_string("<blockquote")
    writer.write_attrs(el.attrs())
    writer.write_string(">\n")
  }
  "</blockquote>\n"
}

///|
fn render_heading_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  let level = attr_value(el.attrs(), "level", "1")
  writer.write_string("<h")
  writer.write_string(level)
  writer.write_attrs_except1(el.attrs(), "level")
  writer.write_string(">")
  heading_close_html(level)
}

///|
fn render_list_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if attr_value(el.attrs(), "ordered", "false") == "true" {
    writer.write_string("<ol")
    write_ordered_start_attr(writer, el.attrs())
    writer.write_attrs_except2(el.attrs(), "ordered", "start")
    writer.write_string(">\n")
    "</ol>\n"
  } else {
    writer.write_string("<ul")
    writer.write_attrs_except2(el.attrs(), "ordered", "start")
    writer.write_string(">\n")
    "</ul>\n"
  }
}

///|
fn render_item_html(
  writer : @markdown.HtmlWriter,
  _el : @markdown.Element,
) -> String {
  if writer.starts_with_block_child() {
    writer.write_string("<li>\n")
  } else {
    writer.write_string("<li>")
  }
  "</li>\n"
}

///|
fn render_code_block_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer.write_string("<pre><code")
  write_code_info_attr(writer, el.attrs())
  writer.write_attrs_except1(el.attrs(), "info")
  writer.write_string(">")
  "</code></pre>\n"
}

///|
fn render_link_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer.write_string("<a href=\"")
  writer.write_escaped(attr_value(el.attrs(), "destination", ""))
  writer.write_string("\"")
  write_title_attr(writer, el.attrs())
  writer.write_attrs_except2(el.attrs(), "destination", "title")
  writer.write_string(">")
  "</a>"
}

///|
fn render_image_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer.write_string("<img src=\"")
  writer.write_escaped(attr_value(el.attrs(), "destination", ""))
  writer.write_string("\" alt=\"")
  writer.write_escaped(attr_value(el.attrs(), "alt", ""))
  writer.write_string("\"")
  write_title_attr(writer, el.attrs())
  writer.write_attrs_except3(el.attrs(), "destination", "alt", "title")
  writer.write_string(" />")
  ""
}

///|
fn render_thematic_break_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer.write_string("<hr")
  writer.write_attrs(el.attrs())
  writer.write_string(" />\n")
  ""
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
fn write_title_attr(
  writer : @markdown.HtmlWriter,
  attrs : Array[@markdown.Attr],
) -> Unit {
  let title = attr_value(attrs, "title", "")
  if title != "" {
    writer.write_string(" title=\"")
    writer.write_escaped(title)
    writer.write_string("\"")
  }
}

///|
fn write_ordered_start_attr(
  writer : @markdown.HtmlWriter,
  attrs : Array[@markdown.Attr],
) -> Unit {
  let start = attr_value(attrs, "start", "1")
  if start != "1" {
    writer.write_string(" start=\"")
    writer.write_escaped(start)
    writer.write_string("\"")
  }
}

///|
fn write_code_info_attr(
  writer : @markdown.HtmlWriter,
  attrs : Array[@markdown.Attr],
) -> Unit {
  let info = attr_value(attrs, "info", "")
  if info != "" {
    writer.write_string(" class=\"language-")
    writer.write_escaped(info)
    writer.write_string("\"")
  }
}
