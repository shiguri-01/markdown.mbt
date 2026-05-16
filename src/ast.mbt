///|
/// A node in the event-derived Markdown tree.
///
/// Element nodes have `Some(element)` and may have children. Text nodes have no
/// element and carry text.
pub struct AstNode {
  priv element : Element?
  priv children : Array[AstNode]
  priv text : String
  priv range : SourceRange?
}

///|
/// An error returned when an event stream cannot form a balanced tree.
pub(all) enum AstError {
  UnexpectedExit(Tag)
  UnclosedTag(Tag)
}

///|
/// Builds an AST from a balanced event stream.
pub struct AstBuilder {
  priv unit : Int
}

///|
/// Creates an AST builder.
pub fn AstBuilder::new() -> AstBuilder {
  { unit: 0 }
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
///
/// The returned array is the node's stored array.
pub fn AstNode::children(self : AstNode) -> Array[AstNode] {
  self.children
}

///|
/// Returns the text carried by a text node.
pub fn AstNode::text(self : AstNode) -> String {
  self.text
}

///|
/// Returns the source range attached to the node, if any.
pub fn AstNode::range(self : AstNode) -> SourceRange? {
  self.range
}

///|
/// Converts events into a tree.
///
/// `Enter` and `Exit` events must be balanced and must close the same tag that
/// was opened. The returned root node has no element.
pub fn AstBuilder::build(
  self : AstBuilder,
  events : Array[Event],
) -> Result[AstNode, AstError] {
  ignore(self.unit)
  let root : AstNode = { element: None, children: [], text: "", range: None }
  let stack : Array[AstNode] = [root]
  for event in events {
    match event {
      Enter(el) =>
        stack.push({
          element: Some(el),
          children: [],
          text: "",
          range: el.range,
        })
      Exit(tag) => {
        if stack.length() <= 1 {
          return Err(UnexpectedExit(tag))
        }
        let node = stack[stack.length() - 1]
        match node.element {
          Some(el) => if el.tag != tag { return Err(UnexpectedExit(tag)) }
          None => return Err(UnexpectedExit(tag))
        }
        ignore(stack.pop())
        stack[stack.length() - 1].children.push(node)
      }
      Text(text) =>
        stack[stack.length() - 1].children.push({
          element: None,
          children: [],
          text,
          range: None,
        })
      SoftBreak =>
        stack[stack.length() - 1].children.push({
          element: None,
          children: [],
          text: "\n",
          range: None,
        })
      HardBreak =>
        stack[stack.length() - 1].children.push({
          element: Some(element(tag_name("cm:hard_break"))),
          children: [],
          text: "",
          range: None,
        })
      Html(raw) =>
        stack[stack.length() - 1].children.push({
          element: Some(element(tag_name("cm:html"))),
          children: [{ element: None, children: [], text: raw, range: None }],
          text: "",
          range: None,
        })
    }
  }
  if stack.length() != 1 {
    match stack[stack.length() - 1].element {
      Some(el) => Err(UnclosedTag(el.tag))
      None => Err(UnclosedTag(tag_name("<root>")))
    }
  } else {
    Ok(stack[0])
  }
}
