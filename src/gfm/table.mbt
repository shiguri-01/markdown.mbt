///|
priv struct TableData {
  header : Array[String]
  aligns : Array[String]
  rows : Array[Array[String]]
  end_index : Int
}

///|
fn table_block(ctx : BlockContext) -> BlockRuleResult {
  guard ctx.line_index() + 1 < ctx.line_count() else { NoMatch }
  let header_line = ctx.current_line()
  guard count_leading_spaces(header_line) <= 3 else { NoMatch }
  guard contains_char(header_line, '|') else { NoMatch }
  let delimiter_line = match ctx.line(1) {
    Some(line) => line
    None => return NoMatch
  }
  let header = split_table_row(header_line)
  let aligns = parse_delimiter_row(delimiter_line)
  guard aligns.length() > 0 && header.length() == aligns.length() else {
    NoMatch
  }
  if ctx.is_collecting() {
    return block_match(
      table_end_index(ctx, ctx.line_index() + 2) - ctx.line_index(),
      @markdown.EventFragment::empty(),
    )
  }
  let data = collect_table_data(ctx, header, aligns)
  let buffer = @markdown.Events()
  let sink = buffer.owned_sink()
  emit_table(data, ctx, sink)
  block_match(data.end_index - ctx.line_index(), buffer.into_fragment())
}

///|
fn collect_table_data(
  ctx : BlockContext,
  header : Array[String],
  aligns : Array[String],
) -> TableData {
  let rows : Array[Array[String]] = []
  let mut i = ctx.line_index() + 2
  while i < ctx.line_count() &&
        !is_blank(ctx.source_lines()[i]) &&
        !is_table_terminating_block_start(ctx.source_lines()[i]) {
    rows.push(
      normalize_table_row(
        split_table_row(ctx.source_lines()[i]),
        header.length(),
      ),
    )
    i = i + 1
  }
  { header, aligns, rows, end_index: i }
}

///|
fn table_end_index(ctx : BlockContext, start : Int) -> Int {
  let mut i = start
  while i < ctx.line_count() &&
        !is_blank(ctx.source_lines()[i]) &&
        !is_table_terminating_block_start(ctx.source_lines()[i]) {
    i = i + 1
  }
  i
}

///|
fn emit_table(data : TableData, ctx : BlockContext, sink : Sink) -> Unit {
  sink.emit(@markdown.Enter(@markdown.Element(tag_name("gfm:table"))))
  sink.emit(@markdown.Enter(@markdown.Element(tag_name("gfm:thead"))))
  emit_table_row(data.header, data.aligns, "gfm:th", ctx, sink)
  sink.emit(@markdown.Exit(tag_name("gfm:thead")))
  if data.rows.length() > 0 {
    sink.emit(@markdown.Enter(@markdown.Element(tag_name("gfm:tbody"))))
    for row in data.rows {
      emit_table_row(row, data.aligns, "gfm:td", ctx, sink)
    }
    sink.emit(@markdown.Exit(tag_name("gfm:tbody")))
  }
  sink.emit(@markdown.Exit(tag_name("gfm:table")))
}

///|
fn emit_table_row(
  cells : Array[String],
  aligns : Array[String],
  cell_tag : String,
  ctx : BlockContext,
  sink : Sink,
) -> Unit {
  sink.emit(@markdown.Enter(@markdown.Element(tag_name("gfm:tr"))))
  for i in 0..<aligns.length() {
    let attrs = if aligns[i] == "" { [] } else { [attr("align", aligns[i])] }
    sink.emit(
      @markdown.Enter(@markdown.Element::with_attrs(tag_name(cell_tag), attrs)),
    )
    ctx.services().parse_inline(unescape_table_cell(cells[i]), sink)
    sink.emit(@markdown.Exit(tag_name(cell_tag)))
  }
  sink.emit(@markdown.Exit(tag_name("gfm:tr")))
}

///|
fn normalize_table_row(cells : Array[String], width : Int) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<width {
    if i < cells.length() {
      out.push(cells[i])
    } else {
      out.push("")
    }
  }
  out
}

