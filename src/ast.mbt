///|
/// A Markdown AST node shaped to serialize as mdast-compatible JSON.
pub(all) enum AstNode {
  AstRoot(Array[AstNode])
  AstParagraph(Array[AstNode])
  AstHeading(Int, Array[AstNode])
  AstThematicBreak
  AstBlockquote(Array[AstNode])
  AstList(Bool, Int?, Bool, Array[AstNode])
  AstListItem(Bool, Bool?, Array[AstNode])
  AstCode(String, String?, String?)
  AstHtml(String)
  AstText(String)
  AstEmphasis(Array[AstNode])
  AstStrong(Array[AstNode])
  AstInlineCode(String)
  AstBreak
  AstLink(String, String?, Array[AstNode])
  AstImage(String, String?, String)
  AstDelete(Array[AstNode])
  AstTable(Array[String?], Array[AstNode])
  AstTableRow(Array[AstNode])
  AstTableCell(String?, Array[AstNode])
  AstTableSection(Array[AstNode])
  AstExtension(String, Array[Attr], Array[AstNode])
}

///|
/// An error raised when an event stream cannot form a balanced AST.
pub(all) suberror AstError {
  /// An `Exit` appeared with no matching open element.
  UnexpectedExit(Tag)
  /// An `Exit` closed a different tag than the currently open element.
  MismatchedExit(Tag, Tag)
  /// The event stream ended while an element was still open.
  UnclosedTag(Tag)
}

///|
priv struct AstFrame {
  tag : Tag?
  attrs : Array[Attr]
  children : Array[AstNode]
}

///|
/// A streaming AST builder sink.
pub struct Ast {
  priv stack : Array[AstFrame]
  priv mut finished : Bool
  priv mut error : AstError?
}

///|
/// Creates an empty streaming AST builder.
pub fn Ast::Ast() -> Ast {
  { stack: [ast_root_frame()], finished: false, error: None }
}

///|
/// Returns a sink that builds the AST as events arrive.
pub fn Ast::sink(self : Ast) -> Sink {
  Sink(fn(event) { self.accept(event) }, finish=fn() { self.finish() })
}

///|
/// Returns the AST root after the stream has finished.
pub fn Ast::result(self : Ast) -> AstNode raise AstError {
  if !self.finished {
    self.finish()
  }
  match self.error {
    Some(err) => raise err
    None => AstRoot(copy_ast_nodes(self.stack[0].children))
  }
}

///|
fn ast_root_frame() -> AstFrame {
  { tag: None, attrs: [], children: [] }
}

///|
fn Ast::accept(self : Ast, event : Event) -> Unit {
  guard !self.finished else {  }
  guard self.error is None else {  }
  match event {
    Enter(el) =>
      self.stack.push({ tag: Some(el.tag), attrs: el.attrs(), children: [] })
    Exit(tag) => self.close(tag)
    Text(text) => if text != "" { self.append(AstText(text)) }
    SoftBreak => self.append(AstText("\n"))
    HardBreak => self.append(AstBreak)
    RawHtml(raw) => self.append(AstHtml(raw))
  }
}

///|
fn Ast::append(self : Ast, node : AstNode) -> Unit {
  self.stack[self.stack.length() - 1].children.push(node)
}

///|
fn Ast::close(self : Ast, tag : Tag) -> Unit {
  guard self.stack.length() > 1 else { self.error = Some(UnexpectedExit(tag)) }
  let frame = self.stack[self.stack.length() - 1]
  match frame.tag {
    Some(opened) if opened == tag => {
      ignore(self.stack.pop())
      self.append(ast_node_from_frame(frame))
    }
    Some(opened) => self.error = Some(MismatchedExit(opened, tag))
    None => self.error = Some(UnexpectedExit(tag))
  }
}

