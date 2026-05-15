///|
pub(all) struct AstNode {
  element : Element?
  children : Array[AstNode]
  text : String
  range : SourceRange?
}

///|
pub(all) enum AstError {
  UnexpectedExit(Tag)
  UnclosedTag(Tag)
}

///|
pub struct AstBuilder {
  priv unit : Int
}

///|
pub fn AstBuilder::new() -> AstBuilder {
  { unit: 0 }
}

///|
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
