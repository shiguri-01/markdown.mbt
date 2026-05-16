///|
/// A configured Markdown processor.
///
/// A processor owns the rule registry used to turn Markdown input into events.
/// Add plugins before calling `parse`.
pub struct Processor {
  priv registry : RuleRegistry
}

///|
/// A pull parser over an already-produced event stream.
pub struct Parser {
  priv events : Array[Event]
  priv mut index : Int
}

///|
/// Creates an empty processor with no registered rules.
///
/// Parsing with an empty processor still emits a fallback paragraph for plain
/// text input.
pub fn Processor::new() -> Processor {
  { registry: RuleRegistry::new() }
}

///|
/// Creates a processor with the built-in CommonMark plugin installed.
pub fn Processor::commonmark() -> Processor {
  Processor::new().with_plugin(commonmark_plugin())
}

///|
/// Creates a processor with the built-in CommonMark plugin installed.
pub fn commonmark() -> Processor {
  Processor::commonmark()
}

///|
/// Parses Markdown input with the built-in CommonMark processor.
pub fn parse(source : String) -> Array[Event] {
  commonmark().parse(source).collect()
}

///|
/// Registers all rules from `plugin` on this processor.
///
/// Plugin operations are applied in order. Registered rules are ordered by
/// priority, registration order, and same-chain `before`/`after` edges.
pub fn Processor::with_plugin(self : Processor, plugin : Plugin) -> Processor {
  let registry = self.registry.copy().use_plugin(plugin)
  { registry, }
}

///|
/// Parses Markdown input into a pull parser of events.
///
/// Source core rules run before block parsing. Core event rules run after block
/// and inline parsing.
pub fn Processor::parse(self : Processor, input : String) -> Parser {
  if self.registry.has_commonmark_preset_only() &&
    is_plain_single_paragraph(input) {
    return { events: plain_paragraph_events(input), index: 0 }
  }
  let source = apply_source_core_rules(input, self.registry)
  if self.registry.has_commonmark_preset_only() && source.length() >= 10_000 {
    match parse_large_commonmark_blocks(source, self.registry) {
      Some(events) => return { events, index: 0 }
      None => ()
    }
  }
  {
    events: apply_core_rules(parse_blocks(source, self.registry), self.registry),
    index: 0,
  }
}

///|
/// Returns the next event, or `None` after the stream is exhausted.
pub fn Parser::next(self : Parser) -> Event? {
  if self.index >= self.events.length() {
    None
  } else {
    let event = self.events[self.index]
    self.index = self.index + 1
    Some(event)
  }
}

///|
/// Collects the remaining events and advances the parser to the end.
pub fn Parser::collect(self : Parser) -> Array[Event] {
  if self.index == 0 {
    self.index = self.events.length()
    return self.events
  }
  let remaining : Array[Event] = []
  while self.index < self.events.length() {
    remaining.push(self.events[self.index])
    self.index = self.index + 1
  }
  remaining
}

///|
fn parse_blocks(input : String, registry : RuleRegistry) -> Array[Event] {
  let source = split_lines(input)
  parse_block_lines(source.lines, source.line_starts, registry)
}

///|
fn plain_paragraph_events(input : String) -> Array[Event] {
  [
    Enter(
      Element::with_attrs(
        tag_name("cm:paragraph"),
        [],
        range=Some(source_range(0, input.length())),
      ),
    ),
    Text(input),
    Exit(tag_name("cm:paragraph")),
  ]
}

///|
fn is_plain_single_paragraph(input : String) -> Bool {
  if input.length() == 0 {
    return false
  }
  let first = char_at(input, 0)
  if first == 32 ||
    first == 9 ||
    first == 35 ||
    first == 42 ||
    first == 43 ||
    first == 45 ||
    first == 60 ||
    first == 62 ||
    first == 95 ||
    first == 96 ||
    first == 126 ||
    (first >= 48 && first <= 57) {
    return false
  }
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if c == 10 ||
      c == 13 ||
      c == 33 ||
      c == 38 ||
      c == 42 ||
      c == 60 ||
      c == 91 ||
      c == 92 ||
      c == 95 ||
      c == 96 {
      return false
    }
  }
  true
}

