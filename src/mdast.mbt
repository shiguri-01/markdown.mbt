///|
/// A Markdown AST node shaped to serialize as mdast-compatible JSON.
pub(all) enum MdastNode {
  MdastRoot(Array[MdastNode])
  MdastParagraph(Array[MdastNode])
  MdastHeading(Int, Array[MdastNode])
  MdastThematicBreak
  MdastBlockquote(Array[MdastNode])
  MdastList(Bool, Int?, Bool, Array[MdastNode])
  MdastListItem(Bool, Bool?, Array[MdastNode])
  MdastCode(String, String?, String?)
  MdastHtml(String)
  MdastText(String)
  MdastEmphasis(Array[MdastNode])
  MdastStrong(Array[MdastNode])
  MdastInlineCode(String)
  MdastBreak
  MdastLink(String, String?, Array[MdastNode])
  MdastImage(String, String?, String)
  MdastDelete(Array[MdastNode])
  MdastTable(Array[String?], Array[MdastNode])
  MdastTableRow(Array[MdastNode])
  MdastTableCell(String?, Array[MdastNode])
  MdastTableSection(Array[MdastNode])
  MdastExtension(String, Array[Attr], Array[MdastNode])
}

///|
priv struct MdastFrame {
  tag : Tag?
  attrs : Array[Attr]
  children : Array[MdastNode]
}

///|
/// A streaming mdast builder sink.
pub struct Mdast {
  priv stack : Array[MdastFrame]
  priv mut finished : Bool
  priv mut error : AstError?
}

///|
/// Creates an empty streaming mdast builder.
pub fn Mdast::Mdast() -> Mdast {
  { stack: [mdast_root_frame()], finished: false, error: None }
}

///|
/// Returns a sink that builds mdast as events arrive.
pub fn Mdast::sink(self : Mdast) -> Sink {
  Sink(fn(event) { self.accept(event) }, finish=fn() { self.finish() })
}

///|
/// Returns the mdast root after the stream has finished.
pub fn Mdast::result(self : Mdast) -> MdastNode raise AstError {
  if !self.finished {
    self.finish()
  }
  match self.error {
    Some(err) => raise err
    None => MdastRoot(copy_mdast_nodes(self.stack[0].children))
  }
}

///|
fn mdast_root_frame() -> MdastFrame {
  { tag: None, attrs: [], children: [] }
}

///|
fn Mdast::accept(self : Mdast, event : Event) -> Unit {
  guard !self.finished else {  }
  guard self.error is None else {  }
  match event {
    Enter(el) =>
      self.stack.push({ tag: Some(el.tag), attrs: el.attrs(), children: [] })
    Exit(tag) => self.close(tag)
    Text(text) => if text != "" { self.append(MdastText(text)) }
    SoftBreak => self.append(MdastText("\n"))
    HardBreak => self.append(MdastBreak)
    RawHtml(raw) => self.append(MdastHtml(raw))
  }
}

///|
fn Mdast::append(self : Mdast, node : MdastNode) -> Unit {
  self.stack[self.stack.length() - 1].children.push(node)
}

///|
fn Mdast::close(self : Mdast, tag : Tag) -> Unit {
  guard self.stack.length() > 1 else { self.error = Some(UnexpectedExit(tag)) }
  let frame = self.stack[self.stack.length() - 1]
  match frame.tag {
    Some(opened) if opened == tag => {
      ignore(self.stack.pop())
      self.append(mdast_node_from_frame(frame))
    }
    Some(opened) => self.error = Some(MismatchedExit(opened, tag))
    None => self.error = Some(UnexpectedExit(tag))
  }
}

///|
fn Mdast::finish(self : Mdast) -> Unit {
  guard !self.finished else {  }
  self.finished = true
  guard self.error is None else {  }
  guard self.stack.length() != 1 else {  }
  let err = match self.stack[self.stack.length() - 1].tag {
    Some(tag) => UnclosedTag(tag)
    None => UnclosedTag(tag_name("<root>"))
  }
  self.error = Some(err)
}

