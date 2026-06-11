///|
/// Returns the standard HTML renderers for CommonMark plus GFM extension tags.
pub fn html_renderers() -> @markdown.HtmlRenderers {
  @commonmark.html_renderers().extend(extension_renderers())
}

///|
/// Returns only the HTML renderers for GFM extension event tags.
pub fn extension_renderers() -> @markdown.HtmlRenderers {
  @markdown.HtmlRenderers()
  .replace(tag_name("cm:item"), render_task_item_html)
  .register(tag_name("gfm:strikethrough"), render_strikethrough_html)
  .register(tag_name("gfm:table"), render_table_html)
  .register(tag_name("gfm:thead"), render_thead_html)
  .register(tag_name("gfm:tbody"), render_tbody_html)
  .register(tag_name("gfm:tr"), render_tr_html)
  .register(tag_name("gfm:th"), render_th_html)
  .register(tag_name("gfm:td"), render_td_html)
}

///|
fn render_task_item_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  if writer.starts_with_block_child() {
    writer <+ "<li>\n"
  } else {
    writer <+ "<li>"
  }
  match attr_value(el.attrs(), "gfm:checked") {
    Some("true") =>
      writer <+ "<input checked=\"\" disabled=\"\" type=\"checkbox\"> "
    Some("false") => writer <+ "<input disabled=\"\" type=\"checkbox\"> "
    _ => ()
  }
  "</li>\n"
}

///|
fn render_strikethrough_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer <+ "<del"
  writer.write_attrs(el.attrs())
  writer <+ ">"
  "</del>"
}

///|
fn render_table_html(
  writer : @markdown.HtmlWriter,
  _el : @markdown.Element,
) -> String {
  writer <+ "<table>\n"
  "</table>\n"
}

///|
fn render_thead_html(
  writer : @markdown.HtmlWriter,
  _el : @markdown.Element,
) -> String {
  writer <+ "<thead>\n"
  "</thead>\n"
}

///|
fn render_tbody_html(
  writer : @markdown.HtmlWriter,
  _el : @markdown.Element,
) -> String {
  writer <+ "<tbody>\n"
  "</tbody>\n"
}

///|
fn render_tr_html(
  writer : @markdown.HtmlWriter,
  _el : @markdown.Element,
) -> String {
  writer <+ "<tr>\n"
  "</tr>\n"
}

///|
fn render_th_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer <+ "<th"
  writer.write_attrs(el.attrs())
  writer <+ ">"
  "</th>\n"
}

///|
fn render_td_html(
  writer : @markdown.HtmlWriter,
  el : @markdown.Element,
) -> String {
  writer <+ "<td"
  writer.write_attrs(el.attrs())
  writer <+ ">"
  "</td>\n"
}

///|
fn attr_value(attrs : Array[@markdown.Attr], name : String) -> String? {
  for attr in attrs {
    if attr.name().to_string() == name {
      return Some(attr.value())
    }
  }
  None
}