///|
fn parse_block_lines(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
) -> Array[Event] {
  if registry.has_commonmark_block_rules_only() {
    return parse_commonmark_block_lines(lines, line_starts, registry)
  }
  let sink : EventSink = { events: [] }
  let mut i = 0
  let inline_rules = registry.inline_parse_rules()
  let block_continue_rules = registry.block_continue_rules()
  let block_start_rules = registry.block_rules()
  while i < lines.length() {
    let mut consumed = 0
    let ctx = { lines, line_starts, index: i, registry, inline_rules }
    for rule in block_continue_rules {
      match rule.block {
        Some(f) => if consumed == 0 { consumed = f(ctx, sink) }
        None => ()
      }
    }
    for rule in block_start_rules {
      match rule.block {
        Some(f) => if consumed == 0 { consumed = f(ctx, sink) }
        None => ()
      }
    }
    if consumed <= 0 {
      consumed = if registry.has_enabled_block_rules() {
        emit_fallback_text(ctx, sink)
      } else {
        cm_paragraph_block(ctx, sink)
      }
    }
    i = i + consumed
  }
  sink.events
}

///|
fn parse_commonmark_block_lines(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
) -> Array[Event] {
  let sink : EventSink = { events: [] }
  let mut i = 0
  let inline_rules = registry.inline_parse_rules()
  while i < lines.length() {
    let ctx = { lines, line_starts, index: i, registry, inline_rules }
    let mut consumed = commonmark_block_dispatch(ctx, sink)
    if consumed == 0 {
      consumed = cm_paragraph_block(ctx, sink)
    }
    if consumed <= 0 {
      consumed = 1
    }
    i = i + consumed
  }
  sink.events
}

///|
fn parse_large_commonmark_blocks(
  input : String,
  registry : RuleRegistry,
) -> Array[Event]? {
  let source = split_lines(input)
  let sink : EventSink = { events: [] }
  let mut i = 0
  while i < source.lines.length() {
    let line = source.lines[i]
    let first = first_non_space_index(line)
    if first < 0 {
      i = i + 1
      continue
    }
    let leading = count_leading_spaces(line)
    let trimmed = trim(line)
    if leading <= 3 && fence_marker(trimmed) != "" {
      i = fast_fenced_code_block(source, i, sink)
    } else if leading >= 4 {
      return None
    } else if is_atx_heading_start(trimmed) {
      fast_atx_heading_block(source, i, trimmed, registry, sink)
      i = i + 1
    } else if trimmed.has_prefix(">") {
      i = fast_blockquote_block(source, i, registry, sink)
    } else if is_unordered_list_marker(trimmed) ||
      is_ordered_list_marker(trimmed) {
      i = fast_list_block(source, i, registry, sink)
    } else if is_thematic_break(trimmed) {
      sink.emit(
        Enter(
          fast_element(
            tag_name("cm:thematic_break"),
            [],
            Some(fast_line_range(source, i)),
          ),
        ),
      )
      sink.emit(Exit(tag_name("cm:thematic_break")))
      i = i + 1
    } else {
      i = fast_paragraph_block(source, i, registry, sink)
    }
  }
  Some(sink.events)
}

///|
fn fast_atx_heading_block(
  source : LineSource,
  index : Int,
  trimmed : String,
  registry : RuleRegistry,
  sink : EventSink,
) -> Unit {
  let mut level = 0
  while level < trimmed.length() && level < 6 && char_at(trimmed, level) == 35 {
    level = level + 1
  }
  let content = if level >= trimmed.length() {
    ""
  } else {
    trim(strip_closing_hashes(trimmed[level:].to_owned()))
  }
  sink.emit(
    Enter(
      fast_element(
        tag_name("cm:heading"),
        [{ name: attr_name("level"), value: level.to_string() }],
        Some(fast_line_range(source, index)),
      ),
    ),
  )
  fast_commonmark_inlines(content, registry, sink)
  sink.emit(Exit(tag_name("cm:heading")))
}