///|
fn mdast_node_from_frame(frame : MdastFrame) -> MdastNode {
  let tag = match frame.tag {
    Some(tag) => tag.to_string()
    None => "<root>"
  }
  let children = copy_mdast_nodes(frame.children)
  match tag {
    "cm:paragraph" => MdastParagraph(children)
    "cm:heading" => MdastHeading(mdast_heading_depth(frame.attrs), children)
    "cm:thematic_break" => MdastThematicBreak
    "cm:code_block" =>
      MdastCode(
        mdast_text_value(children),
        mdast_optional_nonempty_attr(frame.attrs, "info"),
        None,
      )
    "cm:block_quote" => MdastBlockquote(children)
    "cm:list" =>
      MdastList(
        mdast_bool_attr(frame.attrs, "ordered"),
        mdast_int_attr(frame.attrs, "start"),
        mdast_list_spread(children),
        children,
      )
    "cm:item" => {
      let spread = mdast_list_item_spread(children)
      MdastListItem(
        spread,
        mdast_checked_attr(frame.attrs),
        mdast_list_item_children(children),
      )
    }
    "cm:code_span" => MdastInlineCode(mdast_text_value(children))
    "cm:link" =>
      MdastLink(
        mdast_attr(frame.attrs, "destination", default=""),
        mdast_optional_attr(frame.attrs, "title"),
        children,
      )
    "cm:image" =>
      MdastImage(
        mdast_attr(frame.attrs, "destination", default=""),
        mdast_optional_attr(frame.attrs, "title"),
        mdast_attr(frame.attrs, "alt", default=""),
      )
    "cm:emphasis" => MdastEmphasis(children)
    "cm:strong" => MdastStrong(children)
    "gfm:strikethrough" => MdastDelete(children)
    "gfm:table" =>
      MdastTable(mdast_table_align(children), mdast_table_rows(children))
    "gfm:thead" | "gfm:tbody" => MdastTableSection(children)
    "gfm:tr" => MdastTableRow(children)
    "gfm:th" | "gfm:td" =>
      MdastTableCell(mdast_optional_attr(frame.attrs, "align"), children)
    _ => MdastExtension(tag, copy_attrs_for_mdast(frame.attrs), children)
  }
}

///|
fn mdast_heading_depth(attrs : Array[Attr]) -> Int {
  let depth = mdast_int_attr(attrs, "level").unwrap_or(1)
  if depth < 1 {
    1
  } else if depth > 6 {
    6
  } else {
    depth
  }
}

///|
fn mdast_attr(attrs : Array[Attr], name : String, default~ : String) -> String {
  match mdast_optional_attr(attrs, name) {
    Some(value) => value
    None => default
  }
}

///|
fn mdast_optional_attr(attrs : Array[Attr], name : String) -> String? {
  for attr in attrs {
    if attr.name().to_string() == name {
      return Some(attr.value())
    }
  }
  None
}

///|
fn mdast_optional_nonempty_attr(attrs : Array[Attr], name : String) -> String? {
  match mdast_optional_attr(attrs, name) {
    Some(value) if value != "" => Some(value)
    _ => None
  }
}

///|
fn mdast_bool_attr(attrs : Array[Attr], name : String) -> Bool {
  mdast_optional_attr(attrs, name) == Some("true")
}

///|
fn mdast_checked_attr(attrs : Array[Attr]) -> Bool? {
  match mdast_optional_attr(attrs, "gfm:checked") {
    Some("true") => Some(true)
    Some("false") => Some(false)
    _ => None
  }
}

///|
fn mdast_int_attr(attrs : Array[Attr], name : String) -> Int? {
  match mdast_optional_attr(attrs, name) {
    Some(value) => parse_mdast_int(value)
    None => None
  }
}

///|
fn parse_mdast_int(value : String) -> Int? {
  guard value.length() > 0 else { None }
  let mut out = 0
  for i in 0..<value.length() {
    let digit = value[i].to_int() - 48
    guard digit >= 0 && digit <= 9 else { return None }
    out = out * 10 + digit
  }
  Some(out)
}

///|
fn mdast_text_value(nodes : Array[MdastNode]) -> String {
  let out = StringBuilder::new()
  for node in nodes {
    match node {
      MdastText(text) => out.write_string(text)
      _ => ()
    }
  }
  out.to_string()
}

///|
fn mdast_list_item_children(nodes : Array[MdastNode]) -> Array[MdastNode] {
  let out : Array[MdastNode] = []
  let pending : Array[MdastNode] = []
  for node in nodes {
    if mdast_is_phrasing(node) {
      pending.push(copy_mdast_node(node))
    } else {
      if pending.length() > 0 {
        out.push(MdastParagraph(copy_mdast_nodes(pending)))
        pending.clear()
      }
      out.push(copy_mdast_node(node))
    }
  }
  if pending.length() > 0 {
    out.push(MdastParagraph(copy_mdast_nodes(pending)))
  }
  out
}