///|
fn split_table_row(line : String) -> Array[String] {
  let trimmed = trim(line)
  let start = if trimmed.length() > 0 && char_at(trimmed, 0) == '|' {
    1
  } else {
    0
  }
  let end = if trimmed.length() > start &&
    char_at(trimmed, trimmed.length() - 1) == '|' &&
    !is_escaped_char(trimmed, trimmed.length() - 1) {
    trimmed.length() - 1
  } else {
    trimmed.length()
  }
  let cells : Array[String] = []
  let mut cell_start = start
  let mut i = start
  while i < end {
    if char_at(trimmed, i) == '|' && !is_escaped_char(trimmed, i) {
      cells.push(trim(trimmed[cell_start:i].to_owned()))
      cell_start = i + 1
    }
    i = i + 1
  }
  cells.push(trim(trimmed[cell_start:end].to_owned()))
  cells
}

///|
fn parse_delimiter_row(line : String) -> Array[String] {
  let cells = split_table_row(line)
  let aligns : Array[String] = []
  for cell in cells {
    let align = parse_delimiter_cell(cell)
    if align is None {
      return []
    }
    match align {
      Some(value) => aligns.push(value)
      None => ()
    }
  }
  aligns
}

///|
fn parse_delimiter_cell(cell : String) -> String? {
  let text = trim(cell)
  guard text.length() >= 1 else { None }
  let mut i = 0
  let left = if char_at(text, i) == ':' {
    i = i + 1
    true
  } else {
    false
  }
  let mut hyphens = 0
  while i < text.length() && char_at(text, i) == '-' {
    hyphens = hyphens + 1
    i = i + 1
  }
  guard hyphens >= 1 else { None }
  let right = if i < text.length() && char_at(text, i) == ':' {
    i = i + 1
    true
  } else {
    false
  }
  guard i == text.length() else { None }
  if left && right {
    Some("center")
  } else if right {
    Some("right")
  } else if left {
    Some("left")
  } else {
    Some("")
  }
}

///|
fn unescape_table_cell(cell : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < cell.length() {
    if i + 1 < cell.length() &&
      char_at(cell, i) == '\\' &&
      char_at(cell, i + 1) == '|' {
      out <+ "|"
      i = i + 2
    } else {
      out <+ "\{cell[i:i + 1].to_owned()}"
      i = i + 1
    }
  }
  out.to_string()
}

///|
fn is_table_terminating_block_start(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  if leading > 3 {
    return false
  }
  let text = trim(line)
  text == "" ||
  has_prefix_at(text, ">", 0) ||
  has_prefix_at(text, "#", 0) ||
  has_prefix_at(text, "```", 0) ||
  has_prefix_at(text, "~~~", 0) ||
  has_prefix_at(text, "<", 0) ||
  is_unordered_marker(text) ||
  is_ordered_marker(text) ||
  is_thematic_break(text)
}

///|
fn is_unordered_marker(text : String) -> Bool {
  text.length() >= 2 &&
  (
    char_at(text, 0) == '-' ||
    char_at(text, 0) == '*' ||
    char_at(text, 0) == '+'
  ) &&
  is_space(char_at(text, 1))
}

///|
fn is_ordered_marker(text : String) -> Bool {
  let mut i = 0
  while i < text.length() && char_at(text, i) >= '0' && char_at(text, i) <= '9' {
    i = i + 1
  }
  i > 0 &&
  i + 1 < text.length() &&
  (char_at(text, i) == '.' || char_at(text, i) == ')') &&
  is_space(char_at(text, i + 1))
}

///|
fn is_thematic_break(text : String) -> Bool {
  guard text.length() >= 3 else { false }
  let marker = char_at(text, 0)
  guard marker == '-' || marker == '*' || marker == '_' else { false }
  let mut count = 0
  for i in 0..<text.length() {
    let c = char_at(text, i)
    if c == marker {
      count = count + 1
    } else if !is_space(c) {
      return false
    }
  }
  count >= 3
}
