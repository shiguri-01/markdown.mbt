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
/// An error returned when an event stream cannot form a balanced tree.
pub(all) enum AstError {
  /// An `Exit` appeared with no matching open element.
  UnexpectedExit(Tag)
  /// An `Exit` closed a different tag than the currently open element.
  MismatchedExit(Tag, Tag)
  /// The event stream ended while an element was still open.
  UnclosedTag(Tag)
}

///|
/// Builds an AST from a balanced event stream.
pub struct AstBuilder {
  priv unit : Int
}

///|
/// A streaming AST builder sink.
pub struct AstBuffer {
  priv stack : Array[AstNode]
  priv mut result : Result[AstNode, AstError]?
}

///|
/// Creates an AST builder.
pub fn AstBuilder::new() -> AstBuilder {
  { unit: 0 }
}

///|
/// Creates an empty streaming AST buffer.
pub fn AstBuffer::new() -> AstBuffer {
  { stack: [root_ast_node()], result: None }
}

///|
/// Returns a sink that builds an AST as events arrive.
pub fn AstBuffer::sink(self : AstBuffer) -> EventSink {
  EventSink::new(fn(event) { self.accept(event) }, finish=fn() { self.finish() })
}

///|
/// Returns the AST result after the stream has finished.
pub fn AstBuffer::result(self : AstBuffer) -> Result[AstNode, AstError] {
  match self.result {
    Some(result) => copy_ast_result(result)
    None => self.finish_and_result()
  }
}

///|
/// Converts events into an AST.
pub fn to_ast(events : Array[Event]) -> Result[AstNode, AstError] {
  AstBuilder::new().build(events)
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
fn copy_ast_result(
  result : Result[AstNode, AstError],
) -> Result[AstNode, AstError] {
  match result {
    Ok(node) => Ok(copy_ast_node(node))
    Err(err) => Err(err)
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
/// Converts events into a tree.
///
/// `Enter` and `Exit` events must be balanced and must close the same tag that
/// was opened. The returned root node has no element. Mismatched close events
/// report the expected open tag first and the actual close tag second.
pub fn AstBuilder::build(
  self : AstBuilder,
  events : Array[Event],
) -> Result[AstNode, AstError] {
  ignore(self.unit)
  let buffer = AstBuffer::new()
  for event in events {
    buffer.accept(event)
  }
  buffer.finish_and_result()
}

///|
fn AstBuffer::accept(self : AstBuffer, event : Event) -> Unit {
  match self.result {
    Some(_) => return
    None => ()
  }
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
      if self.stack.length() <= 1 {
        self.result = Some(Err(UnexpectedExit(tag)))
        return
      }
      let node = self.stack[self.stack.length() - 1]
      match node.element {
        Some(el) =>
          if el.tag != tag {
            self.result = Some(Err(MismatchedExit(el.tag, tag)))
            return
          }
        None => {
          self.result = Some(Err(UnexpectedExit(tag)))
          return
        }
      }
      ignore(self.stack.pop())
      self.stack[self.stack.length() - 1].children.push(node)
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
        element: Some(Element::new(tag_name("cm:hard_break"))),
        children: [],
        text: "",
        range: None,
      })
    Html(raw) =>
      self.stack[self.stack.length() - 1].children.push({
        kind: ElementNode,
        element: Some(Element::new(tag_name("cm:html"))),
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
fn AstBuffer::finish(self : AstBuffer) -> Unit {
  ignore(self.finish_and_result())
}

///|
fn AstBuffer::finish_and_result(self : AstBuffer) -> Result[AstNode, AstError] {
  match self.result {
    Some(result) => return copy_ast_result(result)
    None => ()
  }
  let result = if self.stack.length() != 1 {
    match self.stack[self.stack.length() - 1].element {
      Some(el) => Err(UnclosedTag(el.tag))
      None => Err(UnclosedTag(tag_name("<root>")))
    }
  } else {
    Ok(copy_ast_node(self.stack[0]))
  }
  self.result = Some(result)
  copy_ast_result(result)
}
