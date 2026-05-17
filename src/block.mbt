///|
fn cm_paragraph_block(ctx : BlockContext) -> BlockRuleResult {
  let mut i = ctx.index
  while i < ctx.lines.length() &&
        !is_blank(ctx.lines[i]) &&
        (i == ctx.index || !is_paragraph_interrupt(ctx.lines[i])) {
    i = i + 1
  }
  if i == ctx.index {
    block_match(1, EventFragment::empty())
  } else {
    let buffer = Events::new()
    let sink = buffer.sink()
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
      strip_trailing_spaces(paragraph_line(ctx.lines[ctx.index]))
    } else {
      paragraph_text(ctx, i)
    }
    parse_inlines_with_rules(
      inline_text,
      ctx.registry,
      ctx.inline_rules,
      sink,
      ctx.state,
    )
    sink.emit(Exit(tag_name("cm:paragraph")))
    block_match(i - ctx.index, event_fragment_from_events(buffer.collect()))
  }
}

///|
fn paragraph_text(ctx : BlockContext, end : Int) -> String {
  let text = StringBuilder::new()
  for i in ctx.index..<end {
    if i > ctx.index {
      text.write_string("\n")
    }
    let line = paragraph_line(ctx.lines[i])
    if i + 1 == end {
      text.write_string(strip_trailing_spaces(line))
    } else {
      text.write_string(line)
    }
  }
  text.to_string()
}

///|
fn emit_fallback_text(ctx : BlockContext) -> BlockRuleResult {
  block_match(1, EventFragment::text(ctx.lines[ctx.index]))
}

///|
fn paragraph_line(line : String) -> String {
  let leading = count_leading_spaces(line)
  if leading > 0 {
    line[leading:].to_owned()
  } else {
    line
  }
}

///|
fn strip_trailing_spaces(line : String) -> String {
  let mut end = line.length()
  while end > 0 && char_at(line, end - 1) == 32 {
    end = end - 1
  }
  if end == line.length() {
    line
  } else {
    line[:end].to_owned()
  }
}

///|
fn cm_blank_block(ctx : BlockContext) -> BlockRuleResult {
  if is_blank(ctx.lines[ctx.index]) {
    block_match(1, EventFragment::empty())
  } else {
    NoMatch
  }
}

///|
fn cm_atx_heading_block(ctx : BlockContext) -> BlockRuleResult {
  if count_leading_spaces(ctx.lines[ctx.index]) > 3 {
    return NoMatch
  }
  let line = trim(ctx.lines[ctx.index])
  let mut level = 0
  while level < line.length() && level < 6 && char_at(line, level) == 35 {
    level = level + 1
  }
  if level == 0 {
    return NoMatch
  }
  if level < line.length() && !is_space(char_at(line, level)) {
    return NoMatch
  }
  let content = if level >= line.length() {
    ""
  } else {
    trim(strip_closing_hashes(line[level:].to_owned()))
  }
  let buffer = Events::new()
  let sink = buffer.sink()
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:heading"),
        [{ name: attr_name("level"), value: level.to_string() }],
        range=Some(block_source_range(ctx, ctx.index, ctx.index + 1)),
      ),
    ),
  )
  parse_inlines_with_rules(
    content,
    ctx.registry,
    ctx.inline_rules,
    sink,
    ctx.state,
  )
  sink.emit(Exit(tag_name("cm:heading")))
  block_match(1, event_fragment_from_events(buffer.collect()))
}

