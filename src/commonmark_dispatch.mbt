///|
fn commonmark_block_dispatch(ctx : BlockContext, sink : Sink) -> Int {
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
