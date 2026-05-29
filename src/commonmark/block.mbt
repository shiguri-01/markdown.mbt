///|
fn paragraph_block(ctx : BlockContext) -> BlockRuleResult {
  let end = for i in ctx.line_index()..<ctx.source_lines().length() {
    if is_blank(ctx.source_lines()[i]) ||
      (i != ctx.line_index() && is_paragraph_interrupt(ctx.source_lines()[i])) {
      break i
    }
  } nobreak {
    ctx.source_lines().length()
  }
  if end == ctx.line_index() {
    block_match(1, @markdown.EventFragment::empty())
  } else if ctx.is_collecting() {
    block_match(end - ctx.line_index(), @markdown.EventFragment::empty())
  } else {
    let buffer = @markdown.Events()
    let sink = buffer.owned_sink()
    sink.emit(
      @markdown.Enter(
        @markdown.Element::with_attrs(
          tag_name("cm:paragraph"),
          [],
          range=Some(block_source_range(ctx, ctx.line_index(), end)),
        ),
      ),
    )
    let inline_text = if end == ctx.line_index() + 1 {
      strip_trailing_spaces(
        paragraph_line(ctx.source_lines()[ctx.line_index()]),
      )
    } else {
      paragraph_text(ctx, end)
    }
    ctx.services().parse_inline(inline_text, sink)
    sink.emit(@markdown.Exit(tag_name("cm:paragraph")))
    block_match(end - ctx.line_index(), buffer.into_fragment())
  }
}

///|
fn paragraph_text(ctx : BlockContext, end : Int) -> String {
  let text = StringBuilder::new()
  for i in ctx.line_index()..<end {
    if i > ctx.line_index() {
      text.write_string("\n")
    }
    let line = paragraph_line(ctx.source_lines()[i])
    if i + 1 == end {
      text.write_string(strip_trailing_spaces(line))
    } else {
      text.write_string(line)
    }
  }
  text.to_string()
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
  let end = for end in line.length()>=..1 {
    if char_at(line, end - 1) != ' ' {
      break end
    }
  } nobreak {
    0
  }
  if end == line.length() {
    line
  } else {
    line[:end].to_owned()
  }
}

///|
fn blank_block(ctx : BlockContext) -> BlockRuleResult {
  if is_blank(ctx.source_lines()[ctx.line_index()]) {
    block_match(1, @markdown.EventFragment::empty())
  } else {
    NoMatch
  }
}

///|
fn atx_heading_block(ctx : BlockContext) -> BlockRuleResult {
  guard count_leading_spaces(ctx.source_lines()[ctx.line_index()]) <= 3 else {
    NoMatch
  }
  let line = trim(ctx.source_lines()[ctx.line_index()])
  let level = marker_run_length_limit(line, 0, '#', 6)
  guard level > 0 else { NoMatch }
  guard level >= line.length() || is_space(char_at(line, level)) else {
    NoMatch
  }
  if ctx.is_collecting() {
    return block_match(1, @markdown.EventFragment::empty())
  }
  let content = if level >= line.length() {
    ""
  } else {
    trim(strip_closing_hashes(line[level:].to_owned()))
  }
  let buffer = @markdown.Events()
  let sink = buffer.owned_sink()
  sink.emit(
    @markdown.Enter(
      @markdown.Element::with_attrs(
        tag_name("cm:heading"),
        [attr("level", heading_level_value(level))],
        range=Some(
          block_source_range(ctx, ctx.line_index(), ctx.line_index() + 1),
        ),
      ),
    ),
  )
  ctx.services().parse_inline(content, sink)
  sink.emit(@markdown.Exit(tag_name("cm:heading")))
  block_match(1, buffer.into_fragment())
}

