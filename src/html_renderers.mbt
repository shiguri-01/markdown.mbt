///|
/// A writer passed to custom HTML renderers.
///
/// Renderer authors should use `write_escaped` and `write_attrs` for text and
/// attribute output that comes from Markdown input.
pub struct HtmlWriter {
  priv out : StringBuilder
  priv block_child : Bool
}

///|
/// Writes raw HTML.
pub fn HtmlWriter::write_string(self : HtmlWriter, value : String) -> Unit {
  self.out.write_string(value)
}

///|
/// Returns whether the current element starts with a block child.
pub fn HtmlWriter::starts_with_block_child(self : HtmlWriter) -> Bool {
  self.block_child
}

///|
/// Writes escaped HTML text.
pub fn HtmlWriter::write_escaped(self : HtmlWriter, value : String) -> Unit {
  self.out.write_escaped_html(value)
}

///|
/// Writes escaped HTML attributes.
pub fn HtmlWriter::write_attrs(self : HtmlWriter, attrs : Array[Attr]) -> Unit {
  self.out.write_attrs(attrs)
}

///|
/// Writes escaped HTML attributes except one named attribute.
pub fn HtmlWriter::write_attrs_except1(
  self : HtmlWriter,
  attrs : Array[Attr],
  excluded : String,
) -> Unit {
  self.out.write_attrs_except1(attrs, excluded)
}

///|
/// Writes escaped HTML attributes except two named attributes.
pub fn HtmlWriter::write_attrs_except2(
  self : HtmlWriter,
  attrs : Array[Attr],
  first : String,
  second : String,
) -> Unit {
  self.out.write_attrs_except2(attrs, first, second)
}

///|
/// Writes escaped HTML attributes except three named attributes.
pub fn HtmlWriter::write_attrs_except3(
  self : HtmlWriter,
  attrs : Array[Attr],
  first : String,
  second : String,
  third : String,
) -> Unit {
  self.out.write_attrs_except3(attrs, first, second, third)
}

///|
/// A function that renders an opening HTML element and returns its close text.
pub type HtmlRendererFn = (HtmlWriter, Element) -> String

///|
priv struct HtmlRendererEntry {
  tag : Tag
  f : HtmlRendererFn
}

///|
priv enum HtmlRendererOp {
  RegisterHtmlRenderer(HtmlRendererEntry)
  ReplaceHtmlRenderer(HtmlRendererEntry)
  DisableHtmlRenderer(Tag)
  EnableHtmlRenderer(Tag)
}

///|
/// A composable set of HTML renderers keyed by Markdown event tags.
///
/// `HtmlRenderers` does not parse Markdown. It only teaches `Html` how to
/// render extension event tags emitted by syntax rules.
pub struct HtmlRenderers {
  priv ops : Array[HtmlRendererOp]
}

///|
/// Creates an empty composable HTML renderer set.
pub fn HtmlRenderers::HtmlRenderers() -> HtmlRenderers {
  { ops: [] }
}

///|
/// Appends all renderer operations from `other`.
pub fn HtmlRenderers::extend(
  self : HtmlRenderers,
  other : HtmlRenderers,
) -> HtmlRenderers {
  let ops = copy_html_renderer_ops(self.ops)
  for op in other.ops {
    ops.push(copy_html_renderer_op(op))
  }
  { ops, }
}

///|
/// Registers a renderer for `tag`.
pub fn HtmlRenderers::register(
  self : HtmlRenderers,
  tag : Tag,
  f : HtmlRendererFn,
) -> HtmlRenderers {
  let ops = copy_html_renderer_ops(self.ops)
  ops.push(RegisterHtmlRenderer({ tag, f }))
  { ops, }
}

///|
/// Replaces the renderer for `tag`.
pub fn HtmlRenderers::replace(
  self : HtmlRenderers,
  tag : Tag,
  f : HtmlRendererFn,
) -> HtmlRenderers {
  let ops = copy_html_renderer_ops(self.ops)
  ops.push(ReplaceHtmlRenderer({ tag, f }))
  { ops, }
}

///|
/// Disables the renderer for `tag`, causing `Html` to use unknown-tag fallback.
pub fn HtmlRenderers::disable(self : HtmlRenderers, tag : Tag) -> HtmlRenderers {
  let ops = copy_html_renderer_ops(self.ops)
  ops.push(DisableHtmlRenderer(tag))
  { ops, }
}

///|
/// Re-enables the renderer for `tag`.
pub fn HtmlRenderers::enable(self : HtmlRenderers, tag : Tag) -> HtmlRenderers {
  let ops = copy_html_renderer_ops(self.ops)
  ops.push(EnableHtmlRenderer(tag))
  { ops, }
}

