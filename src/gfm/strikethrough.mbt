///|
fn strikethrough_delimiter(
  ctx : InlineContext,
  sink : Sink,
) -> InlineRuleResult {
  let text = ctx.source()
  let start = ctx.offset()
  guard char_at(text, start) == '~' else { NoMatch }
  guard start == 0 || char_at(text, start - 1) != '~' else { NoMatch }
  let run = tilde_run_length(text, start)
  let width = if run >= 2 { 2 } else { 1 }
  let close = find_strikethrough_close(text, start + width, width)
  guard close >= 0 else { NoMatch }
  guard close > start + width else { NoMatch }
  sink.emit(@markdown.Enter(@markdown.Element(tag_name("gfm:strikethrough"))))
  ctx.services().parse_inline(text[start + width:close].to_owned(), sink)
  sink.emit(@markdown.Exit(tag_name("gfm:strikethrough")))
  inline_match(close - start + width)
}

///|
fn tilde_run_length(text : String, start : Int) -> Int {
  let mut end = start
  while end < text.length() && char_at(text, end) == '~' {
    end = end + 1
  }
  end - start
}

///|
fn find_strikethrough_close(text : String, start : Int, width : Int) -> Int {
  let mut i = start
  while i + width <= text.length() {
    if char_at(text, i) == '`' {
      let next = code_span_end(text, i)
      if next > i {
        i = next
        continue
      }
    }
    if char_at(text, i) == '~' &&
      tilde_run_length(text, i) >= width &&
      !is_escaped_char(text, i) {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn code_span_end(text : String, start : Int) -> Int {
  let width = backtick_run_length(text, start)
  let mut i = start + width
  while i < text.length() {
    if char_at(text, i) == '`' {
      let close_width = backtick_run_length(text, i)
      if close_width == width {
        return i + close_width
      }
      i = i + close_width
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn backtick_run_length(text : String, start : Int) -> Int {
  let mut end = start
  while end < text.length() && char_at(text, end) == '`' {
    end = end + 1
  }
  end - start
}