///|
fn mdast_is_phrasing(node : MdastNode) -> Bool {
  match node {
    MdastText(_)
    | MdastEmphasis(_)
    | MdastStrong(_)
    | MdastInlineCode(_)
    | MdastBreak
    | MdastLink(_, _, _)
    | MdastImage(_, _, _)
    | MdastDelete(_)
    | MdastHtml(_) => true
    _ => false
  }
}

///|
fn mdast_list_item_spread(nodes : Array[MdastNode]) -> Bool {
  for node in nodes {
    if node is MdastParagraph(_) {
      return true
    }
  }
  false
}

///|
fn mdast_list_spread(nodes : Array[MdastNode]) -> Bool {
  for node in nodes {
    match node {
      MdastListItem(spread, _, _) if spread => return true
      _ => ()
    }
  }
  false
}

///|
fn mdast_table_align(nodes : Array[MdastNode]) -> Array[String?] {
  for node in nodes {
    match node {
      MdastTableSection(rows) | MdastTableRow(rows) =>
        if mdast_align_from_rows(rows) is Some(aligns) {
          return aligns
        }
      _ => ()
    }
  }
  []
}

///|
fn mdast_align_from_rows(rows : Array[MdastNode]) -> Array[String?]? {
  for row in rows {
    match row {
      MdastTableRow(cells) => {
        let aligns : Array[String?] = []
        for cell in cells {
          match cell {
            MdastTableCell(align, _) => aligns.push(align)
            _ => ()
          }
        }
        return Some(aligns)
      }
      _ => ()
    }
  }
  None
}

///|
fn mdast_table_rows(nodes : Array[MdastNode]) -> Array[MdastNode] {
  let rows : Array[MdastNode] = []
  for node in nodes {
    match node {
      MdastTableSection(section_rows) =>
        for row in section_rows {
          rows.push(copy_mdast_node(row))
        }
      MdastTableRow(_) => rows.push(copy_mdast_node(node))
      _ => ()
    }
  }
  rows
}

///|
fn copy_attrs_for_mdast(attrs : Array[Attr]) -> Array[Attr] {
  let copied : Array[Attr] = []
  for attr in attrs {
    copied.push(attr)
  }
  copied
}

///|
fn copy_mdast_nodes(nodes : Array[MdastNode]) -> Array[MdastNode] {
  let copied : Array[MdastNode] = []
  for node in nodes {
    copied.push(copy_mdast_node(node))
  }
  copied
}

///|
fn copy_mdast_node(node : MdastNode) -> MdastNode {
  match node {
    MdastRoot(children) => MdastRoot(copy_mdast_nodes(children))
    MdastParagraph(children) => MdastParagraph(copy_mdast_nodes(children))
    MdastHeading(depth, children) =>
      MdastHeading(depth, copy_mdast_nodes(children))
    MdastThematicBreak => MdastThematicBreak
    MdastBlockquote(children) => MdastBlockquote(copy_mdast_nodes(children))
    MdastList(ordered, start, spread, children) =>
      MdastList(ordered, start, spread, copy_mdast_nodes(children))
    MdastListItem(spread, checked, children) =>
      MdastListItem(spread, checked, copy_mdast_nodes(children))
    MdastCode(value, lang, meta) => MdastCode(value, lang, meta)
    MdastHtml(value) => MdastHtml(value)
    MdastText(value) => MdastText(value)
    MdastEmphasis(children) => MdastEmphasis(copy_mdast_nodes(children))
    MdastStrong(children) => MdastStrong(copy_mdast_nodes(children))
    MdastInlineCode(value) => MdastInlineCode(value)
    MdastBreak => MdastBreak
    MdastLink(url, title, children) =>
      MdastLink(url, title, copy_mdast_nodes(children))
    MdastImage(url, title, alt) => MdastImage(url, title, alt)
    MdastDelete(children) => MdastDelete(copy_mdast_nodes(children))
    MdastTable(align, children) =>
      MdastTable(copy_string_options(align), copy_mdast_nodes(children))
    MdastTableRow(children) => MdastTableRow(copy_mdast_nodes(children))
    MdastTableCell(align, children) =>
      MdastTableCell(align, copy_mdast_nodes(children))
    MdastTableSection(children) => MdastTableSection(copy_mdast_nodes(children))
    MdastExtension(tag, attrs, children) =>
      MdastExtension(
        tag,
        copy_attrs_for_mdast(attrs),
        copy_mdast_nodes(children),
      )
  }
}