///|
fn fast_fenced_code_block(
  source : LineSource,
  start : Int,
  sink : EventSink,
) -> Int {
  let line = source.lines[start]
  let opening_indent = count_leading_spaces(line)
  let trimmed = trim(line)
  let fence = fence_marker(trimmed)
  let info = fence_info(trimmed, fence)
  let mut i = start + 1
  let code = StringBuilder::new()
  while i < source.lines.length() {
    if is_closing_fence_line(source.lines[i], fence) {
      sink.emit(
        Enter(
          fast_element(
            tag_name("cm:code_block"),
            code_block_attrs(info),
            Some(fast_block_range(source, start, i + 1)),
          ),
        ),
      )
      sink.emit(Text(code.to_string()))
      sink.emit(Exit(tag_name("cm:code_block")))
      return i + 1
    }
    if i > start + 1 {
      code.write_string("\n")
    }
    code.write_string(strip_fenced_code_indent(source.lines[i], opening_indent))
    i = i + 1
  }
  sink.emit(
    Enter(
      fast_element(
        tag_name("cm:code_block"),
        code_block_attrs(info),
        Some(fast_block_range(source, start, i)),
      ),
    ),
  )
  sink.emit(Text(code.to_string()))
  sink.emit(Exit(tag_name("cm:code_block")))
  i
}

///|
fn fast_blockquote_block(
  source : LineSource,
  start : Int,
  registry : RuleRegistry,
  sink : EventSink,
) -> Int {
  let mut i = start
  let inner = StringBuilder::new()
  while i < source.lines.length() && is_blockquote_marker_line(source.lines[i]) {
    if i > start {
      inner.write_string("\n")
    }
    inner.write_string(strip_blockquote_marker(source.lines[i]))
    i = i + 1
  }
  sink.emit(
    Enter(
      fast_element(
        tag_name("cm:block_quote"),
        [],
        Some(fast_block_range(source, start, i)),
      ),
    ),
  )
  sink.emit(Enter(Element::new(tag_name("cm:paragraph"))))
  fast_commonmark_inlines(inner.to_string(), registry, sink)
  sink.emit(Exit(tag_name("cm:paragraph")))
  sink.emit(Exit(tag_name("cm:block_quote")))
  i
}

///|
fn fast_list_block(
  source : LineSource,
  start : Int,
  registry : RuleRegistry,
  sink : EventSink,
) -> Int {
  let first = trim(source.lines[start])
  let ordered = is_ordered_list_marker(first)
  let ordered_delimiter = if ordered {
    ordered_list_delimiter(first)
  } else {
    0
  }
  let unordered_delimiter = if ordered { 0 } else { char_at(first, 0) }
  let mut end = start
  while end < source.lines.length() {
    if count_leading_spaces(source.lines[end]) > 3 {
      break
    }
    let current = trim(source.lines[end])
    if !same_list_marker(
        current, ordered, ordered_delimiter, unordered_delimiter,
      ) {
      break
    }
    end = end + 1
  }
  sink.emit(
    Enter(
      fast_element(
        tag_name("cm:list"),
        list_attrs(ordered, first),
        Some(fast_block_range(source, start, end)),
      ),
    ),
  )
  for i in start..<end {
    let current = trim(source.lines[i])
    let item = if ordered {
      strip_ordered_marker(current)
    } else {
      strip_unordered_marker(current)
    }
    sink.emit(
      Enter(
        fast_element(tag_name("cm:item"), [], Some(fast_line_range(source, i))),
      ),
    )
    fast_commonmark_inlines(trim(item), registry, sink)
    sink.emit(Exit(tag_name("cm:item")))
  }
  sink.emit(Exit(tag_name("cm:list")))
  end
}

///|
fn fast_paragraph_block(
  source : LineSource,
  start : Int,
  registry : RuleRegistry,
  sink : EventSink,
) -> Int {
  let mut i = start
  while i < source.lines.length() &&
        !is_blank(source.lines[i]) &&
        (i == start || !is_paragraph_interrupt(source.lines[i])) {
    i = i + 1
  }
  sink.emit(
    Enter(
      fast_element(
        tag_name("cm:paragraph"),
        [],
        Some(
          if i == start + 1 {
            fast_line_range(source, start)
          } else {
            fast_block_range(source, start, i)
          },
        ),
      ),
    ),
  )
  let inline_text = if i == start + 1 {
    paragraph_line(source.lines[start])
  } else {
    fast_paragraph_text(source, start, i)
  }
  fast_commonmark_inlines(inline_text, registry, sink)
  sink.emit(Exit(tag_name("cm:paragraph")))
  i
}

///|
fn fast_paragraph_text(source : LineSource, start : Int, end : Int) -> String {
  let text = StringBuilder::new()
  for i in start..<end {
    if i > start {
      text.write_string("\n")
    }
    text.write_string(paragraph_line(source.lines[i]))
  }
  text.to_string()
}