///|
fn setext_heading_block(ctx : BlockContext) -> BlockRuleResult {
  guard is_setext_heading_paragraph_start(ctx.source_lines()[ctx.line_index()]) else {
    NoMatch
  }
  let underline_index = find_setext_underline(ctx)
  guard underline_index >= 0 else { NoMatch }
  if ctx.is_collecting() {
    return block_match(
      underline_index - ctx.line_index() + 1,
      @markdown.EventFragment::empty(),
    )
  }
  let level = setext_heading_level_line(ctx.source_lines()[underline_index])
  let buffer = @markdown.Events()
  let sink = buffer.owned_sink()
  sink.emit(
    @markdown.Enter(
      @markdown.Element::with_attrs(
        tag_name("cm:heading"),
        [attr("level", heading_level_value(level))],
        range=Some(
          block_source_range(ctx, ctx.line_index(), underline_index + 1),
        ),
      ),
    ),
  )
  ctx
  .services()
  .parse_inline(setext_heading_content(ctx, underline_index), sink)
  sink.emit(@markdown.Exit(tag_name("cm:heading")))
  block_match(underline_index - ctx.line_index() + 1, buffer.into_fragment())
}

///|
fn heading_level_value(level : Int) -> String {
  match level {
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    _ => level.to_string()
  }
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
  for i in (ctx.line_index() + 1)..<ctx.source_lines().length() {
    if is_blank(ctx.source_lines()[i]) {
      break -1
    }
    if setext_heading_level_line(ctx.source_lines()[i]) > 0 {
      if setext_heading_content(ctx, i) != "" {
        break i
      }
      break -1
    }
    if i > ctx.line_index() && is_paragraph_interrupt(ctx.source_lines()[i]) {
      break -1
    }
  } nobreak {
    -1
  }
}

///|
fn setext_heading_content(ctx : BlockContext, underline_index : Int) -> String {
  let text = StringBuilder::new()
  for i in ctx.line_index()..<underline_index {
    if i > ctx.line_index() {
      text.write_string("\n")
    }
    text.write_string(paragraph_line(ctx.source_lines()[i]))
  }
  trim(text.to_string())
}

///|
fn thematic_break_block(ctx : BlockContext) -> BlockRuleResult {
  let leading = count_leading_spaces(ctx.source_lines()[ctx.line_index()])
  guard leading <= 3 && leading < ctx.source_lines()[ctx.line_index()].length() else {
    NoMatch
  }
  guard is_thematic_break_at(ctx.source_lines()[ctx.line_index()], leading) else {
    NoMatch
  }
  if ctx.is_collecting() {
    return block_match(1, @markdown.EventFragment::empty())
  }
  block_match(
    1,
    @markdown.EventFragment::element(
      @markdown.Element::with_attrs(
        tag_name("cm:thematic_break"),
        [],
        range=Some(
          block_source_range(ctx, ctx.line_index(), ctx.line_index() + 1),
        ),
      ),
    ),
  )
}

///|
fn setext_heading_level_line(line : String) -> Int {
  let start = count_leading_spaces(line)
  guard start <= 3 else { 0 }
  let end = for end in line.length()>=..(start + 1) {
    if !is_space(char_at(line, end - 1)) {
      break end
    }
  } nobreak {
    start
  }
  setext_heading_level_at(line, start, end)
}

///|
fn setext_heading_level_at(line : String, start : Int, end : Int) -> Int {
  guard line.length() > 0 else { 0 }
  guard start < end else { 0 }
  let c = char_at(line, start)
  guard c == '=' || c == '-' else { 0 }
  let mut count = 0
  for i in start..<end {
    let n = char_at(line, i)
    if n == c {
      count = count + 1
    } else {
      break 0
    }
  } nobreak {
    if count == 0 {
      0
    } else if c == '=' {
      1
    } else {
      2
    }
  }
}

///|
fn html_block(ctx : BlockContext) -> BlockRuleResult {
  let raw_line = ctx.source_lines()[ctx.line_index()]
  let leading = count_leading_spaces(raw_line)
  guard leading <= 3 &&
    leading < raw_line.length() &&
    char_at(raw_line, leading) == '<' else {
    NoMatch
  }
  let line = if leading == 0 { raw_line } else { raw_line[leading:].to_owned() }
  if html_block_terminator(line) is Some(terminator) {
    return html_block_until_terminator(ctx, terminator)
  }
  guard looks_like_html_block_start(line) ||
    looks_like_complete_open_or_close_tag(line) else {
    NoMatch
  }
  html_block_until_blank(ctx)
}

