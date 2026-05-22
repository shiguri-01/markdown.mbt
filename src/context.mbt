///|
/// A downstream event consumer used by parsers, rules, renderers, and transforms.
pub struct Sink {
  priv emit_event : (Event) -> Unit
  priv finish_stream : () -> Unit
}

///|
/// Creates an event sink.
pub fn Sink::Sink(
  emit : (Event) -> Unit,
  finish? : () -> Unit = fn() { () },
) -> Sink {
  { emit_event: emit, finish_stream: finish }
}

///|
/// Emits an event downstream.
pub fn Sink::emit(self : Sink, event : Event) -> Unit {
  (self.emit_event)(event)
}

///|
/// Finishes the stream and lets downstream consumers flush buffered state.
pub fn Sink::finish(self : Sink) -> Unit {
  (self.finish_stream)()
}

///|
/// Context passed to block rules.
pub struct BlockContext {
  priv lines : Array[String]
  priv line_starts : Array[Int]
  priv index : Int
  priv registry : RuleRegistry
  priv inline_rules : Array[RuleEntry]
  priv inline_mode : InlineParseMode
  priv state : ParseState
  priv collect_only : Bool
}

///|
/// Context passed to inline and delimiter rules.
pub struct InlineContext {
  priv text : String
  priv index : Int
  priv scanner : InlineScanner
  priv registry : RuleRegistry
  priv state : ParseState
}

///|
/// Returns the line currently being considered by a block rule.
pub fn BlockContext::current_line(self : BlockContext) -> String {
  if self.index >= 0 && self.index < self.lines.length() {
    self.lines[self.index]
  } else {
    ""
  }
}

///|
/// Returns the source line at `index`, if it exists.
pub fn BlockContext::line_at(self : BlockContext, index : Int) -> String? {
  if index >= 0 && index < self.lines.length() {
    Some(self.lines[index])
  } else {
    None
  }
}

///|
/// Returns the current zero-based source line index.
pub fn BlockContext::line_index(self : BlockContext) -> Int {
  self.index
}

///|
/// Returns the byte offset where the current source line starts.
pub fn BlockContext::current_line_start(self : BlockContext) -> Int {
  if self.index >= 0 && self.index < self.line_starts.length() {
    self.line_starts[self.index]
  } else {
    0
  }
}

///|
/// Returns the full inline source being scanned.
pub fn InlineContext::source(self : InlineContext) -> String {
  self.text
}

///|
/// Returns the current byte offset in the inline source.
pub fn InlineContext::offset(self : InlineContext) -> Int {
  self.index
}

///|
/// Returns a scanner positioned at the current inline offset.
pub fn InlineContext::scanner(self : InlineContext) -> InlineScanner {
  self.scanner
}

///|
/// A small scanner for inline rule implementations.
pub struct InlineScanner {
  priv text : String
  priv index : Int
}

///|
/// Creates an inline scanner positioned at `index`.
pub fn InlineScanner::new(text : String, index : Int) -> InlineScanner? {
  if index < 0 || index > text.length() {
    None
  } else {
    Some(inline_scanner(text, index))
  }
}

///|
fn inline_scanner(text : String, index : Int) -> InlineScanner {
  { text, index }
}

///|
/// Returns whether the scanner position starts with `prefix`.
pub fn InlineScanner::has_prefix(self : InlineScanner, prefix : String) -> Bool {
  has_prefix_at(self.text, prefix, self.index)
}

///|
/// Returns the character code at the scanner position.
pub fn InlineScanner::char(self : InlineScanner) -> Int? {
  if self.index >= 0 && self.index < self.text.length() {
    Some(self.text[self.index].to_int())
  } else {
    None
  }
}

///|
/// Returns the character code at an offset from the scanner position.
pub fn InlineScanner::char_at_offset(
  self : InlineScanner,
  offset : Int,
) -> Int? {
  let target = self.index + offset
  if target >= 0 && target < self.text.length() {
    Some(self.text[target].to_int())
  } else {
    None
  }
}

///|
/// Returns a slice relative to the scanner position.
pub fn InlineScanner::slice(
  self : InlineScanner,
  start_offset : Int,
  end_offset : Int,
) -> String? {
  let start = self.index + start_offset
  let end = self.index + end_offset
  if start < 0 || end < start || end > self.text.length() {
    None
  } else {
    Some(self.text[start:end].to_owned())
  }
}

///|
/// Finds `needle` from the scanner position and returns a relative offset.
pub fn InlineScanner::find_char(self : InlineScanner, needle : Int) -> Int? {
  for i in self.index..<self.text.length() {
    if self.text[i].to_int() == needle {
      return Some(i - self.index)
    }
  }
  None
}