///|
fn fast_commonmark_inlines(
  text : String,
  registry : RuleRegistry,
  sink : EventSink,
) -> Unit {
  let mut i = 0
  while i < text.length() {
    if !is_fast_inline_special(text, i) {
      let start = i
      i = i + 1
      while i < text.length() && !is_fast_inline_special(text, i) {
        i = i + 1
      }
      if start == 0 && i == text.length() {
        sink.emit(Text(text))
      } else {
        sink.emit(Text(text[start:i].to_owned()))
      }
      continue
    }
    let c = char_at(text, i)
    let mut consumed = 0
    match c {
      38 => consumed = fast_entity_inline(text, i, sink)
      42 => consumed = fast_emphasis_inline(text, i, registry, sink)
      60 => consumed = fast_raw_html_inline(text, i, sink)
      91 => consumed = fast_link_inline(text, i, registry, sink)
      92 =>
        if i + 1 < text.length() && is_ascii_punctuation(char_at(text, i + 1)) {
          sink.emit(Text(text[i + 1:i + 2].to_owned()))
          consumed = 2
        }
      96 => consumed = fast_code_span_inline(text, i, sink)
      10 => {
        sink.emit(SoftBreak)
        consumed = 1
      }
      _ => ()
    }
    if consumed == 0 {
      sink.emit(Text(text[i:i + 1].to_owned()))
      i = i + 1
    } else {
      i = i + consumed
    }
  }
}

///|
fn is_fast_inline_special(text : String, index : Int) -> Bool {
  let c = char_at(text, index)
  c == 10 || c == 38 || c == 42 || c == 60 || c == 91 || c == 92 || c == 96
}

///|
fn fast_code_span_inline(text : String, start : Int, sink : EventSink) -> Int {
  let end = find_char(text, 96, start + 1)
  if end < 0 {
    return 0
  }
  sink.emit(Enter(Element::new(tag_name("cm:code_span"))))
  sink.emit(Text(normalize_code_span_fast(text, start + 1, end)))
  sink.emit(Exit(tag_name("cm:code_span")))
  end - start + 1
}

///|
fn fast_element(
  tag : Tag,
  attrs : Array[Attr],
  range : SourceRange?,
) -> Element {
  { tag, attrs, range }
}

///|
fn normalize_code_span_fast(text : String, start : Int, end : Int) -> String {
  let out = StringBuilder::new(size_hint=end - start)
  let mut has_non_space = false
  for i in start..<end {
    if is_space(char_at(text, i)) {
      out.write_string(" ")
    } else {
      has_non_space = true
      out.write_view(text[i:i + 1])
    }
  }
  let normalized = out.to_string()
  if normalized.length() >= 2 &&
    char_at(normalized, 0) == 32 &&
    char_at(normalized, normalized.length() - 1) == 32 &&
    has_non_space {
    normalized[1:normalized.length() - 1].to_owned()
  } else {
    normalized
  }
}

///|
fn fast_emphasis_inline(
  text : String,
  start : Int,
  registry : RuleRegistry,
  sink : EventSink,
) -> Int {
  if start + 1 < text.length() && char_at(text, start + 1) == 42 {
    let end = find_substring(text, "**", start + 2)
    if end >= 0 {
      sink.emit(Enter(Element::new(tag_name("cm:strong"))))
      fast_commonmark_inlines(text[start + 2:end].to_owned(), registry, sink)
      sink.emit(Exit(tag_name("cm:strong")))
      return end - start + 2
    }
  }
  let end = find_char(text, 42, start + 1)
  if end > start {
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
    fast_commonmark_inlines(text[start + 1:end].to_owned(), registry, sink)
    sink.emit(Exit(tag_name("cm:emphasis")))
    return end - start + 1
  }
  0
}

///|
fn fast_link_inline(
  text : String,
  start : Int,
  registry : RuleRegistry,
  sink : EventSink,
) -> Int {
  let close_text = find_char(text, 93, start + 1)
  if close_text < 0 ||
    close_text + 1 >= text.length() ||
    char_at(text, close_text + 1) != 40 {
    return 0
  }
  let close_dest = find_char(text, 41, close_text + 2)
  if close_dest < 0 {
    return 0
  }
  let destination = text[close_text + 2:close_dest].to_owned()
  if destination == "" || contains_unescaped_space(destination) {
    return 0
  }
  sink.emit(
    Enter(
      Element::with_attrs(tag_name("cm:link"), [
        {
          name: attr_name("destination"),
          value: normalize_link_destination(destination),
        },
      ]),
    ),
  )
  fast_commonmark_inlines(text[start + 1:close_text].to_owned(), registry, sink)
  sink.emit(Exit(tag_name("cm:link")))
  close_dest - start + 1
}

