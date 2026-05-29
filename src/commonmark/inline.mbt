///|
fn text_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let start = ctx.offset()
  let has_extension_triggers = ctx.has_inline_triggers_other_than(
    commonmark_inline_trigger_chars(),
  )
  guard start < text.length() &&
    !is_non_space_special(char_at(text, start)) &&
    (!has_extension_triggers || !ctx.has_inline_trigger_at(start)) else {
    NoMatch
  }
  let end = if has_extension_triggers {
    plain_text_end_with_context(ctx, text, start, text.length())
  } else {
    plain_text_end(text, start, text.length())
  }
  guard end > start else { NoMatch }
  if start == 0 && end == text.length() {
    sink.emit(@markdown.Text(text))
  } else {
    sink.emit(@markdown.Text(text[start:end].to_owned()))
  }
  inline_match(end - start)
}

///|
fn commonmark_inline_trigger_chars() -> String {
  " ![<&`*_\\\n"
}

///|
fn plain_text_end(text : String, start : Int, end : Int) -> Int {
  let mut i = start
  while i < end {
    let c = char_at(text, i)
    if c == ' ' {
      let space_end = space_run_end(text, i, end)
      if space_end < end && char_at(text, space_end) == '\n' {
        return i
      }
      i = space_end
    } else if is_non_space_special(c) {
      return i
    } else {
      i = i + 1
    }
  }
  end
}

///|
fn plain_text_end_with_context(
  ctx : InlineContext,
  text : String,
  start : Int,
  end : Int,
) -> Int {
  plain_text_end_loop(text, start, end, fn(i) { ctx.has_inline_trigger_at(i) })
}

///|
fn plain_text_end_loop(
  text : String,
  start : Int,
  end : Int,
  is_extension_start : (Int) -> Bool,
) -> Int {
  let mut i = start
  while i < end {
    let c = char_at(text, i)
    if c == ' ' {
      let space_end = space_run_end(text, i, end)
      if space_end < end && char_at(text, space_end) == '\n' {
        return i
      }
      i = space_end
    } else if is_non_space_special(c) || is_extension_start(i) {
      return i
    } else {
      i = i + 1
    }
  }
  end
}

///|
fn space_run_end(text : String, start : Int, end : Int) -> Int {
  let mut i = start
  while i < end && char_at(text, i) == ' ' {
    i = i + 1
  }
  i
}

///|
fn is_non_space_special(c : Int) -> Bool {
  c == '\n' ||
  c == '&' ||
  c == '!' ||
  c == '*' ||
  c == '<' ||
  c == '[' ||
  c == '\\' ||
  c == '_' ||
  c == '`'
}

///|
fn escape_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  guard char_at(text, i) == '\\' &&
    i + 1 < text.length() &&
    is_ascii_punctuation(char_at(text, i + 1)) else {
    NoMatch
  }
  sink.emit(@markdown.Text(text[i + 1:i + 2].to_owned()))
  inline_match(2)
}

///|
fn hard_break_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  if i + 1 < text.length() &&
    char_at(text, i) == '\\' &&
    char_at(text, i + 1) == '\n' {
    sink.emit(@markdown.HardBreak)
    inline_match(2)
  } else if char_at(text, i) == ' ' {
    let mut end = i
    while end < text.length() && char_at(text, end) == ' ' {
      end = end + 1
    }
    if end - i >= 2 && end < text.length() && char_at(text, end) == '\n' {
      sink.emit(@markdown.HardBreak)
      inline_match(end - i + 1)
    } else if end < text.length() && char_at(text, end) == '\n' {
      inline_match(end - i)
    } else {
      NoMatch
    }
  } else {
    NoMatch
  }
}

///|
fn soft_break_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  guard char_at(ctx.source(), ctx.offset()) == '\n' else { NoMatch }
  sink.emit(@markdown.SoftBreak)
  inline_match(1)
}

///|
fn code_span_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  guard char_at(text, i) == '`' else { NoMatch }
  guard i == 0 || char_at(text, i - 1) != '`' else { NoMatch }
  let width = delimiter_run_len(text, i, '`')
  let end = find_code_span_end(text, i + width, width)
  guard end >= 0 else { NoMatch }
  emit_inline_match(
    sink,
    end - i + width,
    @markdown.EventFragment::element(
      @markdown.Element(tag_name("cm:code_span")),
      children=[
        @markdown.EventFragment::text(
          normalize_code_span(text[i + width:end].to_owned()),
        ),
      ],
    ),
  )
}

