///|
fn cm_paragraph_block(ctx : BlockContext, sink : EventSink) -> Int {
  let mut i = ctx.index
  while i < ctx.lines.length() &&
        trim(ctx.lines[i]) != "" &&
        (i == ctx.index || !is_paragraph_interrupt(ctx.lines[i])) {
    i = i + 1
  }
  if i == ctx.index {
    1
  } else {
    sink.emit(
      Enter(
        Element::with_attrs(
          tag_name("cm:paragraph"),
          [],
          range=Some(block_source_range(ctx, ctx.index, i)),
        ),
      ),
    )
    let inline_text = if i == ctx.index + 1 {
      paragraph_line(ctx.lines[ctx.index])
    } else {
      paragraph_text(ctx, i)
    }
    parse_inlines_with_rules(inline_text, ctx.registry, ctx.inline_rules, sink)
    sink.emit(Exit(tag_name("cm:paragraph")))
    i - ctx.index
  }
}

///|
fn paragraph_text(ctx : BlockContext, end : Int) -> String {
  let text = StringBuilder::new()
  for i in ctx.index..<end {
    if i > ctx.index {
      text.write_string("\n")
    }
    text.write_string(paragraph_line(ctx.lines[i]))
  }
  text.to_string()
}

///|
fn emit_fallback_text(ctx : BlockContext, sink : EventSink) -> Int {
  sink.emit(Text(ctx.lines[ctx.index]))
  1
}

///|
fn paragraph_line(line : String) -> String {
  let leading = count_leading_spaces(line)
  if leading > 0 && leading <= 3 {
    line[leading:].to_owned()
  } else {
    line
  }
}

///|
fn cm_blank_block(ctx : BlockContext, _sink : EventSink) -> Int {
  if trim(ctx.lines[ctx.index]) == "" {
    1
  } else {
    0
  }
}

///|
fn cm_atx_heading_block(ctx : BlockContext, sink : EventSink) -> Int {
  if count_leading_spaces(ctx.lines[ctx.index]) > 3 {
    return 0
  }
  let line = trim(ctx.lines[ctx.index])
  let mut level = 0
  while level < line.length() && level < 6 && char_at(line, level) == 35 {
    level = level + 1
  }
  if level == 0 {
    return 0
  }
  if level < line.length() && !is_space(char_at(line, level)) {
    return 0
  }
  let content = if level >= line.length() {
    ""
  } else {
    trim(strip_closing_hashes(line[level:].to_owned()))
  }
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:heading"),
        [{ name: attr_name("level"), value: level.to_string() }],
        range=Some(block_source_range(ctx, ctx.index, ctx.index + 1)),
      ),
    ),
  )
  parse_inlines_with_rules(content, ctx.registry, ctx.inline_rules, sink)
  sink.emit(Exit(tag_name("cm:heading")))
  1
}

///|
fn cm_setext_heading_block(ctx : BlockContext, sink : EventSink) -> Int {
  if ctx.index + 1 >= ctx.lines.length() {
    return 0
  }
  if count_leading_spaces(ctx.lines[ctx.index + 1]) > 3 {
    return 0
  }
  let content = paragraph_line(ctx.lines[ctx.index])
  let underline = trim(ctx.lines[ctx.index + 1])
  let level = setext_heading_level(underline)
  if trim(content) == "" || level == 0 {
    return 0
  }
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:heading"),
        [{ name: attr_name("level"), value: level.to_string() }],
        range=Some(block_source_range(ctx, ctx.index, ctx.index + 2)),
      ),
    ),
  )
  parse_inlines_with_rules(trim(content), ctx.registry, ctx.inline_rules, sink)
  sink.emit(Exit(tag_name("cm:heading")))
  2
}

///|
fn cm_thematic_break_block(ctx : BlockContext, sink : EventSink) -> Int {
  if count_leading_spaces(ctx.lines[ctx.index]) > 3 {
    return 0
  }
  let line = trim(ctx.lines[ctx.index])
  if is_thematic_break(line) {
    sink.emit(
      Enter(
        Element::with_attrs(
          tag_name("cm:thematic_break"),
          [],
          range=Some(block_source_range(ctx, ctx.index, ctx.index + 1)),
        ),
      ),
    )
    sink.emit(Exit(tag_name("cm:thematic_break")))
    1
  } else {
    0
  }
}