///|
fn html_block_until_terminator(
  ctx : BlockContext,
  terminator : String,
) -> BlockRuleResult {
  if ctx.is_collecting() {
    for i in ctx.line_index()..<ctx.source_lines().length() {
      if find_substring(ctx.source_lines()[i], terminator, 0) >= 0 {
        return block_match(
          i - ctx.line_index() + 1,
          @markdown.EventFragment::empty(),
        )
      }
    }
    return block_match(
      ctx.source_lines().length() - ctx.line_index(),
      @markdown.EventFragment::empty(),
    )
  }
  let raw = StringBuilder::new()
  for i in ctx.line_index()..<ctx.source_lines().length() {
    raw.write_string(ctx.source_lines()[i])
    raw.write_string("\n")
    if find_substring(ctx.source_lines()[i], terminator, 0) >= 0 {
      return block_match(
        i - ctx.line_index() + 1,
        @markdown.EventFragment::html(raw.to_string()),
      )
    }
  }
  block_match(
    ctx.source_lines().length() - ctx.line_index(),
    @markdown.EventFragment::html(raw.to_string()),
  )
}

///|
fn html_block_until_blank(ctx : BlockContext) -> BlockRuleResult {
  if ctx.is_collecting() {
    for i in ctx.line_index()..<ctx.source_lines().length() {
      if is_blank(ctx.source_lines()[i]) {
        return block_match(
          i - ctx.line_index(),
          @markdown.EventFragment::empty(),
        )
      }
    }
    return block_match(
      ctx.source_lines().length() - ctx.line_index(),
      @markdown.EventFragment::empty(),
    )
  }
  let raw = StringBuilder::new()
  for i in ctx.line_index()..<ctx.source_lines().length() {
    if is_blank(ctx.source_lines()[i]) {
      return block_match(
        i - ctx.line_index(),
        @markdown.EventFragment::html(raw.to_string()),
      )
    }
    raw.write_string(ctx.source_lines()[i])
    raw.write_string("\n")
  }
  block_match(
    ctx.source_lines().length() - ctx.line_index(),
    @markdown.EventFragment::html(raw.to_string()),
  )
}