///|
fn copy_string_options(values : Array[String?]) -> Array[String?] {
  let copied : Array[String?] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
pub impl ToJson for MdastNode with to_json(self) {
  match self {
    MdastRoot(children) =>
      Json::object({
        "type": Json::string("root"),
        "children": mdast_children_json(children),
      })
    MdastParagraph(children) =>
      Json::object({
        "type": Json::string("paragraph"),
        "children": mdast_children_json(children),
      })
    MdastHeading(depth, children) =>
      Json::object({
        "type": Json::string("heading"),
        "depth": Json::number(depth.to_double()),
        "children": mdast_children_json(children),
      })
    MdastThematicBreak =>
      Json::object({ "type": Json::string("thematicBreak") })
    MdastBlockquote(children) =>
      Json::object({
        "type": Json::string("blockquote"),
        "children": mdast_children_json(children),
      })
    MdastList(ordered, start, spread, children) =>
      Json::object({
        "type": Json::string("list"),
        "ordered": Json::boolean(ordered),
        "start": mdast_int_option_json(start),
        "spread": Json::boolean(spread),
        "children": mdast_children_json(children),
      })
    MdastListItem(spread, checked, children) =>
      Json::object({
        "type": Json::string("listItem"),
        "spread": Json::boolean(spread),
        "checked": mdast_bool_option_json(checked),
        "children": mdast_children_json(children),
      })
    MdastCode(value, lang, meta) =>
      Json::object({
        "type": Json::string("code"),
        "lang": mdast_string_option_json(lang),
        "meta": mdast_string_option_json(meta),
        "value": Json::string(value),
      })
    MdastHtml(value) =>
      Json::object({
        "type": Json::string("html"),
        "value": Json::string(value),
      })
    MdastText(value) =>
      Json::object({
        "type": Json::string("text"),
        "value": Json::string(value),
      })
    MdastEmphasis(children) =>
      Json::object({
        "type": Json::string("emphasis"),
        "children": mdast_children_json(children),
      })
    MdastStrong(children) =>
      Json::object({
        "type": Json::string("strong"),
        "children": mdast_children_json(children),
      })
    MdastInlineCode(value) =>
      Json::object({
        "type": Json::string("inlineCode"),
        "value": Json::string(value),
      })
    MdastBreak => Json::object({ "type": Json::string("break") })
    MdastLink(url, title, children) =>
      Json::object({
        "type": Json::string("link"),
        "url": Json::string(url),
        "title": mdast_string_option_json(title),
        "children": mdast_children_json(children),
      })
    MdastImage(url, title, alt) =>
      Json::object({
        "type": Json::string("image"),
        "url": Json::string(url),
        "title": mdast_string_option_json(title),
        "alt": Json::string(alt),
      })
    MdastDelete(children) =>
      Json::object({
        "type": Json::string("delete"),
        "children": mdast_children_json(children),
      })
    MdastTable(align, children) =>
      Json::object({
        "type": Json::string("table"),
        "align": mdast_align_json(align),
        "children": mdast_children_json(children),
      })
    MdastTableRow(children) =>
      Json::object({
        "type": Json::string("tableRow"),
        "children": mdast_children_json(children),
      })
    MdastTableCell(_, children) =>
      Json::object({
        "type": Json::string("tableCell"),
        "children": mdast_children_json(children),
      })
    MdastTableSection(children) =>
      Json::object({
        "type": Json::string("mdastExtension"),
        "name": Json::string("gfm:table_section"),
        "children": mdast_children_json(children),
      })
    MdastExtension(tag, attrs, children) =>
      Json::object({
        "type": Json::string("mdastExtension"),
        "name": Json::string(tag),
        "attributes": mdast_attrs_json(attrs),
        "children": mdast_children_json(children),
      })
  }
}

///|
fn mdast_children_json(children : Array[MdastNode]) -> Json {
  let out : Array[Json] = []
  for child in children {
    out.push(child.to_json())
  }
  Json::array(out)
}

///|
fn mdast_align_json(align : Array[String?]) -> Json {
  let out : Array[Json] = []
  for value in align {
    out.push(mdast_string_option_json(value))
  }
  Json::array(out)
}

///|
fn mdast_attrs_json(attrs : Array[Attr]) -> Json {
  let out : Map[String, Json] = {}
  for attr in attrs {
    out[attr.name().to_string()] = Json::string(attr.value())
  }
  Json::object(out)
}

///|
fn mdast_string_option_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn mdast_int_option_json(value : Int?) -> Json {
  match value {
    Some(value) => Json::number(value.to_double())
    None => Json::null()
  }
}

///|
fn mdast_bool_option_json(value : Bool?) -> Json {
  match value {
    Some(value) => Json::boolean(value)
    None => Json::null()
  }
}