///|
fn setext_heading_level(line : String) -> Int {
  if line.length() == 0 {
    return 0
  }
  let c = first_non_space_char(line)
  if c != 61 && c != 45 {
    return 0
  }
  let mut count = 0
  for i in 0..<line.length() {
    let n = char_at(line, i)
    if n == c {
      count = count + 1
    } else if !is_space(n) {
      return 0
    }
  }
  if count == 0 {
    0
  } else if c == 61 {
    1
  } else {
    2
  }
}

///|
fn first_non_space_char(line : String) -> Int {
  for i in 0..<line.length() {
    if !is_space(char_at(line, i)) {
      return char_at(line, i)
    }
  }
  0
}

///|
fn cm_html_block(ctx : BlockContext, sink : EventSink) -> Int {
  if count_leading_spaces(ctx.lines[ctx.index]) > 3 {
    return 0
  }
  let line = trim(ctx.lines[ctx.index])
  match html_block_terminator(line) {
    Some(terminator) => {
      let mut i = ctx.index
      let raw = StringBuilder::new()
      while i < ctx.lines.length() {
        raw.write_string(ctx.lines[i])
        raw.write_string("\n")
        if find_substring(ctx.lines[i], terminator, 0) >= 0 {
          sink.emit(Html(raw.to_string()))
          return i - ctx.index + 1
        }
        i = i + 1
      }
      sink.emit(Html(raw.to_string()))
      return i - ctx.index
    }
    None => ()
  }
  if !looks_like_html_block_start(line) {
    return 0
  }
  let mut i = ctx.index
  let raw = StringBuilder::new()
  while i < ctx.lines.length() && trim(ctx.lines[i]) != "" {
    raw.write_string(ctx.lines[i])
    raw.write_string("\n")
    i = i + 1
  }
  sink.emit(Html(raw.to_string()))
  i - ctx.index
}

///|
fn html_block_terminator(line : String) -> String? {
  if line.has_prefix("<!--") {
    Some("-->")
  } else if line.has_prefix("<?") {
    Some("?>")
  } else if line.has_prefix("<![CDATA[") {
    Some("]]>")
  } else if looks_like_html_declaration(line) {
    Some(">")
  } else {
    None
  }
}

///|
fn cm_fenced_code_block(ctx : BlockContext, sink : EventSink) -> Int {
  let line = ctx.lines[ctx.index]
  let opening_indent = count_leading_spaces(line)
  if opening_indent > 3 {
    return 0
  }
  let trimmed = trim(line)
  let fence = fence_marker(trimmed)
  if fence == "" {
    return 0
  }
  let info = fence_info(trimmed, fence)
  if char_at(fence, 0) == 96 && contains_char(info, 96) {
    return 0
  }
  let mut i = ctx.index + 1
  let code = StringBuilder::new()
  while i < ctx.lines.length() {
    if is_closing_fence_line(ctx.lines[i], fence) {
      sink.emit(
        Enter(
          Element::with_attrs(
            tag_name("cm:code_block"),
            code_block_attrs(info),
            range=Some(block_source_range(ctx, ctx.index, i + 1)),
          ),
        ),
      )
      sink.emit(Text(code.to_string()))
      sink.emit(Exit(tag_name("cm:code_block")))
      return i - ctx.index + 1
    }
    if i > ctx.index + 1 {
      code.write_string("\n")
    }
    code.write_string(strip_fenced_code_indent(ctx.lines[i], opening_indent))
    i = i + 1
  }
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:code_block"),
        code_block_attrs(info),
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
    ),
  )
  sink.emit(Text(code.to_string()))
  sink.emit(Exit(tag_name("cm:code_block")))
  i - ctx.index
}

///|
fn strip_fenced_code_indent(line : String, indent : Int) -> String {
  let leading = count_leading_spaces(line)
  let strip = if leading < indent { leading } else { indent }
  line[strip:].to_owned()
}

///|
fn cm_indented_code_block(ctx : BlockContext, sink : EventSink) -> Int {
  let line = ctx.lines[ctx.index]
  if count_leading_spaces(line) < 4 {
    return 0
  }
  let mut i = ctx.index
  let code = StringBuilder::new()
  while i < ctx.lines.length() {
    if trim(ctx.lines[i]) == "" {
      if next_nonblank_is_indented_code(ctx.lines, i + 1) {
        if i > ctx.index {
          code.write_string("\n")
        }
        i = i + 1
        continue
      } else {
        break
      }
    }
    if count_leading_spaces(ctx.lines[i]) < 4 {
      break
    }
    if i > ctx.index {
      code.write_string("\n")
    }
    code.write_view(ctx.lines[i][4:])
    i = i + 1
  }
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:code_block"),
        [],
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
    ),
  )
  sink.emit(Text(code.to_string()))
  sink.emit(Exit(tag_name("cm:code_block")))
  i - ctx.index
}

