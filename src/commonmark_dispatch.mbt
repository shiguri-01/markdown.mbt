///|
fn commonmark_block_dispatch(ctx : BlockContext) -> BlockRuleResult {
  let line = ctx.lines[ctx.index]
  let first = first_non_space_index(line)
  if first < 0 {
    return block_match(1, EventFragment::empty())
  }
  let leading = count_leading_spaces(line)
  let c = char_at(line, first)
  if leading <= 3 && (c == 96 || c == 126) {
    let result = cm_fenced_code_block(ctx)
    match result {
      Match(_, _) => return result
      NoMatch => ()
    }
  }
  if leading >= 4 {
    return cm_indented_code_block(ctx)
  }
  if c == 45 || c == 42 || c == 95 {
    let result = cm_thematic_break_block(ctx)
    match result {
      Match(_, _) => return result
      NoMatch => ()
    }
  }
  if ctx.index + 1 < ctx.lines.length() {
    let next_first = first_non_space_index(ctx.lines[ctx.index + 1])
    if next_first >= 0 {
      let marker = char_at(ctx.lines[ctx.index + 1], next_first)
      if marker == 45 || marker == 61 {
        let result = cm_setext_heading_block(ctx)
        match result {
          Match(_, _) => return result
          NoMatch => ()
        }
      }
    }
  }
  if c == 60 {
    let result = cm_html_block(ctx)
    match result {
      Match(_, _) => return result
      NoMatch => ()
    }
  }
  if c == 35 {
    let result = cm_atx_heading_block(ctx)
    match result {
      Match(_, _) => return result
      NoMatch => ()
    }
  }
  if c == 62 {
    let result = cm_blockquote_block(ctx)
    match result {
      Match(_, _) => return result
      NoMatch => ()
    }
  }
  if c == 45 || c == 42 || c == 43 || (c >= 48 && c <= 57) {
    let result = cm_list_block(ctx)
    match result {
      Match(_, _) => return result
      NoMatch => ()
    }
  }
  NoMatch
}