///|
fn html_block_terminator(line : String) -> String? {
  guard line.length() > 0 && char_at(line, 0) == '<' else { None }
  if html_script_pre_style_terminator(line) is Some(terminator) {
    return Some(terminator)
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
  guard line.has_prefix("<") else { None }
  guard line.length() > 1 && is_ascii_alpha(char_at(line, 1)) else { None }
  let end = for end in 1..<line.length() {
    if !is_ascii_alpha(char_at(line, end)) {
      break end
    }
  } nobreak {
    line.length()
  }
  let tag = ascii_lower(line[1:end].to_owned())
  match tag {
    "script" => Some("</script>")
    "style" => Some("</style>")
    "pre" => Some("</pre>")
    "textarea" => Some("</textarea>")
    _ => None
  }
}

///|
fn fenced_code_block(ctx : BlockContext) -> BlockRuleResult {
  let line = ctx.source_lines()[ctx.line_index()]
  let opening_indent = count_leading_spaces(line)
  guard opening_indent <= 3 else { NoMatch }
  let trimmed = trim(line)
  let fence = fence_marker(trimmed)
  guard fence != "" else { NoMatch }
  guard !(char_at(fence, 0) == '`' &&
    contains_char(trim(trimmed[fence.length():].to_owned()), '`')) else {
    NoMatch
  }
  if ctx.is_collecting() {
    for i in (ctx.line_index() + 1)..<ctx.source_lines().length() {
      if is_closing_fence_line(ctx.source_lines()[i], fence) {
        return block_match(
          i - ctx.line_index() + 1,
          @markdown.EventFragment::empty(),
        )
      }
    }
    return block_match(
      ctx.source_lines().length() - ctx.line_index(),
      @markdown.EventFragment::empty(),
    )
  }
  let info = fence_info(trimmed, fence)
  let code = StringBuilder::new()
  for i in (ctx.line_index() + 1)..<ctx.source_lines().length() {
    if is_closing_fence_line(ctx.source_lines()[i], fence) {
      return block_match(
        i - ctx.line_index() + 1,
        @markdown.EventFragment::element(
          @markdown.Element::with_attrs(
            tag_name("cm:code_block"),
            code_block_attrs(info),
            range=Some(block_source_range(ctx, ctx.line_index(), i + 1)),
          ),
          children=[
            @markdown.EventFragment::text(
              finalize_code_block_text(code.to_string()),
            ),
          ],
        ),
      )
    }
    if i > ctx.line_index() + 1 {
      code.write_string("\n")
    }
    code.write_string(
      strip_fenced_code_indent(ctx.source_lines()[i], opening_indent),
    )
  }
  block_match(
    ctx.source_lines().length() - ctx.line_index(),
    @markdown.EventFragment::element(
      @markdown.Element::with_attrs(
        tag_name("cm:code_block"),
        code_block_attrs(info),
        range=Some(
          block_source_range(ctx, ctx.line_index(), ctx.source_lines().length()),
        ),
      ),
      children=[
        @markdown.EventFragment::text(
          finalize_code_block_text(code.to_string()),
        ),
      ],
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
fn indented_code_block(ctx : BlockContext) -> BlockRuleResult {
  let line = ctx.source_lines()[ctx.line_index()]
  guard count_leading_spaces(line) >= 4 else { NoMatch }
  if ctx.is_collecting() {
    let mut i = ctx.line_index()
    while i < ctx.source_lines().length() {
      if is_blank(ctx.source_lines()[i]) {
        if next_nonblank_is_indented_code(ctx.source_lines(), i + 1) {
          i = i + 1
          continue
        }
        break
      }
      if count_leading_spaces(ctx.source_lines()[i]) < 4 {
        break
      }
      i = i + 1
    }
    return block_match(i - ctx.line_index(), @markdown.EventFragment::empty())
  }
  let code = StringBuilder::new()
  let mut i = ctx.line_index()
  while i < ctx.source_lines().length() {
    if is_blank(ctx.source_lines()[i]) {
      if next_nonblank_is_indented_code(ctx.source_lines(), i + 1) {
        if i > ctx.line_index() {
          code.write_string("\n")
        }
        if count_leading_spaces(ctx.source_lines()[i]) >= 4 {
          code.write_view(ctx.source_lines()[i][4:])
        }
        i = i + 1
        continue
      } else {
        break
      }
    }
    if count_leading_spaces(ctx.source_lines()[i]) < 4 {
      break
    }
    if i > ctx.line_index() {
      code.write_string("\n")
    }
    code.write_view(ctx.source_lines()[i][4:])
    i = i + 1
  }
  block_match(
    i - ctx.line_index(),
    @markdown.EventFragment::element(
      @markdown.Element::with_attrs(
        tag_name("cm:code_block"),
        [],
        range=Some(block_source_range(ctx, ctx.line_index(), i)),
      ),
      children=[
        @markdown.EventFragment::text(
          finalize_code_block_text(code.to_string()),
        ),
      ],
    ),
  )
}

///|
fn finalize_code_block_text(text : String) -> String {
  match text {
    "" => ""
    _ => text + "\n"
  }
}

///|
fn next_nonblank_is_indented_code(lines : Array[String], start : Int) -> Bool {
  for i in start..<lines.length() {
    if !is_blank(lines[i]) {
      break count_leading_spaces(lines[i]) >= 4
    }
  } nobreak {
    false
  }
}

///|
fn blockquote_block(ctx : BlockContext) -> BlockRuleResult {
  guard is_blockquote_marker_line(ctx.source_lines()[ctx.line_index()]) else {
    NoMatch
  }
  let mut i = ctx.line_index()
  let mut used_lazy = false
  let first = strip_blockquote_marker(ctx.source_lines()[i])
  if is_single_line_blockquote(ctx, first, i + 1) {
    return emit_single_line_blockquote(ctx, first)
  }
  let inner = BlockPayload(first)
  i = i + 1
  let result = append_blockquote_lazy_lines(ctx, inner, first, i)
  i = result.next_index
  if result.used_lazy {
    used_lazy = true
  }
  while i < ctx.source_lines().length() &&
        is_blockquote_marker_line(ctx.source_lines()[i]) {
    let stripped = strip_blockquote_marker(ctx.source_lines()[i])
    inner.append(stripped)
    i = i + 1
    let result = append_blockquote_lazy_lines(ctx, inner, stripped, i)
    i = result.next_index
    if result.used_lazy {
      used_lazy = true
    }
  }
  if ctx.is_collecting() && !inner.may_contain_reference {
    return block_match(i - ctx.line_index(), @markdown.EventFragment::empty())
  }
  if ctx.is_collecting() {
    inner.collect_references(ctx.services())
    return block_match(i - ctx.line_index(), @markdown.EventFragment::empty())
  }
  let buffer = @markdown.Events()
  let sink = buffer.owned_sink()
  sink.emit(
    @markdown.Enter(
      @markdown.Element::with_attrs(
        tag_name("cm:block_quote"),
        [],
        range=Some(block_source_range(ctx, ctx.line_index(), i)),
      ),
    ),
  )
  let lazy_starts_with_block = used_lazy &&
    blockquote_inner_starts_with_block(inner)
  let inner_text = if inner.may_contain_reference ||
    (used_lazy && !lazy_starts_with_block) {
    inner.to_text()
  } else {
    ""
  }
  if parse_reference_definition(trim(inner_text)) is Some(definition) {
    add_reference(ctx.services(), definition)
  } else if lazy_starts_with_block {
    inner.parse_into(ctx.services(), sink)
  } else if used_lazy {
    sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:paragraph"))))
    ctx.services().parse_inline(inner_text, sink)
    sink.emit(@markdown.Exit(tag_name("cm:paragraph")))
  } else if inner.length == 1 &&
    inner.first != "" &&
    count_leading_spaces(inner.first) < 4 &&
    !is_paragraph_interrupt(inner.first) {
    sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:paragraph"))))
    ctx.services().parse_inline(paragraph_line(inner.first), sink)
    sink.emit(@markdown.Exit(tag_name("cm:paragraph")))
  } else {
    inner.parse_into(ctx.services(), sink)
  }
  sink.emit(@markdown.Exit(tag_name("cm:block_quote")))
  block_match(i - ctx.line_index(), buffer.into_fragment())
}

///|
fn is_single_line_blockquote(
  ctx : BlockContext,
  stripped : String,
  next : Int,
) -> Bool {
  if next >= ctx.source_lines().length() ||
    is_blockquote_marker_line(ctx.source_lines()[next]) {
    return next >= ctx.source_lines().length()
  }
  is_blank(ctx.source_lines()[next]) ||
  !blockquote_allows_lazy(stripped) ||
  is_paragraph_interrupt(ctx.source_lines()[next])
}

///|
fn emit_single_line_blockquote(
  ctx : BlockContext,
  inner : String,
) -> BlockRuleResult {
  if ctx.is_collecting() {
    if may_contain_reference_definition(inner) {
      let payload = BlockPayload(inner)
      payload.collect_references(ctx.services())
    }
    return block_match(1, @markdown.EventFragment::empty())
  }
  let buffer = @markdown.Events()
  let sink = buffer.owned_sink()
  sink.emit(
    @markdown.Enter(
      @markdown.Element::with_attrs(
        tag_name("cm:block_quote"),
        [],
        range=Some(
          block_source_range(ctx, ctx.line_index(), ctx.line_index() + 1),
        ),
      ),
    ),
  )
  if may_contain_reference_definition(inner) {
    if parse_reference_definition(trim(inner)) is Some(definition) {
      add_reference(ctx.services(), definition)
    } else {
      emit_single_line_blockquote_content(ctx, inner, sink)
    }
  } else {
    emit_single_line_blockquote_content(ctx, inner, sink)
  }
  sink.emit(@markdown.Exit(tag_name("cm:block_quote")))
  block_match(1, buffer.into_fragment())
}

///|
fn emit_single_line_blockquote_content(
  ctx : BlockContext,
  inner : String,
  sink : Sink,
) -> Unit {
  if inner != "" &&
    count_leading_spaces(inner) < 4 &&
    !is_paragraph_interrupt(inner) {
    sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:paragraph"))))
    ctx.services().parse_inline(paragraph_line(inner), sink)
    sink.emit(@markdown.Exit(tag_name("cm:paragraph")))
  } else {
    BlockPayload(inner).parse_into(ctx.services(), sink)
  }
}

///|
priv struct BlockquoteLazyResult {
  next_index : Int
  used_lazy : Bool
}

///|
fn append_blockquote_lazy_lines(
  ctx : BlockContext,
  inner : BlockPayload,
  stripped : String,
  start : Int,
) -> BlockquoteLazyResult {
  let allow_lazy = blockquote_allows_lazy(stripped)
  let mut i = start
  let mut used_lazy = false
  while i < ctx.source_lines().length() &&
        !is_blank(ctx.source_lines()[i]) &&
        !is_blockquote_marker_line(ctx.source_lines()[i]) &&
        allow_lazy &&
        !is_paragraph_interrupt(ctx.source_lines()[i]) {
    inner.append(paragraph_line(ctx.source_lines()[i]))
    used_lazy = true
    i = i + 1
  }
  { next_index: i, used_lazy }
}

///|
fn blockquote_allows_lazy(stripped : String) -> Bool {
  stripped != "" &&
  count_leading_spaces(stripped) < 4 &&
  (
    !is_paragraph_interrupt(stripped) ||
    is_blockquote_marker_line(stripped) ||
    is_ordered_list_marker(trim(stripped)) ||
    is_unordered_list_marker(trim(stripped))
  )
}

///|
fn blockquote_inner_starts_with_block(inner : BlockPayload) -> Bool {
  is_paragraph_interrupt(inner.first)
}

///|
fn is_blockquote_marker_line(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 && leading < line.length() && char_at(line, leading) == '>'
}

///|
fn block_source_range(
  ctx : BlockContext,
  start_line : Int,
  end_line : Int,
) -> SourceRange {
  if start_line >= ctx.source_line_starts().length() || end_line <= start_line {
    source_range(0, 0)
  } else {
    let last = end_line - 1
    let end = if last < ctx.source_lines().length() &&
      last < ctx.source_line_starts().length() {
      ctx.source_line_starts()[last] + ctx.source_lines()[last].length()
    } else {
      ctx.source_line_starts()[start_line]
    }
    source_range(ctx.source_line_starts()[start_line], end)
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
  if pos < line.length() {
    match char_at(line, pos) {
      ' ' => {
        pos = pos + 1
        column = column + 1
      }
      '\t' => {
        let spaces = 4 - column % 4
        pos = pos + 1
        column = column + spaces
        prefix_spaces = if pos < line.length() && char_at(line, pos) == '\t' {
          column - first - 2
        } else {
          0
        }
      }
      _ => ()
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
  guard prefix_spaces > 0 || find_char(text, '\t', 0) >= 0 else { text }
  let out = StringBuilder::new(size_hint=text.length() + prefix_spaces + 4)
  for _ in 0..<prefix_spaces {
    out.write_string(" ")
  }
  let mut column = start_column
  for i in 0..<text.length() {
    match char_at(text, i) {
      '\t' => {
        let spaces = 4 - column % 4
        for _ in 0..<spaces {
          out.write_string(" ")
        }
        column = column + spaces
      }
      _ => {
        out.write_view(text[i:i + 1])
        column = column + 1
      }
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
  let level = marker_run_length_limit(line, start, '#', 6)
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
  guard leading <= 3 && leading < line.length() && char_at(line, leading) == '<' else {
    false
  }
  let trimmed = if leading == 0 { line } else { line[leading:].to_owned() }
  html_block_terminator(trimmed) is Some(_) ||
  looks_like_html_block_start(trimmed)
}

///|
fn looks_like_html_block_start(line : String) -> Bool {
  guard line.length() >= 3 && char_at(line, 0) == '<' else { false }
  let start = if char_at(line, 1) == '/' { 2 } else { 1 }
  guard start < line.length() && is_ascii_alpha(char_at(line, start)) else {
    false
  }
  let end = for end in start..<line.length() {
    if !(is_ascii_alpha(char_at(line, end)) ||
      is_ascii_digit(char_at(line, end))) {
      break end
    }
  } nobreak {
    line.length()
  }
  is_html_block_tag(ascii_lower(line[start:end].to_owned())) &&
  (
    end >= line.length() ||
    is_space(char_at(line, end)) ||
    char_at(line, end) == '>' ||
    char_at(line, end) == '/'
  )
}

///|
fn looks_like_complete_open_or_close_tag(line : String) -> Bool {
  if raw_html_tag_end(line, 0) is Some(end) {
    let rest = trim(line[end:].to_owned())
    rest == ""
  } else {
    false
  }
}

///|
fn looks_like_html_declaration(line : String) -> Bool {
  line.length() >= 3 &&
  char_at(line, 0) == '<' &&
  char_at(line, 1) == '!' &&
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
  guard line.length() >= 3 else { "" }
  let marker = char_at(line, 0)
  guard marker == '`' || marker == '~' else { "" }
  let length = marker_run_length(line, 0, marker)
  if length >= 3 {
    line[:length].to_owned()
  } else {
    ""
  }
}

///|
fn has_fence_marker_at(line : String, start : Int) -> Bool {
  guard start + 3 <= line.length() else { false }
  let marker = char_at(line, start)
  guard marker == '`' || marker == '~' else { false }
  let length = marker_run_length(line, start, marker)
  length >= 3
}

///|
fn is_closing_fence_at(line : String, opening : String, start : Int) -> Bool {
  guard opening != "" && line.length() >= opening.length() else { false }
  let marker = char_at(opening, 0)
  let length = marker_run_length(line, start, marker)
  guard length >= opening.length() else { false }
  for i in (start + length)..<line.length() {
    if !is_space(char_at(line, i)) {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn marker_run_length(line : String, start : Int, marker : Int) -> Int {
  for i in start..<line.length() {
    if char_at(line, i) != marker {
      break i - start
    }
  } nobreak {
    line.length() - start
  }
}

///|
fn marker_run_length_limit(
  line : String,
  start : Int,
  marker : Int,
  limit : Int,
) -> Int {
  let stop = if start + limit < line.length() {
    start + limit
  } else {
    line.length()
  }
  for i in start..<stop {
    if char_at(line, i) != marker {
      break i - start
    }
  } nobreak {
    let remaining = line.length() - start
    if remaining < limit {
      remaining
    } else {
      limit
    }
  }
}

///|
fn is_closing_fence_line(line : String, opening : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 && is_closing_fence_at(line, opening, leading)
}

///|
fn fence_info(line : String, fence : String) -> String {
  let rest = trim(line[fence.length():].to_owned())
  let end = for end in 0..<rest.length() {
    if is_space(char_at(rest, end)) {
      break end
    }
  } nobreak {
    rest.length()
  }
  normalize_attribute_text(rest[:end].to_owned())
}

///|
fn code_block_attrs(info : String) -> Array[Attr] {
  match info {
    "" => []
    _ => [attr("info", info)]
  }
}

///|
fn is_thematic_break_at(line : String, start : Int) -> Bool {
  let c = char_at(line, start)
  guard c == '-' || c == '*' || c == '_' else { false }
  let mut count = 0
  for i in start..<line.length() {
    let n = char_at(line, i)
    if n == c {
      count = count + 1
    } else if !is_space(n) {
      break false
    }
  } nobreak {
    count >= 3
  }
}

///|
fn strip_closing_hashes(line : String) -> String {
  let end = for end in line.length()>=..1 {
    if !is_space(char_at(line, end - 1)) {
      break end
    }
  } nobreak {
    0
  }
  let hash_start = for hash_start in end>=..1 {
    if char_at(line, hash_start - 1) != '#' {
      break hash_start
    }
  } nobreak {
    0
  }
  if hash_start == end ||
    hash_start == 0 ||
    !is_space(char_at(line, hash_start - 1)) {
    line
  } else {
    line[:hash_start].to_owned()
  }
}