///|
fn next_nonblank_is_indented_code(lines : Array[String], start : Int) -> Bool {
  let mut i = start
  while i < lines.length() {
    if trim(lines[i]) != "" {
      return count_leading_spaces(lines[i]) >= 4
    }
    i = i + 1
  }
  false
}

///|
fn cm_blockquote_block(ctx : BlockContext, sink : EventSink) -> Int {
  if !is_blockquote_marker_line(ctx.lines[ctx.index]) {
    return 0
  }
  let mut i = ctx.index
  let inner = StringBuilder::new()
  while i < ctx.lines.length() && is_blockquote_marker_line(ctx.lines[i]) {
    if i > ctx.index {
      inner.write_string("\n")
    }
    inner.write_string(strip_blockquote_marker(ctx.lines[i]))
    i = i + 1
    while i < ctx.lines.length() &&
          trim(ctx.lines[i]) != "" &&
          !trim(ctx.lines[i]).has_prefix(">") &&
          !is_paragraph_interrupt(ctx.lines[i]) {
      inner.write_string("\n")
      inner.write_string(paragraph_line(ctx.lines[i]))
      i = i + 1
    }
  }
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:block_quote"),
        [],
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
    ),
  )
  let inner_text = inner.to_string()
  if inner_text != "" &&
    !contains_char(inner_text, 10) &&
    !is_paragraph_interrupt(inner_text) {
    sink.emit(Enter(Element::new(tag_name("cm:paragraph"))))
    parse_inlines_with_rules(inner_text, ctx.registry, ctx.inline_rules, sink)
    sink.emit(Exit(tag_name("cm:paragraph")))
  } else {
    let events = parse_blocks(inner_text, ctx.registry)
    for event in events {
      sink.emit(event)
    }
  }
  sink.emit(Exit(tag_name("cm:block_quote")))
  i - ctx.index
}

///|
fn is_blockquote_marker_line(line : String) -> Bool {
  count_leading_spaces(line) <= 3 && trim(line).has_prefix(">")
}

///|
fn block_source_range(
  ctx : BlockContext,
  start_line : Int,
  end_line : Int,
) -> SourceRange {
  if start_line >= ctx.line_starts.length() || end_line <= start_line {
    source_range(0, 0)
  } else {
    let last = end_line - 1
    let end = if last < ctx.lines.length() && last < ctx.line_starts.length() {
      ctx.line_starts[last] + ctx.lines[last].length()
    } else {
      ctx.line_starts[start_line]
    }
    source_range(ctx.line_starts[start_line], end)
  }
}

///|
fn cm_list_block(ctx : BlockContext, sink : EventSink) -> Int {
  if count_leading_spaces(ctx.lines[ctx.index]) > 3 {
    return 0
  }
  let line = trim(ctx.lines[ctx.index])
  let ordered = is_ordered_list_marker(line)
  let unordered = is_unordered_list_marker(line)
  if !ordered && !unordered {
    return 0
  }
  let ordered_delimiter = if ordered { ordered_list_delimiter(line) } else { 0 }
  let unordered_delimiter = if unordered { char_at(line, 0) } else { 0 }
  let list_attrs = list_attrs(ordered, line)
  let mut i = ctx.index
  let mut loose = false
  let item_texts : Array[String] = []
  let item_starts : Array[Int] = []
  let item_ends : Array[Int] = []
  while i < ctx.lines.length() {
    let item_start = i
    if count_leading_spaces(ctx.lines[i]) > 3 {
      break
    }
    let current = trim(ctx.lines[i])
    if !same_list_marker(
        current, ordered, ordered_delimiter, unordered_delimiter,
      ) {
      break
    }
    let item = if ordered {
      strip_ordered_marker(current)
    } else {
      strip_unordered_marker(current)
    }
    let mut item_text = trim(item)
    i = i + 1
    let continuation = collect_list_continuation(ctx.lines, i, true)
    item_text = item_text + continuation.text
    i = continuation.next_index
    let mut item_end = i
    let mut blank_count = 0
    while i < ctx.lines.length() && trim(ctx.lines[i]) == "" {
      blank_count = blank_count + 1
      i = i + 1
    }
    if blank_count > 0 &&
      i < ctx.lines.length() &&
      is_list_continuation_after_blank(ctx.lines[i]) {
      loose = true
      for _ in 0..<blank_count {
        item_text = item_text + "\n"
      }
      let continuation = collect_list_continuation(ctx.lines, i, false)
      item_text = item_text + continuation.text
      i = continuation.next_index
      item_end = i
    } else if blank_count > 0 &&
      i < ctx.lines.length() &&
      same_list_marker(
        trim(ctx.lines[i]),
        ordered,
        ordered_delimiter,
        unordered_delimiter,
      ) {
      loose = true
    } else if blank_count > 0 {
      i = item_end
    }
    item_texts.push(item_text)
    item_starts.push(item_start)
    item_ends.push(item_end)
  }
  let list_events : EventSink = { events: [] }
  for n in 0..<item_texts.length() {
    list_events.emit(
      Enter(
        Element::with_attrs(
          tag_name("cm:item"),
          [],
          range=Some(block_source_range(ctx, item_starts[n], item_ends[n])),
        ),
      ),
    )
    emit_list_item_content(
      item_texts[n],
      ctx.registry,
      ctx.inline_rules,
      list_events,
      loose~,
    )
    list_events.emit(Exit(tag_name("cm:item")))
  }
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:list"),
        list_attrs,
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
    ),
  )
  for event in list_events.events {
    sink.emit(event)
  }
  sink.emit(Exit(tag_name("cm:list")))
  i - ctx.index
}