///|
priv struct PreparedHtmlRenderers {
  mut entries : Array[HtmlRendererEntry]
  mut disabled : Array[Tag]
  mut overrides : Array[HtmlRendererEntry]
}

///|
fn PreparedHtmlRenderers::PreparedHtmlRenderers(
  renderers : HtmlRenderers,
) -> PreparedHtmlRenderers {
  let prepared = { entries: [], disabled: [], overrides: [] }
  prepared.apply(renderers)
  prepared
}

///|
fn PreparedHtmlRenderers::apply(
  self : PreparedHtmlRenderers,
  renderers : HtmlRenderers,
) -> Unit {
  for op in renderers.ops {
    match op {
      RegisterHtmlRenderer(entry) => self.register(entry)
      ReplaceHtmlRenderer(entry) => self.replace(entry)
      DisableHtmlRenderer(tag) => self.disable(tag)
      EnableHtmlRenderer(tag) => self.enable(tag)
    }
  }
}

///|
fn PreparedHtmlRenderers::find(
  self : PreparedHtmlRenderers,
  tag : Tag,
) -> HtmlRendererFn? {
  if array_contains_tag(self.disabled, tag) {
    return None
  }
  for entry in self.entries {
    if entry.tag == tag {
      return Some(entry.f)
    }
  }
  None
}

///|
fn PreparedHtmlRenderers::register(
  self : PreparedHtmlRenderers,
  entry : HtmlRendererEntry,
) -> Unit {
  match self.override_for(entry.tag) {
    Some(replace) => self.override_registered(replace)
    None => self.register_raw(entry)
  }
}

///|
fn PreparedHtmlRenderers::register_raw(
  self : PreparedHtmlRenderers,
  entry : HtmlRendererEntry,
) -> Unit {
  for old in self.entries {
    if old.tag == entry.tag {
      abort("duplicate HTML renderer: " + entry.tag.to_string())
    }
  }
  self.entries.push(entry)
}

///|
fn PreparedHtmlRenderers::replace(
  self : PreparedHtmlRenderers,
  entry : HtmlRendererEntry,
) -> Unit {
  self.remember_override(entry)
  self.override_registered(entry)
}

///|
fn PreparedHtmlRenderers::remember_override(
  self : PreparedHtmlRenderers,
  entry : HtmlRendererEntry,
) -> Unit {
  let next : Array[HtmlRendererEntry] = []
  for old in self.overrides {
    if old.tag != entry.tag {
      next.push(old)
    }
  }
  next.push(entry)
  self.overrides = next
}

///|
fn PreparedHtmlRenderers::override_for(
  self : PreparedHtmlRenderers,
  tag : Tag,
) -> HtmlRendererEntry? {
  for entry in self.overrides {
    if entry.tag == tag {
      return Some(entry)
    }
  }
  None
}

///|
fn PreparedHtmlRenderers::override_registered(
  self : PreparedHtmlRenderers,
  entry : HtmlRendererEntry,
) -> Unit {
  let next : Array[HtmlRendererEntry] = []
  for old in self.entries {
    if old.tag != entry.tag {
      next.push(old)
    }
  }
  self.entries = next
  self.entries.push(entry)
}

///|
fn PreparedHtmlRenderers::disable(
  self : PreparedHtmlRenderers,
  tag : Tag,
) -> Unit {
  if !array_contains_tag(self.disabled, tag) {
    self.disabled.push(tag)
  }
}

///|
fn PreparedHtmlRenderers::enable(
  self : PreparedHtmlRenderers,
  tag : Tag,
) -> Unit {
  let next_disabled : Array[Tag] = []
  for disabled in self.disabled {
    if disabled != tag {
      next_disabled.push(disabled)
    }
  }
  self.disabled = next_disabled
}

///|
fn copy_html_renderer_ops(ops : Array[HtmlRendererOp]) -> Array[HtmlRendererOp] {
  let out : Array[HtmlRendererOp] = []
  for op in ops {
    out.push(copy_html_renderer_op(op))
  }
  out
}

///|
fn copy_html_renderer_op(op : HtmlRendererOp) -> HtmlRendererOp {
  match op {
    RegisterHtmlRenderer(entry) => RegisterHtmlRenderer(entry)
    ReplaceHtmlRenderer(entry) => ReplaceHtmlRenderer(entry)
    DisableHtmlRenderer(tag) => DisableHtmlRenderer(tag)
    EnableHtmlRenderer(tag) => EnableHtmlRenderer(tag)
  }
}

///|
fn array_contains_tag(tags : Array[Tag], tag : Tag) -> Bool {
  for current in tags {
    if current == tag {
      return true
    }
  }
  false
}

///|