///|
fn Ast::finish(self : Ast) -> Unit {
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
fn ast_node_from_frame(frame : AstFrame) -> AstNode {
  let tag = match frame.tag {
    Some(tag) => tag.to_string()
    None => "<root>"
  }
  let children = copy_ast_nodes(frame.children)
  match tag {
    "cm:paragraph" => AstParagraph(children)
    "cm:heading" => AstHeading(ast_heading_depth(frame.attrs), children)
    "cm:thematic_break" => AstThematicBreak
    "cm:code_block" =>
      AstCode(
        ast_text_value(children),
        ast_optional_nonempty_attr(frame.attrs, "info"),
        None,
      )
    "cm:block_quote" => AstBlockquote(children)
    "cm:list" =>
      AstList(
        ast_bool_attr(frame.attrs, "ordered"),
        ast_int_attr(frame.attrs, "start"),
        ast_list_spread(children),
        children,
      )
    "cm:item" => {
      let spread = ast_list_item_spread(children)
      AstListItem(
        spread,
        ast_checked_attr(frame.attrs),
        ast_list_item_children(children),
      )
    }
    "cm:code_span" => AstInlineCode(ast_text_value(children))
    "cm:link" =>
      AstLink(
        ast_attr(frame.attrs, "destination", default=""),
        ast_optional_attr(frame.attrs, "title"),
        children,
      )
    "cm:image" =>
      AstImage(
        ast_attr(frame.attrs, "destination", default=""),
        ast_optional_attr(frame.attrs, "title"),
        ast_attr(frame.attrs, "alt", default=""),
      )
    "cm:emphasis" => AstEmphasis(children)
    "cm:strong" => AstStrong(children)
    "gfm:strikethrough" => AstDelete(children)
    "gfm:table" => AstTable(ast_table_align(children), ast_table_rows(children))
    "gfm:thead" | "gfm:tbody" => AstTableSection(children)
    "gfm:tr" => AstTableRow(children)
    "gfm:th" | "gfm:td" =>
      AstTableCell(ast_optional_attr(frame.attrs, "align"), children)
    _ => AstExtension(tag, copy_attrs_for_ast(frame.attrs), children)
  }
}

///|
fn ast_heading_depth(attrs : Array[Attr]) -> Int {
  let depth = ast_int_attr(attrs, "level").unwrap_or(1)
  if depth < 1 {
    1
  } else if depth > 6 {
    6
  } else {
    depth
  }
}

///|
fn ast_attr(attrs : Array[Attr], name : String, default~ : String) -> String {
  match ast_optional_attr(attrs, name) {
    Some(value) => value
    None => default
  }
}

///|
fn ast_optional_attr(attrs : Array[Attr], name : String) -> String? {
  for attr in attrs {
    if attr.name().to_string() == name {
      return Some(attr.value())
    }
  }
  None
}

///|
fn ast_optional_nonempty_attr(attrs : Array[Attr], name : String) -> String? {
  match ast_optional_attr(attrs, name) {
    Some(value) if value != "" => Some(value)
    _ => None
  }
}

///|
fn ast_bool_attr(attrs : Array[Attr], name : String) -> Bool {
  ast_optional_attr(attrs, name) == Some("true")
}

///|
fn ast_checked_attr(attrs : Array[Attr]) -> Bool? {
  match ast_optional_attr(attrs, "gfm:checked") {
    Some("true") => Some(true)
    Some("false") => Some(false)
    _ => None
  }
}

///|
fn ast_int_attr(attrs : Array[Attr], name : String) -> Int? {
  match ast_optional_attr(attrs, name) {
    Some(value) => parse_ast_int(value)
    None => None
  }
}

///|
fn parse_ast_int(value : String) -> Int? {
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
fn ast_text_value(nodes : Array[AstNode]) -> String {
  let out = StringBuilder::new()
  for node in nodes {
    match node {
      AstText(text) => out <+ "\{text}"
      _ => ()
    }
  }
  out.to_string()
}

///|
fn ast_list_item_children(nodes : Array[AstNode]) -> Array[AstNode] {
  let out : Array[AstNode] = []
  let pending : Array[AstNode] = []
  for node in nodes {
    if ast_is_phrasing(node) {
      pending.push(copy_ast_node(node))
    } else {
      if pending.length() > 0 {
        out.push(AstParagraph(copy_ast_nodes(pending)))
        pending.clear()
      }
      out.push(copy_ast_node(node))
    }
  }
  if pending.length() > 0 {
    out.push(AstParagraph(copy_ast_nodes(pending)))
  }
  out
}

///|
fn ast_is_phrasing(node : AstNode) -> Bool {
  match node {
    AstText(_)
    | AstEmphasis(_)
    | AstStrong(_)
    | AstInlineCode(_)
    | AstBreak
    | AstLink(_, _, _)
    | AstImage(_, _, _)
    | AstDelete(_)
    | AstHtml(_) => true
    _ => false
  }
}

///|
fn ast_list_item_spread(nodes : Array[AstNode]) -> Bool {
  for node in nodes {
    if node is AstParagraph(_) {
      return true
    }
  }
  false
}

///|
fn ast_list_spread(nodes : Array[AstNode]) -> Bool {
  for node in nodes {
    match node {
      AstListItem(spread, _, _) if spread => return true
      _ => ()
    }
  }
  false
}

///|
fn ast_table_align(nodes : Array[AstNode]) -> Array[String?] {
  for node in nodes {
    match node {
      AstTableSection(rows) | AstTableRow(rows) =>
        if ast_align_from_rows(rows) is Some(aligns) {
          return aligns
        }
      _ => ()
    }
  }
  []
}

///|
fn ast_align_from_rows(rows : Array[AstNode]) -> Array[String?]? {
  for row in rows {
    match row {
      AstTableRow(cells) => {
        let aligns : Array[String?] = []
        for cell in cells {
          match cell {
            AstTableCell(align, _) => aligns.push(align)
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
fn ast_table_rows(nodes : Array[AstNode]) -> Array[AstNode] {
  let rows : Array[AstNode] = []
  for node in nodes {
    match node {
      AstTableSection(section_rows) =>
        for row in section_rows {
          rows.push(copy_ast_node(row))
        }
      AstTableRow(_) => rows.push(copy_ast_node(node))
      _ => ()
    }
  }
  rows
}

///|
fn copy_attrs_for_ast(attrs : Array[Attr]) -> Array[Attr] {
  let copied : Array[Attr] = []
  for attr in attrs {
    copied.push(attr)
  }
  copied
}

///|
fn copy_ast_nodes(nodes : Array[AstNode]) -> Array[AstNode] {
  let copied : Array[AstNode] = []
  for node in nodes {
    copied.push(copy_ast_node(node))
  }
  copied
}

///|
fn copy_ast_node(node : AstNode) -> AstNode {
  match node {
    AstRoot(children) => AstRoot(copy_ast_nodes(children))
    AstParagraph(children) => AstParagraph(copy_ast_nodes(children))
    AstHeading(depth, children) => AstHeading(depth, copy_ast_nodes(children))
    AstThematicBreak => AstThematicBreak
    AstBlockquote(children) => AstBlockquote(copy_ast_nodes(children))
    AstList(ordered, start, spread, children) =>
      AstList(ordered, start, spread, copy_ast_nodes(children))
    AstListItem(spread, checked, children) =>
      AstListItem(spread, checked, copy_ast_nodes(children))
    AstCode(value, lang, meta) => AstCode(value, lang, meta)
    AstHtml(value) => AstHtml(value)
    AstText(value) => AstText(value)
    AstEmphasis(children) => AstEmphasis(copy_ast_nodes(children))
    AstStrong(children) => AstStrong(copy_ast_nodes(children))
    AstInlineCode(value) => AstInlineCode(value)
    AstBreak => AstBreak
    AstLink(url, title, children) =>
      AstLink(url, title, copy_ast_nodes(children))
    AstImage(url, title, alt) => AstImage(url, title, alt)
    AstDelete(children) => AstDelete(copy_ast_nodes(children))
    AstTable(align, children) =>
      AstTable(copy_string_options(align), copy_ast_nodes(children))
    AstTableRow(children) => AstTableRow(copy_ast_nodes(children))
    AstTableCell(align, children) =>
      AstTableCell(align, copy_ast_nodes(children))
    AstTableSection(children) => AstTableSection(copy_ast_nodes(children))
    AstExtension(tag, attrs, children) =>
      AstExtension(tag, copy_attrs_for_ast(attrs), copy_ast_nodes(children))
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
pub impl ToJson for AstNode with fn to_json(self) {
  match self {
    AstRoot(children) =>
      Json::object({
        "type": Json::string("root"),
        "children": ast_children_json(children),
      })
    AstParagraph(children) =>
      Json::object({
        "type": Json::string("paragraph"),
        "children": ast_children_json(children),
      })
    AstHeading(depth, children) =>
      Json::object({
        "type": Json::string("heading"),
        "depth": Json::number(depth.to_double()),
        "children": ast_children_json(children),
      })
    AstThematicBreak => Json::object({ "type": Json::string("thematicBreak") })
    AstBlockquote(children) =>
      Json::object({
        "type": Json::string("blockquote"),
        "children": ast_children_json(children),
      })
    AstList(ordered, start, spread, children) =>
      Json::object({
        "type": Json::string("list"),
        "ordered": Json::boolean(ordered),
        "start": ast_int_option_json(start),
        "spread": Json::boolean(spread),
        "children": ast_children_json(children),
      })
    AstListItem(spread, checked, children) =>
      Json::object({
        "type": Json::string("listItem"),
        "spread": Json::boolean(spread),
        "checked": ast_bool_option_json(checked),
        "children": ast_children_json(children),
      })
    AstCode(value, lang, meta) =>
      Json::object({
        "type": Json::string("code"),
        "lang": ast_string_option_json(lang),
        "meta": ast_string_option_json(meta),
        "value": Json::string(value),
      })
    AstHtml(value) =>
      Json::object({
        "type": Json::string("html"),
        "value": Json::string(value),
      })
    AstText(value) =>
      Json::object({
        "type": Json::string("text"),
        "value": Json::string(value),
      })
    AstEmphasis(children) =>
      Json::object({
        "type": Json::string("emphasis"),
        "children": ast_children_json(children),
      })
    AstStrong(children) =>
      Json::object({
        "type": Json::string("strong"),
        "children": ast_children_json(children),
      })
    AstInlineCode(value) =>
      Json::object({
        "type": Json::string("inlineCode"),
        "value": Json::string(value),
      })
    AstBreak => Json::object({ "type": Json::string("break") })
    AstLink(url, title, children) =>
      Json::object({
        "type": Json::string("link"),
        "url": Json::string(url),
        "title": ast_string_option_json(title),
        "children": ast_children_json(children),
      })
    AstImage(url, title, alt) =>
      Json::object({
        "type": Json::string("image"),
        "url": Json::string(url),
        "title": ast_string_option_json(title),
        "alt": Json::string(alt),
      })
    AstDelete(children) =>
      Json::object({
        "type": Json::string("delete"),
        "children": ast_children_json(children),
      })
    AstTable(align, children) =>
      Json::object({
        "type": Json::string("table"),
        "align": ast_align_json(align),
        "children": ast_children_json(children),
      })
    AstTableRow(children) =>
      Json::object({
        "type": Json::string("tableRow"),
        "children": ast_children_json(children),
      })
    AstTableCell(_, children) =>
      Json::object({
        "type": Json::string("tableCell"),
        "children": ast_children_json(children),
      })
    AstTableSection(children) =>
      Json::object({
        "type": Json::string("mdastExtension"),
        "name": Json::string("gfm:table_section"),
        "children": ast_children_json(children),
      })
    AstExtension(tag, attrs, children) =>
      Json::object({
        "type": Json::string("mdastExtension"),
        "name": Json::string(tag),
        "attributes": ast_attrs_json(attrs),
        "children": ast_children_json(children),
      })
  }
}

///|
fn ast_children_json(children : Array[AstNode]) -> Json {
  let out : Array[Json] = []
  for child in children {
    out.push(child.to_json())
  }
  Json::array(out)
}

///|
fn ast_align_json(align : Array[String?]) -> Json {
  let out : Array[Json] = []
  for value in align {
    out.push(ast_string_option_json(value))
  }
  Json::array(out)
}

///|
fn ast_attrs_json(attrs : Array[Attr]) -> Json {
  let out : Map[String, Json] = {}
  for attr in attrs {
    out[attr.name().to_string()] = Json::string(attr.value())
  }
  Json::object(out)
}

///|
fn ast_string_option_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn ast_int_option_json(value : Int?) -> Json {
  match value {
    Some(value) => Json::number(value.to_double())
    None => Json::null()
  }
}

///|
fn ast_bool_option_json(value : Bool?) -> Json {
  match value {
    Some(value) => Json::boolean(value)
    None => Json::null()
  }
}