///|
fn emit_list_item_content(
  item_text : String,
  registry : RuleRegistry,
  inline_rules : Array[Rule],
  sink : EventSink,
  loose? : Bool = false,
) -> Unit {
  if !loose &&
    item_text != "" &&
    !contains_char(item_text, 10) &&
    !is_paragraph_interrupt(item_text) {
    parse_inlines_with_rules(item_text, registry, inline_rules, sink)
    return
  }
  let events = parse_blocks(item_text, registry)
  if !loose && events.length() >= 2 && is_single_paragraph_events(events) {
    for i in 1..<(events.length() - 1) {
      sink.emit(events[i])
    }
  } else {
    for event in events {
      sink.emit(event)
    }
  }
}

///|
priv struct ListContinuation {
  text : String
  next_index : Int
}

///|
fn collect_list_continuation(
  lines : Array[String],
  start : Int,
  allow_lazy : Bool,
) -> ListContinuation {
  let mut i = start
  let text = StringBuilder::new()
  while i < lines.length() &&
        trim(lines[i]) != "" &&
        !is_ordered_list_marker(trim(lines[i])) &&
        !is_unordered_list_marker(trim(lines[i])) {
    if count_leading_spaces(lines[i]) >= 2 {
      text.write_string("\n")
      text.write_view(lines[i][2:])
      i = i + 1
    } else if allow_lazy && !is_paragraph_interrupt(lines[i]) {
      text.write_string("\n")
      text.write_string(paragraph_line(lines[i]))
      i = i + 1
    } else {
      break
    }
  }
  { text: text.to_string(), next_index: i }
}

///|
fn is_list_continuation_after_blank(line : String) -> Bool {
  trim(line) != "" &&
  count_leading_spaces(line) >= 2 &&
  !is_ordered_list_marker(trim(line)) &&
  !is_unordered_list_marker(trim(line))
}

///|
fn same_list_marker(
  line : String,
  ordered : Bool,
  ordered_delimiter : Int,
  unordered_delimiter : Int,
) -> Bool {
  if ordered {
    is_ordered_list_marker(line) &&
    ordered_list_delimiter(line) == ordered_delimiter
  } else {
    is_unordered_list_marker(line) && char_at(line, 0) == unordered_delimiter
  }
}

///|
fn is_single_paragraph_events(events : Array[Event]) -> Bool {
  match events[0] {
    Enter(el) => if el.tag.value != "cm:paragraph" { return false }
    _ => return false
  }
  match events[events.length() - 1] {
    Exit(tag) => if tag.value != "cm:paragraph" { return false }
    _ => return false
  }
  let mut depth = 0
  for i in 0..<events.length() {
    match events[i] {
      Enter(_) => depth = depth + 1
      Exit(_) => {
        depth = depth - 1
        if depth == 0 && i < events.length() - 1 {
          return false
        }
      }
      _ => ()
    }
  }
  depth == 0
}

///|
fn strip_blockquote_marker(line : String) -> String {
  let stripped = trim(line)
  if stripped.length() > 1 && is_space(char_at(stripped, 1)) {
    stripped[2:].to_owned()
  } else {
    stripped[1:].to_owned()
  }
}