///|
fn fast_raw_html_inline(text : String, start : Int, sink : EventSink) -> Int {
  let end = find_char(text, 62, start + 1)
  if end < 0 {
    return 0
  }
  let raw = text[start:end + 1].to_owned()
  if !looks_like_raw_html(raw) {
    return 0
  }
  sink.emit(Html(raw))
  end - start + 1
}

///|
fn fast_entity_inline(text : String, start : Int, sink : EventSink) -> Int {
  let end = find_char(text, 59, start + 1)
  if end < 0 || end - start > 32 {
    return 0
  }
  let name = text[start + 1:end].to_owned()
  match decode_entity(name) {
    Some(decoded) => {
      sink.emit(Text(decoded))
      end - start + 1
    }
    None => 0
  }
}

///|
fn fast_block_range(
  source : LineSource,
  start_line : Int,
  end_line : Int,
) -> SourceRange {
  if start_line >= source.line_starts.length() || end_line <= start_line {
    source_range(0, 0)
  } else {
    let last = end_line - 1
    let end = if last < source.lines.length() &&
      last < source.line_starts.length() {
      source.line_starts[last] + source.lines[last].length()
    } else {
      source.line_starts[start_line]
    }
    source_range(source.line_starts[start_line], end)
  }
}

///|
fn fast_line_range(source : LineSource, line : Int) -> SourceRange {
  source_range(
    source.line_starts[line],
    source.line_starts[line] + source.lines[line].length(),
  )
}

///|
fn commonmark_block_dispatch(ctx : BlockContext, sink : EventSink) -> Int {
  let line = ctx.lines[ctx.index]
  let first = first_non_space_index(line)
  if first < 0 {
    ignore(sink)
    return 1
  }
  let leading = count_leading_spaces(line)
  let c = char_at(line, first)
  if leading <= 3 && (c == 96 || c == 126) {
    let consumed = cm_fenced_code_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if leading >= 4 {
    return cm_indented_code_block(ctx, sink)
  }
  if c == 45 || c == 42 || c == 95 {
    let consumed = cm_thematic_break_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if ctx.index + 1 < ctx.lines.length() {
    let next_first = first_non_space_index(ctx.lines[ctx.index + 1])
    if next_first >= 0 {
      let marker = char_at(ctx.lines[ctx.index + 1], next_first)
      if marker == 45 || marker == 61 {
        let consumed = cm_setext_heading_block(ctx, sink)
        if consumed != 0 {
          return consumed
        }
      }
    }
  }
  if c == 60 {
    let consumed = cm_html_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if c == 35 {
    let consumed = cm_atx_heading_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if c == 62 {
    let consumed = cm_blockquote_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  if c == 45 || c == 42 || c == 43 || (c >= 48 && c <= 57) {
    let consumed = cm_list_block(ctx, sink)
    if consumed != 0 {
      return consumed
    }
  }
  0
}

///|
fn apply_source_core_rules(input : String, registry : RuleRegistry) -> String {
  let mut current = input
  for rule in registry.core_rules() {
    match rule.source_core {
      Some(f) => current = f(current)
      None => ()
    }
  }
  current
}

///|
fn apply_core_rules(
  events : Array[Event],
  registry : RuleRegistry,
) -> Array[Event] {
  let mut current = events
  for rule in registry.core_rules() {
    match rule.core {
      Some(f) => current = f(current)
      None => ()
    }
  }
  current
}

///|
priv struct LineSource {
  lines : Array[String]
  line_starts : Array[Int]
}

///|
fn split_lines(input : String) -> LineSource {
  if input.length() == 0 {
    return { lines: [], line_starts: [] }
  }
  if find_char(input, 10, 0) < 0 {
    return { lines: [input], line_starts: [0] }
  }
  let lines : Array[String] = []
  let line_starts : Array[Int] = []
  let mut offset = 0
  for line in input.split("\n") {
    lines.push(line.to_owned())
    line_starts.push(offset)
    offset = offset + line.length() + 1
  }
  { lines, line_starts }
}