///|
fn cm_setext_heading_block(ctx : BlockContext) -> BlockRuleResult {
  if !is_setext_heading_paragraph_start(ctx.lines[ctx.index]) {
    return NoMatch
  }
  let underline_index = find_setext_underline(ctx)
  if underline_index < 0 {
    return NoMatch
  }
  let level = setext_heading_level_line(ctx.lines[underline_index])
  let buffer = Events::new()
  let sink = buffer.sink()
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:heading"),
        [{ name: attr_name("level"), value: level.to_string() }],
        range=Some(block_source_range(ctx, ctx.index, underline_index + 1)),
      ),
    ),
  )
  parse_inlines_with_rules(
    setext_heading_content(ctx, underline_index),
    ctx.registry,
    ctx.inline_rules,
    sink,
    ctx.state,
  )
  sink.emit(Exit(tag_name("cm:heading")))
  block_match(
    underline_index - ctx.index + 1,
    event_fragment_from_events(buffer.collect()),
  )
}

///|
fn is_setext_heading_paragraph_start(line : String) -> Bool {
  let trimmed = trim(line)
  trimmed != "" &&
  count_leading_spaces(line) < 4 &&
  !is_ordered_list_marker(trimmed) &&
  !is_unordered_list_marker(trimmed) &&
  !is_paragraph_interrupt(line) &&
  !may_be_reference_definition_line(line)
}

///|
fn find_setext_underline(ctx : BlockContext) -> Int {
  let mut i = ctx.index + 1
  while i < ctx.lines.length() && !is_blank(ctx.lines[i]) {
    if setext_heading_level_line(ctx.lines[i]) > 0 {
      if setext_heading_content(ctx, i) != "" {
        return i
      }
      return -1
    }
    if i > ctx.index && is_paragraph_interrupt(ctx.lines[i]) {
      return -1
    }
    i = i + 1
  }
  -1
}

///|
fn setext_heading_content(ctx : BlockContext, underline_index : Int) -> String {
  let text = StringBuilder::new()
  for i in ctx.index..<underline_index {
    if i > ctx.index {
      text.write_string("\n")
    }
    text.write_string(paragraph_line(ctx.lines[i]))
  }
  trim(text.to_string())
}

///|
fn cm_thematic_break_block(ctx : BlockContext) -> BlockRuleResult {
  let leading = count_leading_spaces(ctx.lines[ctx.index])
  if leading > 3 || leading >= ctx.lines[ctx.index].length() {
    return NoMatch
  }
  if is_thematic_break_at(ctx.lines[ctx.index], leading) {
    block_match(
      1,
      EventFragment::element(
        Element::with_attrs(
          tag_name("cm:thematic_break"),
          [],
          range=Some(block_source_range(ctx, ctx.index, ctx.index + 1)),
        ),
      ),
    )
  } else {
    NoMatch
  }
}

///|
fn setext_heading_level_line(line : String) -> Int {
  let start = count_leading_spaces(line)
  if start > 3 {
    return 0
  }
  let mut end = line.length()
  while end > start && is_space(char_at(line, end - 1)) {
    end = end - 1
  }
  setext_heading_level_at(line, start, end)
}

///|
fn setext_heading_level_at(line : String, start : Int, end : Int) -> Int {
  if line.length() == 0 {
    return 0
  }
  if start >= end {
    return 0
  }
  let c = char_at(line, start)
  if c != 61 && c != 45 {
    return 0
  }
  let mut count = 0
  for i in start..<end {
    let n = char_at(line, i)
    if n == c {
      count = count + 1
    } else {
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
fn cm_html_block(ctx : BlockContext) -> BlockRuleResult {
  if count_leading_spaces(ctx.lines[ctx.index]) > 3 {
    return NoMatch
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
          return block_match(
            i - ctx.index + 1,
            EventFragment::html(raw.to_string()),
          )
        }
        i = i + 1
      }
      return block_match(i - ctx.index, EventFragment::html(raw.to_string()))
    }
    None => ()
  }
  if !looks_like_html_block_start(line) &&
    !looks_like_complete_open_or_close_tag(line) {
    return NoMatch
  }
  let mut i = ctx.index
  let raw = StringBuilder::new()
  while i < ctx.lines.length() && !is_blank(ctx.lines[i]) {
    raw.write_string(ctx.lines[i])
    raw.write_string("\n")
    i = i + 1
  }
  block_match(i - ctx.index, EventFragment::html(raw.to_string()))
}