///|
fn is_paragraph_interrupt(line : String) -> Bool {
  is_blockquote_marker_line(line) ||
  is_unordered_list_marker_line(line) ||
  is_ordered_list_paragraph_interrupt(line) ||
  is_thematic_break_marker_line(line) ||
  is_fence_marker_line(line) ||
  is_atx_heading_marker_line(line)
}

///|
fn is_ordered_list_paragraph_interrupt(line : String) -> Bool {
  count_leading_spaces(line) <= 3 &&
  is_ordered_list_marker(trim(line)) &&
  ordered_list_start(trim(line)) == 1
}

///|
fn is_unordered_list_marker_line(line : String) -> Bool {
  count_leading_spaces(line) <= 3 && is_unordered_list_marker(trim(line))
}

///|
fn is_atx_heading_start(line : String) -> Bool {
  let mut level = 0
  while level < line.length() && level < 6 && char_at(line, level) == 35 {
    level = level + 1
  }
  level > 0 && (level >= line.length() || is_space(char_at(line, level)))
}

///|
fn is_atx_heading_marker_line(line : String) -> Bool {
  count_leading_spaces(line) <= 3 && is_atx_heading_start(trim(line))
}

///|
fn is_thematic_break_marker_line(line : String) -> Bool {
  count_leading_spaces(line) <= 3 && is_thematic_break(trim(line))
}

///|
fn is_fence_marker_line(line : String) -> Bool {
  count_leading_spaces(line) <= 3 && fence_marker(trim(line)) != ""
}

///|
fn looks_like_html_block_start(line : String) -> Bool {
  if line.length() < 3 || char_at(line, 0) != 60 {
    return false
  }
  let mut i = 1
  if char_at(line, i) == 47 {
    i = i + 1
  }
  if i >= line.length() || !is_ascii_alpha(char_at(line, i)) {
    return false
  }
  let start = i
  while i < line.length() &&
        (is_ascii_alpha(char_at(line, i)) || is_ascii_digit(char_at(line, i))) {
    i = i + 1
  }
  is_html_block_tag(ascii_lower(line[start:i].to_owned())) &&
  (
    i >= line.length() ||
    is_space(char_at(line, i)) ||
    char_at(line, i) == 62 ||
    char_at(line, i) == 47
  )
}

///|
fn looks_like_html_declaration(line : String) -> Bool {
  line.length() >= 3 &&
  char_at(line, 0) == 60 &&
  char_at(line, 1) == 33 &&
  is_ascii_alpha(char_at(line, 2))
}

///|
fn is_html_block_tag(tag : String) -> Bool {
  tag == "address" ||
  tag == "article" ||
  tag == "aside" ||
  tag == "base" ||
  tag == "basefont" ||
  tag == "blockquote" ||
  tag == "body" ||
  tag == "caption" ||
  tag == "center" ||
  tag == "col" ||
  tag == "colgroup" ||
  tag == "dd" ||
  tag == "details" ||
  tag == "dialog" ||
  tag == "dir" ||
  tag == "div" ||
  tag == "dl" ||
  tag == "dt" ||
  tag == "fieldset" ||
  tag == "figcaption" ||
  tag == "figure" ||
  tag == "footer" ||
  tag == "form" ||
  tag == "frame" ||
  tag == "frameset" ||
  tag == "h1" ||
  tag == "h2" ||
  tag == "h3" ||
  tag == "h4" ||
  tag == "h5" ||
  tag == "h6" ||
  tag == "head" ||
  tag == "header" ||
  tag == "hr" ||
  tag == "html" ||
  tag == "iframe" ||
  tag == "legend" ||
  tag == "li" ||
  tag == "link" ||
  tag == "main" ||
  tag == "menu" ||
  tag == "menuitem" ||
  tag == "nav" ||
  tag == "noframes" ||
  tag == "ol" ||
  tag == "optgroup" ||
  tag == "option" ||
  tag == "p" ||
  tag == "param" ||
  tag == "search" ||
  tag == "section" ||
  tag == "summary" ||
  tag == "table" ||
  tag == "tbody" ||
  tag == "td" ||
  tag == "tfoot" ||
  tag == "th" ||
  tag == "thead" ||
  tag == "title" ||
  tag == "tr" ||
  tag == "track" ||
  tag == "ul"
}

