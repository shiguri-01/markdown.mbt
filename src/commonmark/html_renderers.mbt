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
    writer <+ "<p>"
  } else {
    writer <+ "<p"
    writer.write_attrs(el.attrs())
    writer <+ ">"
  }
  "</p>\n"
}

///|
fn render_strong_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer <+ "<strong>"
  } else {
    writer <+ "<strong"
    writer.write_attrs(el.attrs())
    writer <+ ">"
  }
  "</strong>"
}

///|
fn render_emphasis_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer <+ "<em>"
  } else {
    writer <+ "<em"
    writer.write_attrs(el.attrs())
    writer <+ ">"
  }
  "</em>"
}

///|
fn render_code_span_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer <+ "<code>"
  } else {
    writer <+ "<code"
    writer.write_attrs(el.attrs())
    writer <+ ">"
  }
  "</code>"
}

///|
fn render_block_quote_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if el.attrs().length() == 0 {
    writer <+ "<blockquote>\n"
  } else {
    writer <+ "<blockquote"
    writer.write_attrs(el.attrs())
    writer <+ ">\n"
  }
  "</blockquote>\n"
}

///|
fn render_heading_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  let level = attr_value(el.attrs(), "level", "1")
  writer <+ "<h"
  writer <+ "\{level}"
  writer.write_attrs_except1(el.attrs(), "level")
  writer <+ ">"
  heading_close_html(level)
}

///|
fn render_list_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if attr_value(el.attrs(), "ordered", "false") == "true" {
    writer <+ "<ol"
    write_ordered_start_attr(writer, el.attrs())
    writer.write_attrs_except2(el.attrs(), "ordered", "start")
    writer <+ ">\n"
    "</ol>\n"
  } else {
    writer <+ "<ul"
    writer.write_attrs_except2(el.attrs(), "ordered", "start")
    writer <+ ">\n"
    "</ul>\n"
  }
}

///|
fn render_item_html(
  writer : @markdown.HtmlWriter,
  _el : @markdown.Element,
) -> String {
  if writer.starts_with_block_child() {
    writer <+ "<li>\n"
  } else {
    writer <+ "<li>"
  }
  "</li>\n"
}

///|
fn render_code_block_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer <+ "<pre><code"
  write_code_info_attr(writer, el.attrs())
  writer.write_attrs_except1(el.attrs(), "info")
  writer <+ ">"
  "</code></pre>\n"
}

///|
fn render_link_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer <+ "<a href=\""
  writer.write_escaped(attr_value(el.attrs(), "destination", ""))
  writer <+ "\""
  write_title_attr(writer, el.attrs())
  writer.write_attrs_except2(el.attrs(), "destination", "title")
  writer <+ ">"
  "</a>"
}

///|
fn render_image_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer <+ "<img src=\""
  writer.write_escaped(attr_value(el.attrs(), "destination", ""))
  writer <+ "\" alt=\""
  writer.write_escaped(attr_value(el.attrs(), "alt", ""))
  writer <+ "\""
  write_title_attr(writer, el.attrs())
  writer.write_attrs_except3(el.attrs(), "destination", "alt", "title")
  writer <+ " />"
  ""
}

///|
fn render_thematic_break_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer <+ "<hr"
  writer.write_attrs(el.attrs())
  writer <+ " />\n"
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
    writer <+ " title=\""
    writer.write_escaped(title)
    writer <+ "\""
  }
}

///|
fn write_ordered_start_attr(
  writer : @markdown.HtmlWriter,
  attrs : Array[@markdown.Attr],
) -> Unit {
  let start = attr_value(attrs, "start", "1")
  if start != "1" {
    writer <+ " start=\""
    writer.write_escaped(start)
    writer <+ "\""
  }
}

///|
fn write_code_info_attr(
  writer : @markdown.HtmlWriter,
  attrs : Array[@markdown.Attr],
) -> Unit {
  let info = attr_value(attrs, "info", "")
  if info != "" {
    writer <+ " class=\"language-"
    writer.write_escaped(info)
    writer <+ "\""
  }
}