///|
fn find_code_span_end(text : String, start : Int, width : Int) -> Int {
  let mut i = start
  while i < text.length() {
    if char_at(text, i) == '`' {
      let run = delimiter_run_len(text, i, '`')
      if run == width {
        return i
      }
      i = i + run
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn find_code_span_end_before(
  text : String,
  start : Int,
  width : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i < end {
    if char_at(text, i) == '`' {
      let run = delimiter_run_len(text, i, '`')
      if run == width {
        return i
      }
      i = i + run
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn autolink_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  guard char_at(text, i) == '<' else { NoMatch }
  let end = find_char(text, '>', i + 1)
  guard end >= 0 else { NoMatch }
  let destination = text[i + 1:end].to_owned()
  let href = autolink_href(destination)
  guard href != "" else { NoMatch }
  emit_inline_match(
    sink,
    end - i + 1,
    @markdown.EventFragment::element(
      @markdown.Element::with_attrs(tag_name("cm:link"), [
        attr("destination", href),
      ]),
      children=[@markdown.EventFragment::text(destination)],
    ),
  )
}

///|
fn autolink_href(destination : String) -> String {
  if is_uri_autolink(destination) {
    percent_encode_autolink_uri(destination)
  } else if is_email_autolink(destination) {
    "mailto:" + destination
  } else {
    ""
  }
}

///|
fn raw_html_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  guard char_at(text, i) == '<' else { NoMatch }
  if raw_html_inline_end(text, i) is Some(end) {
    return emit_inline_match(
      sink,
      end - i,
      @markdown.EventFragment::html(text[i:end].to_owned()),
    )
  }
  if raw_html_tag_end(text, i) is Some(end) {
    let raw = text[i:end].to_owned()
    if looks_like_raw_html(raw) {
      return emit_inline_match(
        sink,
        end - i,
        @markdown.EventFragment::html(raw),
      )
    }
  }
  NoMatch
}

///|
fn raw_html_inline_end(text : String, start : Int) -> Int? {
  if has_prefix_at(text, "<!--", start) {
    if has_prefix_at(text, "<!-->", start) ||
      has_prefix_at(text, "<!--->", start) {
      let end = find_substring(text, "-->", start + 4)
      return if end >= 0 { Some(end + 2) } else { None }
    }
    let end = find_substring(text, "-->", start + 4)
    if end >= 0 {
      Some(end + 3)
    } else {
      None
    }
  } else if has_prefix_at(text, "<?", start) {
    let end = find_substring(text, "?>", start + 2)
    if end >= 0 {
      Some(end + 2)
    } else {
      None
    }
  } else if has_prefix_at(text, "<![CDATA[", start) {
    let end = find_substring(text, "]]>", start + 9)
    if end >= 0 {
      Some(end + 3)
    } else {
      None
    }
  } else if looks_like_html_declaration_at(text, start) {
    let end = find_char(text, '>', start + 2)
    if end >= 0 {
      Some(end + 1)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn looks_like_html_declaration_at(text : String, start : Int) -> Bool {
  start + 2 < text.length() &&
  char_at(text, start) == '<' &&
  char_at(text, start + 1) == '!' &&
  is_ascii_alpha(char_at(text, start + 2))
}

///|
fn entity_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  guard char_at(text, i) == '&' else { NoMatch }
  let end = find_char(text, ';', i + 1)
  guard end >= 0 && end - i <= 32 else { NoMatch }
  let name = text[i + 1:end].to_owned()
  match decode_entity(name) {
    Some(decoded) => {
      sink.emit(@markdown.Text(decoded))
      inline_match(end - i + 1)
    }
    None => NoMatch
  }
}

///|
fn emphasis_delimiter(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let start = ctx.offset()
  let marker = char_at(text, start)
  guard marker == '*' || marker == '_' else { NoMatch }
  let consumed = emit_emphasis(text, start, text.length(), ctx.services(), sink)
  if consumed > 0 {
    inline_match(consumed)
  } else {
    NoMatch
  }
}

///|
fn emit_emphasis(
  text : String,
  start : Int,
  end : Int,
  services : ParserServices,
  sink : Sink,
) -> Int {
  let marker = char_at(text, start)
  if start > 0 && char_at(text, start - 1) == marker {
    return 0
  }
  let run = delimiter_run_len(text, start, marker)
  if run > 12 || !delimiter_can_open(text, start, run, marker) {
    return 0
  }
  if run >= 4 {
    let consumed = emit_long_emphasis_run(
      text, start, run, marker, end, services, sink,
    )
    if consumed > 0 {
      return consumed
    }
  }
  let width = if run >= 3 { 3 } else if run >= 2 { 2 } else { 1 }
  let mut close = find_emphasis_close(text, marker, start + width, width, end)
  if close < 0 {
    let split = emit_split_opening_run(
      text, start, run, marker, end, services, sink,
    )
    if split > 0 {
      return split
    }
    return emit_partial_emphasis(text, start, run, marker, end, services, sink)
  }
  let close_run = delimiter_run_len(text, close, marker)
  if close_run > width &&
    inner_opener_of_width_between(
      text,
      marker,
      start + width,
      close,
      close_run - width,
    ) {
    emit_emphasis_element(
      text,
      start + width,
      close + close_run - width,
      width,
      services,
      sink,
    )
    return close - start + close_run
  }
  if exact_inner_opener_can_use_close(text, marker, start + width, close, width) {
    if close_run > width {
      emit_emphasis_element(
        text,
        start + width,
        close + close_run - width,
        width,
        services,
        sink,
      )
      return close - start + close_run
    }
    let next = find_emphasis_close(
      text,
      marker,
      close + delimiter_run_len(text, close, marker),
      width,
      end,
    )
    if next < 0 {
      return 0
    }
    close = next
  }
  if width == 1 && emphasis_would_split_link_text(text, start, close) {
    return 0
  }
  emit_emphasis_element(text, start + width, close, width, services, sink)
  close - start + width
}

///|
fn inner_opener_of_width_between(
  text : String,
  marker : Int,
  start : Int,
  close : Int,
  width : Int,
) -> Bool {
  let mut i = start
  while i < close {
    if priority_inline_span_end(text, i, close) is Some(next) {
      i = next
      continue
    }
    if other_emphasis_span_end_for_inner_scan(text, marker, i, close)
      is Some(next) {
      i = next
      continue
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run == width &&
      !is_escaped_char(text, i) &&
      delimiter_can_open(text, i, run, marker) {
      return true
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  false
}

///|
fn emit_emphasis_element(
  text : String,
  start : Int,
  end : Int,
  width : Int,
  services : ParserServices,
  sink : Sink,
) -> Unit {
  let tag = if width >= 2 {
    tag_name("cm:strong")
  } else {
    tag_name("cm:emphasis")
  }
  if width == 3 {
    sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:emphasis"))))
  }
  sink.emit(@markdown.Enter(@markdown.Element(tag)))
  services.parse_inline(text[start:end].to_owned(), sink)
  sink.emit(@markdown.Exit(tag))
  if width == 3 {
    sink.emit(@markdown.Exit(tag_name("cm:emphasis")))
  }
}

///|
fn emit_split_opening_run(
  text : String,
  start : Int,
  run : Int,
  marker : Int,
  end : Int,
  services : ParserServices,
  sink : Sink,
) -> Int {
  let width = if run == 2 {
    1
  } else if run == 3 {
    return emit_split_three_opening_run(
      text, start, marker, end, services, sink,
    )
  } else if run == 4 {
    2
  } else {
    return 0
  }
  let inner_close = find_emphasis_close(text, marker, start + run, width, end)
  if inner_close < 0 {
    return 0
  }
  let outer_close = find_emphasis_close(
    text,
    marker,
    inner_close + width,
    width,
    end,
  )
  if outer_close < 0 {
    return 0
  }
  let tag = if width >= 2 {
    tag_name("cm:strong")
  } else {
    tag_name("cm:emphasis")
  }
  sink.emit(@markdown.Enter(@markdown.Element(tag)))
  services.parse_inline(text[start + width:outer_close].to_owned(), sink)
  sink.emit(@markdown.Exit(tag))
  outer_close - start + width
}

///|
fn emit_split_three_opening_run(
  text : String,
  start : Int,
  marker : Int,
  end : Int,
  services : ParserServices,
  sink : Sink,
) -> Int {
  let outer_em = emit_split_mixed_opening_run(
    text,
    start,
    marker,
    end,
    outer_width=1,
    inner_width=2,
    services,
    sink,
  )
  if outer_em > 0 {
    return outer_em
  }
  emit_split_mixed_opening_run(
    text,
    start,
    marker,
    end,
    outer_width=2,
    inner_width=1,
    services,
    sink,
  )
}

///|
fn emit_split_mixed_opening_run(
  text : String,
  start : Int,
  marker : Int,
  end : Int,
  outer_width~ : Int,
  inner_width~ : Int,
  services : ParserServices,
  sink : Sink,
) -> Int {
  let inner_close = find_emphasis_close(
    text,
    marker,
    start + 3,
    inner_width,
    end,
  )
  if inner_close < 0 {
    return 0
  }
  let outer_close = find_emphasis_close(
    text,
    marker,
    inner_close + inner_width,
    outer_width,
    end,
  )
  if outer_close < 0 {
    return 0
  }
  let tag = if outer_width >= 2 {
    tag_name("cm:strong")
  } else {
    tag_name("cm:emphasis")
  }
  sink.emit(@markdown.Enter(@markdown.Element(tag)))
  services.parse_inline(text[start + outer_width:outer_close].to_owned(), sink)
  sink.emit(@markdown.Exit(tag))
  outer_close - start + outer_width
}

///|
fn exact_inner_opener_can_use_close(
  text : String,
  marker : Int,
  start : Int,
  close : Int,
  width : Int,
) -> Bool {
  let mut i = start
  while i < close {
    if priority_inline_span_end(text, i, close) is Some(next) {
      i = next
      continue
    }
    if other_emphasis_span_end_for_inner_scan(text, marker, i, close)
      is Some(next) {
      i = next
      continue
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run == width &&
      !is_escaped_char(text, i) &&
      delimiter_can_open(text, i, run, marker) {
      return true
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  false
}

///|
fn other_emphasis_span_end_for_inner_scan(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Int? {
  let other = char_at(text, start)
  if (other != '*' && other != '_') || other == marker {
    return None
  }
  let run = delimiter_run_len(text, start, other)
  if run > 3 || !delimiter_can_open(text, start, run, other) {
    return None
  }
  let width = if run >= 2 { 2 } else { 1 }
  let close = find_emphasis_close(text, other, start + width, width, end)
  if close >= 0 {
    Some(close + width)
  } else {
    None
  }
}

///|
fn emit_long_emphasis_run(
  text : String,
  start : Int,
  run : Int,
  marker : Int,
  end : Int,
  services : ParserServices,
  sink : Sink,
) -> Int {
  let close = find_exact_run_close(text, marker, start + run, run, end)
  if close < 0 {
    return 0
  }
  let strong_count = run / 2
  if run % 2 == 1 {
    sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:emphasis"))))
  }
  for _ in 0..<strong_count {
    sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:strong"))))
  }
  services.parse_inline(text[start + run:close].to_owned(), sink)
  for _ in 0..<strong_count {
    sink.emit(@markdown.Exit(tag_name("cm:strong")))
  }
  if run % 2 == 1 {
    sink.emit(@markdown.Exit(tag_name("cm:emphasis")))
  }
  close - start + run
}

///|
fn find_exact_run_close(
  text : String,
  marker : Int,
  start : Int,
  width : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i + width <= end {
    if priority_inline_span_end(text, i, end) is Some(next) {
      i = next
      continue
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run >= width &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, width, marker) {
      return i
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  -1
}

///|
fn find_emphasis_close(
  text : String,
  marker : Int,
  start : Int,
  width : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i + width <= end {
    if priority_inline_span_end(text, i, end) is Some(next) {
      i = next
      continue
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run >= width &&
      (width != 1 || run == 1) &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, width, marker) {
      return i
    }
    if run > 0 {
      i = if is_escaped_char(text, i) { i + 1 } else { i + run }
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn emit_partial_emphasis(
  text : String,
  start : Int,
  run : Int,
  marker : Int,
  end : Int,
  services : ParserServices,
  sink : Sink,
) -> Int {
  if run >= 3 {
    let close = find_emphasis_close(text, marker, start + run, 2, end)
    if close >= 0 {
      sink.emit(@markdown.Text(text[start:start + run - 2].to_owned()))
      sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:strong"))))
      services.parse_inline(text[start + run:close].to_owned(), sink)
      sink.emit(@markdown.Exit(tag_name("cm:strong")))
      return close - start + 2
    }
  }
  if run >= 2 {
    let close = find_emphasis_close(text, marker, start + run, 1, end)
    if close >= 0 {
      sink.emit(@markdown.Text(text[start:start + run - 1].to_owned()))
      sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:emphasis"))))
      services.parse_inline(text[start + run:close].to_owned(), sink)
      sink.emit(@markdown.Exit(tag_name("cm:emphasis")))
      return close - start + 1
    }
  }
  if run == 1 {
    let close = find_relaxed_single_close(text, marker, start + 1, end)
    if close >= 0 {
      let close_run = delimiter_run_len(text, close, marker)
      if close_run > 1 &&
        !has_delimiter_run_between(text, marker, start + 1, close) &&
        delimiter_can_open(text, close, close_run, marker) {
        let later = find_later_compound_emphasis_close(
          text,
          marker,
          close + close_run,
          end,
        )
        if later >= 0 {
          let later_run = delimiter_run_len(text, later, marker)
          sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:emphasis"))))
          services.parse_inline(
            text[start + 1:later + later_run - 1].to_owned(),
            sink,
          )
          sink.emit(@markdown.Exit(tag_name("cm:emphasis")))
          return later - start + later_run
        }
      }
      if close_run > 1 &&
        has_delimiter_run_between(text, marker, start + 1, close) {
        sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:emphasis"))))
        services.parse_inline(
          text[start + 1:close + close_run - 1].to_owned(),
          sink,
        )
        sink.emit(@markdown.Exit(tag_name("cm:emphasis")))
        return close - start + close_run
      }
    }
    if close >= 0 && !has_delimiter_run_between(text, marker, start + 1, close) {
      sink.emit(@markdown.Enter(@markdown.Element(tag_name("cm:emphasis"))))
      services.parse_inline(text[start + 1:close].to_owned(), sink)
      sink.emit(@markdown.Exit(tag_name("cm:emphasis")))
      return close - start + 1
    }
  }
  0
}

///|
fn find_later_compound_emphasis_close(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i < end {
    if priority_inline_span_end(text, i, end) is Some(next) {
      i = next
      continue
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run > 1 &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, 1, marker) {
      return i
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  -1
}

///|
fn find_relaxed_single_close(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i < end {
    if priority_inline_span_end(text, i, end) is Some(next) {
      i = next
      continue
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run > 1 &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, 1, marker) {
      return i
    }
    if run > 0 {
      i = if is_escaped_char(text, i) { i + 1 } else { i + run }
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn has_delimiter_run_between(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Bool {
  let mut i = start
  while i < end {
    if char_at(text, i) == marker && !is_escaped_char(text, i) {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn emphasis_would_split_link_text(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  guard !emphasis_close_splits_link_label(text, start, end) else { true }
  guard start + 1 < text.length() && char_at(text, start + 1) == '[' else {
    false
  }
  guard !link_text_range_may_contain_link(text, start + 2, end) else { false }
  guard end + 1 < text.length() && char_at(text, end + 1) == ']' else { false }
  let close_text = end + 1
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == '(' {
    let close_dest = find_link_destination_end(text, close_text + 2)
    close_dest > close_text &&
    parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() > 0
  } else if close_text + 1 < text.length() &&
    char_at(text, close_text + 1) == '[' {
    true
  } else {
    true
  }
}

///|
fn emphasis_close_splits_link_label(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  guard char_at(text, start) == '_' else { false }
  guard end + 1 < text.length() && char_at(text, end + 1) == ']' else { false }
  let mut open = -1
  let mut i = start + 1
  while i < end {
    if char_at(text, i) == '[' && !is_escaped_char(text, i) {
      open = i
    }
    i = i + 1
  }
  guard open >= 0 else { false }
  let close_text = end + 1
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == '(' {
    let close_dest = find_link_destination_end(text, close_text + 2)
    close_dest > close_text &&
    parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() > 0
  } else if close_text + 1 < text.length() &&
    char_at(text, close_text + 1) == '[' {
    true
  } else {
    true
  }
}

///|
fn delimiter_run_len(text : String, start : Int, marker : Int) -> Int {
  let mut i = start
  while i < text.length() && char_at(text, i) == marker {
    i = i + 1
  }
  i - start
}

///|
fn delimiter_can_open(
  text : String,
  start : Int,
  width : Int,
  marker : Int,
) -> Bool {
  let left = is_left_flanking_delimiter(text, start, width)
  let right = is_right_flanking_delimiter(text, start, width)
  if marker == '*' {
    left
  } else if is_intraword_underscore(text, start, width) {
    false
  } else {
    left &&
    (
      !right ||
      start == 0 ||
      is_punctuation_for_flanking(char_at(text, start - 1))
    )
  }
}

///|
fn delimiter_can_close(
  text : String,
  start : Int,
  width : Int,
  marker : Int,
) -> Bool {
  let left = is_left_flanking_delimiter(text, start, width)
  let right = is_right_flanking_delimiter(text, start, width)
  if marker == '*' {
    right
  } else if is_intraword_underscore(text, start, width) {
    false
  } else {
    right &&
    (
      !left ||
      start + width >= text.length() ||
      is_punctuation_for_flanking(char_at(text, start + width))
    )
  }
}

///|
fn is_left_flanking_delimiter(text : String, start : Int, width : Int) -> Bool {
  guard start + width < text.length() else { false }
  let after = char_at(text, start + width)
  guard !is_space_for_delimiter_flanking(after) else { false }
  if is_punctuation_for_flanking(after) {
    start == 0 ||
    is_space_for_delimiter_flanking(char_at(text, start - 1)) ||
    is_punctuation_for_flanking(char_at(text, start - 1))
  } else {
    true
  }
}

///|
fn is_right_flanking_delimiter(text : String, start : Int, width : Int) -> Bool {
  guard start > 0 else { false }
  let before = char_at(text, start - 1)
  guard !is_space_for_delimiter_flanking(before) else { false }
  if start + width >= text.length() {
    return true
  }
  if is_punctuation_for_flanking(before) {
    let after = char_at(text, start + width)
    is_space_for_delimiter_flanking(after) || is_punctuation_for_flanking(after)
  } else {
    true
  }
}

///|
fn is_space_for_delimiter_flanking(c : Int) -> Bool {
  is_unicode_whitespace(c)
}

///|
fn is_punctuation_for_flanking(c : Int) -> Bool {
  is_ascii_punctuation(c) || is_unicode_punctuation_or_symbol(c)
}

///|
fn is_intraword_underscore(text : String, start : Int, width : Int) -> Bool {
  start > 0 &&
  start + width < text.length() &&
  is_word_for_underscore(char_at(text, start - 1)) &&
  is_word_for_underscore(char_at(text, start + width))
}

///|
fn is_word_for_underscore(c : Int) -> Bool {
  !is_unicode_whitespace(c) && !is_punctuation_for_flanking(c)
}

///|
fn priority_inline_span_end(text : String, start : Int, end : Int) -> Int? {
  let c = char_at(text, start)
  match c {
    '`' => {
      let width = delimiter_run_len(text, start, '`')
      let close = find_code_span_end_before(text, start + width, width, end)
      if close >= 0 {
        return Some(close + width)
      }
    }
    '<' => {
      if raw_html_inline_end(text, start) is Some(close) && close <= end {
        return Some(close)
      }
      if raw_html_tag_end(text, start) is Some(close) && close <= end {
        return Some(close)
      }
      let close = find_char(text, '>', start + 1)
      if close >= 0 && close < end {
        let candidate = text[start + 1:close].to_owned()
        if is_uri_autolink(candidate) || is_email_autolink(candidate) {
          return Some(close + 1)
        }
      }
    }
    _ => ()
  }
  None
}

///|
fn percent_encode_autolink_uri(input : String) -> String {
  let first = first_uri_encode_index(input, encode_brackets=true)
  if first < 0 {
    return input
  }
  let out = StringBuilder::new(size_hint=input.length())
  if first > 0 {
    out.write_view(input[:first])
  }
  let mut i = first
  while i < input.length() {
    let c = char_at(input, i)
    if c == '[' || c == ']' {
      out.write_percent_byte(c)
      i = i + 1
    } else if c == 37 &&
      i + 2 < input.length() &&
      is_ascii_hex_digit(char_at(input, i + 1)) &&
      is_ascii_hex_digit(char_at(input, i + 2)) {
      out.write_view(input[i:i + 3])
      i = i + 3
    } else if is_uri_safe_char(c) {
      out.write_view(input[i:i + 1])
      i = i + 1
    } else if c < 128 {
      out.write_percent_byte(c)
      i = i + 1
    } else {
      out.write_percent_utf8(c)
      i = i + 1
    }
  }
  out.to_string()
}

///|
fn normalize_code_span(text : String) -> String {
  let mut needs_space_normalization = false
  let mut has_non_space_char = false
  for i in 0..<text.length() {
    let c = char_at(text, i)
    if is_space(c) {
      if c != ' ' {
        needs_space_normalization = true
      }
    } else {
      has_non_space_char = true
    }
  }
  let trim_outer_spaces = text.length() >= 2 &&
    is_space(char_at(text, 0)) &&
    is_space(char_at(text, text.length() - 1)) &&
    has_non_space_char
  if !needs_space_normalization {
    if trim_outer_spaces {
      return text[1:text.length() - 1].to_owned()
    }
    return text
  }
  let normalized = StringBuilder::new(size_hint=text.length())
  for i in 0..<text.length() {
    if is_space(char_at(text, i)) {
      normalized.write_string(" ")
    } else {
      normalized.write_view(text[i:i + 1])
    }
  }
  let result = normalized.to_string()
  if trim_outer_spaces {
    result[1:result.length() - 1].to_owned()
  } else {
    result
  }
}

///|
fn is_uri_autolink(text : String) -> Bool {
  let colon = find_char(text, ':', 0)
  guard colon > 1 && colon <= 32 else { false }
  guard is_ascii_alpha(char_at(text, 0)) else { false }
  for i in 1..<colon {
    let c = char_at(text, i)
    if !(is_ascii_alpha(c) ||
      is_ascii_digit(c) ||
      c == '+' ||
      c == '-' ||
      c == '.') {
      break false
    }
  } nobreak {
    for i in (colon + 1)..<text.length() {
      let c = char_at(text, i)
      if is_space(c) || c == '<' {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn is_email_autolink(text : String) -> Bool {
  let at = find_char(text, '@', 0)
  guard at > 0 && at < text.length() - 1 else { false }
  let dot = find_char(text, '.', at + 2)
  guard dot >= 0 && dot < text.length() - 1 else { false }
  for i in 0..<at {
    let c = char_at(text, i)
    if !(is_ascii_alpha(c) ||
      is_ascii_digit(c) ||
      c == '!' ||
      c == '#' ||
      c == '$' ||
      c == '%' ||
      c == '&' ||
      c == '\'' ||
      c == '*' ||
      c == '+' ||
      c == '-' ||
      c == '/' ||
      c == '=' ||
      c == '?' ||
      c == '^' ||
      c == '_' ||
      c == '`' ||
      c == '{' ||
      c == '|' ||
      c == '}' ||
      c == '~' ||
      c == '.') {
      break false
    }
  } nobreak {
    is_email_domain(text[at + 1:].to_owned())
  }
}

///|
fn is_email_domain(domain : String) -> Bool {
  let mut label_start = 0
  let mut saw_dot = false
  for i in 0..<domain.length() {
    let c = char_at(domain, i)
    if c == '.' {
      if i == label_start ||
        !is_ascii_alnum(char_at(domain, label_start)) ||
        !is_ascii_alnum(char_at(domain, i - 1)) {
        return false
      }
      saw_dot = true
      label_start = i + 1
    } else if !(is_ascii_alnum(c) || c == '-') {
      return false
    }
  }
  saw_dot &&
  label_start < domain.length() &&
  is_ascii_alnum(char_at(domain, label_start)) &&
  is_ascii_alnum(char_at(domain, domain.length() - 1))
}

///|
fn looks_like_raw_html(raw : String) -> Bool {
  if raw.length() < 3 ||
    char_at(raw, 0) != '<' ||
    char_at(raw, raw.length() - 1) != '>' {
    return false
  }
  let mut i = 1
  if char_at(raw, i) == '/' {
    i = i + 1
    if i >= raw.length() - 1 || !is_ascii_alpha(char_at(raw, i)) {
      return false
    }
    while i < raw.length() - 1 &&
          (
            is_ascii_alpha(char_at(raw, i)) ||
            is_ascii_digit(char_at(raw, i)) ||
            char_at(raw, i) == '-'
          ) {
      i = i + 1
    }
    while i < raw.length() - 1 {
      if !is_space(char_at(raw, i)) {
        return false
      }
      i = i + 1
    }
    return true
  }
  if i >= raw.length() - 1 || !is_ascii_alpha(char_at(raw, i)) {
    return false
  }
  while i < raw.length() - 1 {
    let c = char_at(raw, i)
    if is_space(c) || c == '/' || c == '>' {
      return true
    }
    if !(is_ascii_alpha(c) || is_ascii_digit(c) || c == '-') {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn raw_html_tag_end(text : String, start : Int) -> Int? {
  if start + 2 >= text.length() || char_at(text, start) != '<' {
    return None
  }
  let mut i = start + 1
  if char_at(text, i) == '/' {
    i = i + 1
  }
  if i >= text.length() || !is_ascii_alpha(char_at(text, i)) {
    return None
  }
  let closing = char_at(text, start + 1) == '/'
  while i < text.length() &&
        (
          is_ascii_alpha(char_at(text, i)) ||
          is_ascii_digit(char_at(text, i)) ||
          char_at(text, i) == '-'
        ) {
    i = i + 1
  }
  while i < text.length() {
    let c = char_at(text, i)
    if c == '>' {
      return Some(i + 1)
    } else if is_space(c) {
      i = i + 1
    } else if c == '/' {
      if closing {
        return None
      }
      if i + 1 < text.length() && char_at(text, i + 1) == '>' {
        i = i + 1
      } else {
        return None
      }
    } else if !closing &&
      i > start &&
      is_space(char_at(text, i - 1)) &&
      is_html_attr_name_start(c) {
      i = i + 1
      while i < text.length() && is_html_attr_name_char(char_at(text, i)) {
        i = i + 1
      }
      while i < text.length() && is_space(char_at(text, i)) {
        i = i + 1
      }
      if i < text.length() && char_at(text, i) == '=' {
        i = i + 1
        while i < text.length() && is_space(char_at(text, i)) {
          i = i + 1
        }
        if html_attr_value_end(text, i) is Some(next) {
          i = next
        } else {
          return None
        }
      }
    } else {
      return None
    }
  }
  None
}

///|
fn html_attr_value_end(text : String, start : Int) -> Int? {
  if start >= text.length() {
    return None
  }
  let quote = char_at(text, start)
  if quote == '"' || quote == '\'' {
    let end = find_char(text, quote, start + 1)
    if end < 0 {
      None
    } else {
      Some(end + 1)
    }
  } else {
    let mut i = start
    while i < text.length() {
      let c = char_at(text, i)
      if is_space(c) || c == '>' {
        return Some(i)
      }
      if c == '"' || c == '\'' || c == '=' || c == '<' || c == '`' {
        return None
      }
      i = i + 1
    }
    Some(i)
  }
}

///|
fn is_html_attr_name_start(c : Int) -> Bool {
  is_ascii_alpha(c) || c == '_' || c == ':'
}

///|
fn is_html_attr_name_char(c : Int) -> Bool {
  is_html_attr_name_start(c) || is_ascii_digit(c) || c == '.' || c == '-'
}

///|
fn is_ascii_alpha(c : Int) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn is_ascii_digit(c : Int) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_ascii_alnum(c : Int) -> Bool {
  is_ascii_alpha(c) || is_ascii_digit(c)
}

///|
fn is_ascii_punctuation(c : Int) -> Bool {
  (c >= '!' && c <= '/') ||
  (c >= ':' && c <= '@') ||
  (c >= '[' && c <= '`') ||
  (c >= '{' && c <= '~')
}