///|
fn is_unordered_list_marker(line : String) -> Bool {
  line.length() >= 1 &&
  (char_at(line, 0) == 45 || char_at(line, 0) == 42 || char_at(line, 0) == 43) &&
  (line.length() == 1 || is_space(char_at(line, 1)))
}

///|
fn strip_unordered_marker(line : String) -> String {
  if line.length() <= 1 {
    ""
  } else {
    line[2:].to_owned()
  }
}

///|
fn list_attrs(ordered : Bool, line : String) -> Array[Attr] {
  let attrs = [
    {
      name: attr_name("ordered"),
      value: if ordered {
        "true"
      } else {
        "false"
      },
    },
  ]
  if ordered {
    attrs.push({
      name: attr_name("start"),
      value: ordered_list_start(line).to_string(),
    })
  }
  attrs
}

///|
fn is_ordered_list_marker(line : String) -> Bool {
  let marker = ordered_marker_end(line)
  marker > 0 &&
  marker < line.length() &&
  (char_at(line, marker) == 46 || char_at(line, marker) == 41) &&
  (marker + 1 >= line.length() || is_space(char_at(line, marker + 1)))
}

///|
fn ordered_list_start(line : String) -> Int {
  let marker = ordered_marker_end(line)
  let mut value = 0
  for i in 0..<marker {
    value = value * 10 + char_at(line, i) - 48
  }
  value
}

///|
fn ordered_list_delimiter(line : String) -> Int {
  let marker = ordered_marker_end(line)
  if marker >= 0 && marker < line.length() {
    char_at(line, marker)
  } else {
    0
  }
}

///|
fn strip_ordered_marker(line : String) -> String {
  let marker = ordered_marker_end(line)
  if marker + 2 > line.length() {
    ""
  } else {
    line[marker + 2:].to_owned()
  }
}

///|
fn ordered_marker_end(line : String) -> Int {
  let mut i = 0
  while i < line.length() && char_at(line, i) >= 48 && char_at(line, i) <= 57 {
    i = i + 1
  }
  if i == 0 || i > 9 {
    -1
  } else {
    i
  }
}

///|
fn fence_marker(line : String) -> String {
  if line.length() < 3 {
    return ""
  }
  let marker = char_at(line, 0)
  if marker != 96 && marker != 126 {
    return ""
  }
  let mut length = 0
  while length < line.length() && char_at(line, length) == marker {
    length = length + 1
  }
  if length >= 3 {
    line[:length].to_owned()
  } else {
    ""
  }
}

///|
fn is_closing_fence(line : String, opening : String) -> Bool {
  if opening == "" || line.length() < opening.length() {
    return false
  }
  let marker = char_at(opening, 0)
  let mut length = 0
  while length < line.length() && char_at(line, length) == marker {
    length = length + 1
  }
  if length < opening.length() {
    return false
  }
  for i in length..<line.length() {
    if !is_space(char_at(line, i)) {
      return false
    }
  }
  true
}

///|
fn is_closing_fence_line(line : String, opening : String) -> Bool {
  count_leading_spaces(line) <= 3 && is_closing_fence(trim(line), opening)
}

///|
fn fence_info(line : String, fence : String) -> String {
  let rest = trim(line[fence.length():].to_owned())
  let mut end = 0
  while end < rest.length() && !is_space(char_at(rest, end)) {
    end = end + 1
  }
  rest[:end].to_owned()
}

///|
fn code_block_attrs(info : String) -> Array[Attr] {
  if info == "" {
    []
  } else {
    [{ name: attr_name("info"), value: info }]
  }
}

///|
fn contains_char(text : String, needle : Int) -> Bool {
  find_char(text, needle, 0) >= 0
}

///|
fn is_thematic_break(line : String) -> Bool {
  let c = char_at(line, 0)
  if c != 45 && c != 42 && c != 95 {
    return false
  }
  let mut count = 0
  for i in 0..<line.length() {
    let n = char_at(line, i)
    if n == c {
      count = count + 1
    } else if !is_space(n) {
      return false
    }
  }
  count >= 3
}

///|
fn strip_closing_hashes(line : String) -> String {
  let mut end = line.length()
  while end > 0 && is_space(char_at(line, end - 1)) {
    end = end - 1
  }
  let mut hash_start = end
  while hash_start > 0 && char_at(line, hash_start - 1) == 35 {
    hash_start = hash_start - 1
  }
  if hash_start == end ||
    hash_start == 0 ||
    !is_space(char_at(line, hash_start - 1)) {
    line
  } else {
    line[:hash_start].to_owned()
  }
}