///|
fn html_block_terminator(line : String) -> String? {
  let tag_end = html_script_pre_style_terminator(line)
  match tag_end {
    Some(terminator) => return Some(terminator)
    None => ()
  }
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
fn html_script_pre_style_terminator(line : String) -> String? {
  if !line.has_prefix("<") {
    return None
  }
  let mut i = 1
  if i >= line.length() || !is_ascii_alpha(char_at(line, i)) {
    return None
  }
  let start = i
  while i < line.length() && is_ascii_alpha(char_at(line, i)) {
    i = i + 1
  }
  let tag = ascii_lower(line[start:i].to_owned())
  if tag == "script" || tag == "style" || tag == "pre" || tag == "textarea" {
    Some("</" + tag + ">")
  } else {
    None
  }
}

///|
fn cm_fenced_code_block(ctx : BlockContext) -> BlockRuleResult {
  let line = ctx.lines[ctx.index]
  let opening_indent = count_leading_spaces(line)
  if opening_indent > 3 {
    return NoMatch
  }
  let trimmed = trim(line)
  let fence = fence_marker(trimmed)
  if fence == "" {
    return NoMatch
  }
  let info = fence_info(trimmed, fence)
  if char_at(fence, 0) == 96 &&
    contains_char(trim(trimmed[fence.length():].to_owned()), 96) {
    return NoMatch
  }
  let mut i = ctx.index + 1
  let code = StringBuilder::new()
  while i < ctx.lines.length() {
    if is_closing_fence_line(ctx.lines[i], fence) {
      return block_match(
        i - ctx.index + 1,
        EventFragment::element(
          Element::with_attrs(
            tag_name("cm:code_block"),
            code_block_attrs(info),
            range=Some(block_source_range(ctx, ctx.index, i + 1)),
          ),
          children=[
            EventFragment::text(finalize_code_block_text(code.to_string())),
          ],
        ),
      )
    }
    if i > ctx.index + 1 {
      code.write_string("\n")
    }
    code.write_string(strip_fenced_code_indent(ctx.lines[i], opening_indent))
    i = i + 1
  }
  block_match(
    i - ctx.index,
    EventFragment::element(
      Element::with_attrs(
        tag_name("cm:code_block"),
        code_block_attrs(info),
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
      children=[EventFragment::text(finalize_code_block_text(code.to_string()))],
    ),
  )
}

///|
fn strip_fenced_code_indent(line : String, indent : Int) -> String {
  let leading = count_leading_spaces(line)
  let strip = if leading < indent { leading } else { indent }
  line[strip:].to_owned()
}

///|
fn cm_indented_code_block(ctx : BlockContext) -> BlockRuleResult {
  let line = ctx.lines[ctx.index]
  if count_leading_spaces(line) < 4 {
    return NoMatch
  }
  let mut i = ctx.index
  let code = StringBuilder::new()
  while i < ctx.lines.length() {
    if is_blank(ctx.lines[i]) {
      if next_nonblank_is_indented_code(ctx.lines, i + 1) {
        if i > ctx.index {
          code.write_string("\n")
        }
        if count_leading_spaces(ctx.lines[i]) >= 4 {
          code.write_view(ctx.lines[i][4:])
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
  block_match(
    i - ctx.index,
    EventFragment::element(
      Element::with_attrs(
        tag_name("cm:code_block"),
        [],
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
      children=[EventFragment::text(finalize_code_block_text(code.to_string()))],
    ),
  )
}

///|
fn finalize_code_block_text(text : String) -> String {
  if text == "" {
    ""
  } else {
    text + "\n"
  }
}

///|
fn next_nonblank_is_indented_code(lines : Array[String], start : Int) -> Bool {
  let mut i = start
  while i < lines.length() {
    if !is_blank(lines[i]) {
      return count_leading_spaces(lines[i]) >= 4
    }
    i = i + 1
  }
  false
}

///|
fn cm_blockquote_block(ctx : BlockContext) -> BlockRuleResult {
  if !is_blockquote_marker_line(ctx.lines[ctx.index]) {
    return NoMatch
  }
  let mut i = ctx.index
  let mut used_lazy = false
  let inner = StringBuilder::new()
  while i < ctx.lines.length() && is_blockquote_marker_line(ctx.lines[i]) {
    if i > ctx.index {
      inner.write_string("\n")
    }
    let stripped = strip_blockquote_marker(ctx.lines[i])
    inner.write_string(stripped)
    i = i + 1
    let allow_lazy = stripped != "" &&
      count_leading_spaces(stripped) < 4 &&
      (
        !is_paragraph_interrupt(stripped) ||
        is_blockquote_marker_line(stripped) ||
        is_ordered_list_marker(trim(stripped)) ||
        is_unordered_list_marker(trim(stripped))
      )
    while i < ctx.lines.length() &&
          !is_blank(ctx.lines[i]) &&
          !is_blockquote_marker_line(ctx.lines[i]) &&
          allow_lazy &&
          !is_paragraph_interrupt(ctx.lines[i]) {
      inner.write_string("\n")
      inner.write_string(paragraph_line(ctx.lines[i]))
      used_lazy = true
      i = i + 1
    }
  }
  let buffer = Events::new()
  let sink = buffer.sink()
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
  match parse_reference_definition(trim(inner_text)) {
    Some(definition) => ctx.state.add_reference(definition)
    None =>
      if used_lazy && blockquote_inner_starts_with_block(inner_text) {
        parse_blocks_into(inner_text, ctx.registry, sink, ctx.state)
      } else if used_lazy {
        sink.emit(Enter(Element::new(tag_name("cm:paragraph"))))
        parse_inlines_with_rules(
          inner_text,
          ctx.registry,
          ctx.inline_rules,
          sink,
          ctx.state,
        )
        sink.emit(Exit(tag_name("cm:paragraph")))
      } else if inner_text != "" &&
        !contains_char(inner_text, 10) &&
        count_leading_spaces(inner_text) < 4 &&
        !is_paragraph_interrupt(inner_text) {
        sink.emit(Enter(Element::new(tag_name("cm:paragraph"))))
        parse_inlines_with_rules(
          paragraph_line(inner_text),
          ctx.registry,
          ctx.inline_rules,
          sink,
          ctx.state,
        )
        sink.emit(Exit(tag_name("cm:paragraph")))
      } else {
        parse_blocks_into(inner_text, ctx.registry, sink, ctx.state)
      }
  }
  sink.emit(Exit(tag_name("cm:block_quote")))
  block_match(i - ctx.index, event_fragment_from_events(buffer.collect()))
}

///|
fn blockquote_inner_starts_with_block(text : String) -> Bool {
  let first_break = find_char(text, 10, 0)
  let first = if first_break < 0 { text } else { text[:first_break].to_owned() }
  is_paragraph_interrupt(first)
}

///|
fn is_blockquote_marker_line(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 && leading < line.length() && char_at(line, leading) == 62
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
fn strip_blockquote_marker(line : String) -> String {
  let first = first_non_space_index(line)
  let stripped = trim(line)
  if first < 0 || stripped.length() == 0 {
    return ""
  }
  let mut pos = first + 1
  let mut column = first + 1
  let mut prefix_spaces = 0
  if pos < line.length() && char_at(line, pos) == 32 {
    pos = pos + 1
    column = column + 1
  } else if pos < line.length() && char_at(line, pos) == 9 {
    let spaces = 4 - column % 4
    pos = pos + 1
    column = column + spaces
    prefix_spaces = if pos < line.length() && char_at(line, pos) == 9 {
      column - first - 2
    } else {
      0
    }
  }
  expand_tabs_from_column(line[pos:].to_owned(), column, prefix_spaces)
}

///|
fn expand_tabs_from_column(
  text : String,
  start_column : Int,
  prefix_spaces : Int,
) -> String {
  let out = StringBuilder::new(size_hint=text.length() + prefix_spaces + 4)
  for _ in 0..<prefix_spaces {
    out.write_string(" ")
  }
  let mut column = start_column
  for i in 0..<text.length() {
    if char_at(text, i) == 9 {
      let spaces = 4 - column % 4
      for _ in 0..<spaces {
        out.write_string(" ")
      }
      column = column + spaces
    } else {
      out.write_view(text[i:i + 1])
      column = column + 1
    }
  }
  out.to_string()
}

///|
fn is_paragraph_interrupt(line : String) -> Bool {
  is_blockquote_marker_line(line) ||
  is_unordered_list_marker_line(line) ||
  is_ordered_list_paragraph_interrupt(line) ||
  is_thematic_break_marker_line(line) ||
  is_fence_marker_line(line) ||
  is_atx_heading_marker_line(line) ||
  is_html_block_paragraph_interrupt(line)
}

///|
fn is_atx_heading_start_at(line : String, start : Int) -> Bool {
  let mut level = 0
  while start + level < line.length() &&
        level < 6 &&
        char_at(line, start + level) == 35 {
    level = level + 1
  }
  level > 0 &&
  (start + level >= line.length() || is_space(char_at(line, start + level)))
}

///|
fn is_atx_heading_marker_line(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 && is_atx_heading_start_at(line, leading)
}

///|
fn is_thematic_break_marker_line(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 && leading < line.length() && is_thematic_break_at(line, leading)
}

///|
fn is_fence_marker_line(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 && has_fence_marker_at(line, leading)
}

///|
fn is_html_block_paragraph_interrupt(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  if leading > 3 || leading >= line.length() || char_at(line, leading) != 60 {
    return false
  }
  let trimmed = if leading == 0 { line } else { line[leading:].to_owned() }
  html_block_terminator(trimmed) != None || looks_like_html_block_start(trimmed)
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
fn looks_like_complete_open_or_close_tag(line : String) -> Bool {
  match raw_html_tag_end(line, 0) {
    Some(end) => {
      let rest = trim(line[end:].to_owned())
      rest == ""
    }
    None => false
  }
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
fn has_fence_marker_at(line : String, start : Int) -> Bool {
  if start + 3 > line.length() {
    return false
  }
  let marker = char_at(line, start)
  if marker != 96 && marker != 126 {
    return false
  }
  let mut length = 0
  while start + length < line.length() &&
        char_at(line, start + length) == marker {
    length = length + 1
  }
  length >= 3
}

///|
fn is_closing_fence_at(line : String, opening : String, start : Int) -> Bool {
  if opening == "" || line.length() < opening.length() {
    return false
  }
  let marker = char_at(opening, 0)
  let mut length = 0
  while start + length < line.length() &&
        char_at(line, start + length) == marker {
    length = length + 1
  }
  if length < opening.length() {
    return false
  }
  for i in (start + length)..<line.length() {
    if !is_space(char_at(line, i)) {
      return false
    }
  }
  true
}

///|
fn is_closing_fence_line(line : String, opening : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 && is_closing_fence_at(line, opening, leading)
}

///|
fn fence_info(line : String, fence : String) -> String {
  let rest = trim(line[fence.length():].to_owned())
  let mut end = 0
  while end < rest.length() && !is_space(char_at(rest, end)) {
    end = end + 1
  }
  normalize_attribute_text(rest[:end].to_owned())
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
fn is_thematic_break_at(line : String, start : Int) -> Bool {
  let c = char_at(line, start)
  if c != 45 && c != 42 && c != 95 {
    return false
  }
  let mut count = 0
  for i in start..<line.length() {
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
