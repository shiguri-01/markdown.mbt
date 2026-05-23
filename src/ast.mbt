///|
priv enum AstNodeKind {
  RootNode
  ElementNode
  TextNode
}

///|
/// A node in the event-derived Markdown tree.
///
/// Element nodes have `Some(element)` and may have children. Text nodes have no
/// element and carry text.
pub struct AstNode {
  priv kind : AstNodeKind
  priv element : Element?
  priv children : Array[AstNode]
  priv text : String
  priv range : SourceRange?
}

///|
/// An error raised when an event stream cannot form a balanced tree.
pub(all) suberror AstError {
  /// An `Exit` appeared with no matching open element.
  UnexpectedExit(Tag)
  /// An `Exit` closed a different tag than the currently open element.
  MismatchedExit(Tag, Tag)
  /// The event stream ended while an element was still open.
  UnclosedTag(Tag)
}

///|
/// A streaming AST builder sink.
pub struct Ast {
  priv stack : Array[AstNode]
  priv mut finished : Bool
  priv mut error : AstError?
}

///|
/// Creates an empty streaming AST builder.
pub fn Ast::Ast() -> Ast {
  { stack: [root_ast_node()], finished: false, error: None }
}

///|
/// Returns a sink that builds an AST as events arrive.
pub fn Ast::sink(self : Ast) -> Sink {
  Sink(fn(event) { self.accept(event) }, finish=fn() { self.finish() })
}

///|
/// Returns the AST after the stream has finished.
pub fn Ast::result(self : Ast) -> AstNode raise AstError {
  if !self.finished {
    self.finish()
  }
  match self.error {
    Some(err) => raise err
    None => copy_ast_node(self.stack[0])
  }
}

///|
/// Returns the node element, or `None` for text nodes and the root node.
pub fn AstNode::element(self : AstNode) -> Element? {
  self.element
}

///|
/// Returns the node children.
pub fn AstNode::children(self : AstNode) -> Array[AstNode] {
  copy_ast_nodes(self.children)
}

///|
/// Returns the text carried by a text node.
pub fn AstNode::text(self : AstNode) -> String? {
  match self.kind {
    TextNode => Some(self.text)
    RootNode => None
    ElementNode => None
  }
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
  {
    kind: node.kind,
    element: node.element,
    children: copy_ast_nodes(node.children),
    text: node.text,
    range: node.range,
  }
}

///|
/// Returns the source range attached to the node, if any.
pub fn AstNode::range(self : AstNode) -> SourceRange? {
  self.range
}

///|
fn root_ast_node() -> AstNode {
  { kind: RootNode, element: None, children: [], text: "", range: None }
}

///|
fn Ast::accept(self : Ast, event : Event) -> Unit {
  guard !self.finished else {  }
  guard self.error is None else {  }
  match event {
    Enter(el) =>
      self.stack.push({
        kind: ElementNode,
        element: Some(el),
        children: [],
        text: "",
        range: el.range,
      })
    Exit(tag) => {
      guard self.stack.length() > 1 else {
        self.error = Some(UnexpectedExit(tag))
      }
      let node = self.stack[self.stack.length() - 1]
      match node.element {
        Some(el) if el.tag == tag => {
          ignore(self.stack.pop())
          self.stack[self.stack.length() - 1].children.push(node)
        }
        Some(el) => self.error = Some(MismatchedExit(el.tag, tag))
        None => self.error = Some(UnexpectedExit(tag))
      }
    }
    Text(text) =>
      self.stack[self.stack.length() - 1].children.push({
        kind: TextNode,
        element: None,
        children: [],
        text,
        range: None,
      })
    SoftBreak =>
      self.stack[self.stack.length() - 1].children.push({
        kind: TextNode,
        element: None,
        children: [],
        text: "\n",
        range: None,
      })
    HardBreak =>
      self.stack[self.stack.length() - 1].children.push({
        kind: ElementNode,
        element: Some(Element(tag_name("cm:hard_break"))),
        children: [],
        text: "",
        range: None,
      })
    RawHtml(raw) =>
      self.stack[self.stack.length() - 1].children.push({
        kind: ElementNode,
        element: Some(Element(tag_name("cm:html"))),
        children: [
          {
            kind: TextNode,
            element: None,
            children: [],
            text: raw,
            range: None,
          },
        ],
        text: "",
        range: None,
      })
  }
}

///|
fn Ast::finish(self : Ast) -> Unit {
  guard !self.finished else {  }
  self.finished = true
  guard self.error is None else {  }
  guard self.stack.length() != 1 else {  }
  let err = match self.stack[self.stack.length() - 1].element {
    Some(el) => UnclosedTag(el.tag)
    None => UnclosedTag(tag_name("<root>"))
  }
  self.error = Some(err)
}
