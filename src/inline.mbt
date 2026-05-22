///|
fn parse_inlines(
  text : String,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Unit {
  let rules = registry.inline_parse_rules()
  parse_inlines_with_rules(
    text,
    registry,
    rules,
    inline_parse_mode(rules),
    sink,
    state,
  )
}

///|
fn parse_inlines_with_rules(
  text : String,
  registry : RuleRegistry,
  rules : Array[RuleEntry],
  inline_mode : InlineParseMode,
  sink : Sink,
  state : ParseState,
) -> Unit {
  match inline_mode {
    CommonMarkInlinePipeline => {
      parse_commonmark_inline_range(
        text,
        0,
        text.length(),
        registry,
        sink,
        state,
        true,
      )
      return
    }
    CustomInlinePipeline => ()
  }
  if rules.length() == 0 {
    if text.length() > 0 {
      sink.emit(Text(text))
    }
    return
  }
  let mut i = 0
  while i < text.length() {
    let mut consumed = 0
    let ctx = {
      text,
      index: i,
      scanner: inline_scanner(text, i),
      registry,
      state,
    }
    for rule in rules {
      match rule.inline {
        Some(f) =>
          if consumed == 0 {
            match f(ctx) {
              Match(chars, fragment) => {
                emit_fragment(sink, fragment)
                consumed = chars.to_int()
              }
              NoMatch => ()
            }
          }
        None => ()
      }
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
fn cm_text_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let start = ctx.index
  if start >= text.length() || is_inline_special(text, start) {
    return NoMatch
  }
  let mut end = start
  while end < text.length() && !is_inline_special(text, end) {
    end = end + 1
  }
  let fragment = if start == 0 && end == text.length() {
    EventFragment::text(text)
  } else {
    EventFragment::text(text[start:end].to_owned())
  }
  inline_match(end - start, fragment)
}

///|
fn cm_escape_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) == 92 &&
    i + 1 < text.length() &&
    is_ascii_punctuation(char_at(text, i + 1)) {
    inline_match(2, EventFragment::text(text[i + 1:i + 2].to_owned()))
  } else {
    NoMatch
  }
}

///|
fn cm_hard_break_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if i + 1 < text.length() &&
    char_at(text, i) == 92 &&
    char_at(text, i + 1) == 10 {
    inline_match(2, EventFragment::hard_break())
  } else if char_at(text, i) == 32 {
    let mut end = i
    while end < text.length() && char_at(text, end) == 32 {
      end = end + 1
    }
    if end - i >= 2 && end < text.length() && char_at(text, end) == 10 {
      inline_match(end - i + 1, EventFragment::hard_break())
    } else if end < text.length() && char_at(text, end) == 10 {
      inline_match(end - i, EventFragment::empty())
    } else {
      NoMatch
    }
  } else {
    NoMatch
  }
}

///|
fn cm_soft_break_inline(ctx : InlineContext) -> InlineRuleResult {
  if char_at(ctx.text, ctx.index) == 10 {
    inline_match(1, EventFragment::soft_break())
  } else {
    NoMatch
  }
}

///|
fn cm_code_span_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 96 {
    return NoMatch
  }
  if i > 0 && char_at(text, i - 1) == 96 {
    return NoMatch
  }
  let width = delimiter_run_len(text, i, 96)
  let end = find_code_span_end(text, i + width, width)
  if end < 0 {
    return NoMatch
  }
  inline_match(
    end - i + width,
    EventFragment::element(Element(tag_name("cm:code_span")), children=[
      EventFragment::text(normalize_code_span(text[i + width:end].to_owned())),
    ]),
  )
}

///|
fn find_code_span_end(text : String, start : Int, width : Int) -> Int {
  let mut i = start
  while i < text.length() {
    if char_at(text, i) == 96 {
      let run = delimiter_run_len(text, i, 96)
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
fn cm_autolink_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 60 {
    return NoMatch
  }
  let end = find_char(text, 62, i + 1)
  if end < 0 {
    return NoMatch
  }
  let destination = text[i + 1:end].to_owned()
  let href = if is_uri_autolink(destination) {
    percent_encode_autolink_uri(destination)
  } else if is_email_autolink(destination) {
    "mailto:" + destination
  } else {
    return NoMatch
  }
  inline_match(
    end - i + 1,
    EventFragment::element(
      Element::with_attrs(tag_name("cm:link"), [
        { name: attr_name("destination"), value: href },
      ]),
      children=[EventFragment::text(destination)],
    ),
  )
}

///|
fn cm_raw_html_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 60 {
    return NoMatch
  }
  match raw_html_inline_end(text, i) {
    Some(end) =>
      return inline_match(end - i, EventFragment::html(text[i:end].to_owned()))
    None => ()
  }
  match raw_html_tag_end(text, i) {
    Some(end) => {
      let raw = text[i:end].to_owned()
      if looks_like_raw_html(raw) {
        return inline_match(end - i, EventFragment::html(raw))
      }
    }
    None => ()
  }
  NoMatch
}

///|
fn raw_html_inline_end(text : String, start : Int) -> Int? {
  if has_prefix_at(text, "<!--", start) {
    if has_prefix_at(text, "<!-->", start) ||
      has_prefix_at(text, "<!--->", start) {
      let end = find_substring(text, "-->", start + 4)
      if end >= 0 {
        return Some(end + 2)
      }
      return None
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
    let end = find_char(text, 62, start + 2)
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
  char_at(text, start) == 60 &&
  char_at(text, start + 1) == 33 &&
  is_ascii_alpha(char_at(text, start + 2))
}

///|
fn cm_entity_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 38 {
    return NoMatch
  }
  let end = find_char(text, 59, i + 1)
  if end < 0 || end - i > 32 {
    return NoMatch
  }
  let name = text[i + 1:end].to_owned()
  match decode_entity(name) {
    Some(decoded) => inline_match(end - i + 1, EventFragment::text(decoded))
    None => NoMatch
  }
}

///|
fn cm_emphasis_delimiter(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  let marker = char_at(text, i)
  if marker != 42 && marker != 95 {
    return NoMatch
  }
  if i > 0 && char_at(text, i - 1) == marker {
    return NoMatch
  }
  let run = delimiter_run_len(text, i, marker)
  if run > 12 {
    return inline_match(run, EventFragment::text(text[i:i + run].to_owned()))
  }
  if !delimiter_can_open(text, i, run, marker) {
    return NoMatch
  }
  if run >= 4 {
    let end = find_closing_run(text, marker, i + run, run)
    if end < 0 {
      return emphasis_partial_run_fallback(ctx, run)
    }
    let buffer = Events()
    let sink = buffer.owned_sink()
    let strong_count = run / 2
    if run % 2 == 1 {
      sink.emit(Enter(Element(tag_name("cm:emphasis"))))
    }
    for _ in 0..<strong_count {
      sink.emit(Enter(Element(tag_name("cm:strong"))))
    }
    parse_inlines(text[i + run:end].to_owned(), ctx.registry, sink, ctx.state)
    for _ in 0..<strong_count {
      sink.emit(Exit(tag_name("cm:strong")))
    }
    if run % 2 == 1 {
      sink.emit(Exit(tag_name("cm:emphasis")))
    }
    inline_match(end - i + run, buffer.into_fragment())
  } else if run >= 3 {
    let end = find_closing_run(text, marker, i + 3, 3)
    if end < 0 {
      return emphasis_partial_run_fallback(ctx, run)
    }
    let buffer = Events()
    let sink = buffer.owned_sink()
    sink.emit(Enter(Element(tag_name("cm:emphasis"))))
    sink.emit(Enter(Element(tag_name("cm:strong"))))
    parse_inlines(text[i + 3:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:strong")))
    sink.emit(Exit(tag_name("cm:emphasis")))
    inline_match(end - i + 3, buffer.into_fragment())
  } else if run >= 2 {
    let end = find_closing_run(text, marker, i + 2, 2)
    if end < 0 {
      return emphasis_partial_run_fallback(ctx, run)
    }
    let buffer = Events()
    let sink = buffer.owned_sink()
    sink.emit(Enter(Element(tag_name("cm:strong"))))
    parse_inlines(text[i + 2:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:strong")))
    inline_match(end - i + 2, buffer.into_fragment())
  } else {
    let end = find_closing_single(text, marker, i + 1)
    if end < 0 {
      return NoMatch
    }
    if emphasis_would_split_link_text(text, i, end) {
      return NoMatch
    }
    let buffer = Events()
    let sink = buffer.owned_sink()
    sink.emit(Enter(Element(tag_name("cm:emphasis"))))
    parse_inlines(text[i + 1:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:emphasis")))
    inline_match(end - i + 1, buffer.into_fragment())
  }
}

///|
fn emphasis_partial_run_fallback(
  ctx : InlineContext,
  run : Int,
) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  let marker = char_at(text, i)
  if run >= 3 {
    let end = find_closing_run(text, marker, i + run, 2)
    if end >= 0 {
      let buffer = Events()
      let sink = buffer.owned_sink()
      sink.emit(Text(text[i:i + run - 2].to_owned()))
      sink.emit(Enter(Element(tag_name("cm:strong"))))
      parse_inlines(text[i + run:end].to_owned(), ctx.registry, sink, ctx.state)
      sink.emit(Exit(tag_name("cm:strong")))
      return inline_match(end - i + 2, buffer.into_fragment())
    }
  }
  let end = find_closing_single(text, marker, i + run)
  if end >= 0 {
    if run == 2 && delimiter_run_len(text, end, marker) >= 2 {
      return NoMatch
    }
    let buffer = Events()
    let sink = buffer.owned_sink()
    sink.emit(Text(text[i:i + run - 1].to_owned()))
    sink.emit(Enter(Element(tag_name("cm:emphasis"))))
    parse_inlines(text[i + run:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:emphasis")))
    return inline_match(end - i + 1, buffer.into_fragment())
  }
  NoMatch
}

///|
fn emphasis_would_split_link_text(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  if emphasis_close_splits_link_label(text, start, end) {
    return true
  }
  if start + 1 >= text.length() || char_at(text, start + 1) != 91 {
    return false
  }
  if link_text_range_may_contain_link(text, start + 2, end) {
    return false
  }
  if end + 1 >= text.length() || char_at(text, end + 1) != 93 {
    return false
  }
  let close_text = end + 1
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_text + 2)
    close_dest > close_text &&
    parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() > 0
  } else if close_text + 1 < text.length() &&
    char_at(text, close_text + 1) == 91 {
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
  if char_at(text, start) != 95 {
    return false
  }
  if end + 1 >= text.length() || char_at(text, end + 1) != 93 {
    return false
  }
  let mut open = -1
  let mut i = start + 1
  while i < end {
    if char_at(text, i) == 91 && !is_escaped_char(text, i) {
      open = i
    }
    i = i + 1
  }
  if open < 0 {
    return false
  }
  let close_text = end + 1
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_text + 2)
    close_dest > close_text &&
    parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() > 0
  } else if close_text + 1 < text.length() &&
    char_at(text, close_text + 1) == 91 {
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
fn find_closing_run(
  text : String,
  marker : Int,
  start : Int,
  width : Int,
) -> Int {
  let mut i = start
  while i + width <= text.length() {
    match inline_span_end_for_delimiter_scan(text, i) {
      Some(end) => {
        i = end
        continue
      }
      None => ()
    }
    if delimiter_run_len(text, i, marker) >= width &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, width, marker) {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn find_closing_single(text : String, marker : Int, start : Int) -> Int {
  let exact = find_closing_single_run(text, marker, start, true)
  if exact >= 0 {
    return exact
  }
  find_closing_single_run(text, marker, start, false)
}

///|
fn find_closing_single_run(
  text : String,
  marker : Int,
  start : Int,
  exact_only : Bool,
) -> Int {
  let mut i = start
  while i < text.length() {
    match inline_span_end_for_delimiter_scan(text, i) {
      Some(end) => {
        i = end
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run > 0 &&
      (!exact_only || run == 1) &&
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
fn delimiter_can_open(
  text : String,
  start : Int,
  width : Int,
  marker : Int,
) -> Bool {
  let left = is_left_flanking_delimiter(text, start, width)
  let right = is_right_flanking_delimiter(text, start, width)
  if marker == 42 {
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
  if marker == 42 {
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
  if start + width >= text.length() {
    return false
  }
  let after = char_at(text, start + width)
  if is_space_for_delimiter_flanking(after) {
    return false
  }
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
  if start == 0 {
    return false
  }
  let before = char_at(text, start - 1)
  if is_space_for_delimiter_flanking(before) {
    return false
  }
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
fn inline_span_end_for_delimiter_scan(text : String, start : Int) -> Int? {
  let c = char_at(text, start)
  if c == 96 {
    let width = delimiter_run_len(text, start, 96)
    let end = find_code_span_end(text, start + width, width)
    if end >= 0 {
      return Some(end + width)
    }
  } else if c == 60 {
    match raw_html_inline_end(text, start) {
      Some(end) => return Some(end)
      None => ()
    }
    match raw_html_tag_end(text, start) {
      Some(end) => return Some(end)
      None => ()
    }
    let end = find_char(text, 62, start + 1)
    if end >= 0 {
      let destination = text[start + 1:end].to_owned()
      if is_uri_autolink(destination) || is_email_autolink(destination) {
        return Some(end + 1)
      }
    }
  } else if c == 91 {
    let close_text = find_link_text_end(text, start + 1)
    if close_text > start &&
      close_text + 1 < text.length() &&
      char_at(text, close_text + 1) == 40 {
      let close_dest = find_link_destination_end(text, close_text + 2)
      if close_dest > close_text &&
        parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() >
        0 {
        return Some(close_dest + 1)
      }
    }
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
    if c == 91 || c == 93 {
      write_percent_byte(out, c)
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
      write_percent_byte(out, c)
      i = i + 1
    } else {
      write_percent_utf8(out, c)
      i = i + 1
    }
  }
  out.to_string()
}

///|
fn is_inline_special(text : String, index : Int) -> Bool {
  let c = char_at(text, index)
  c == 10 ||
  c == 32 ||
  c == 38 ||
  c == 33 ||
  c == 42 ||
  c == 60 ||
  c == 91 ||
  c == 92 ||
  c == 95 ||
  c == 96
}

///|
fn normalize_code_span(text : String) -> String {
  let mut needs_space_normalization = false
  let mut has_non_space_char = false
  for i in 0..<text.length() {
    let c = char_at(text, i)
    if is_space(c) {
      if c != 32 {
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
  let colon = find_char(text, 58, 0)
  if colon <= 1 || colon > 32 {
    return false
  }
  if !is_ascii_alpha(char_at(text, 0)) {
    return false
  }
  for i in 1..<colon {
    let c = char_at(text, i)
    if !(is_ascii_alpha(c) || is_ascii_digit(c) || c == 43 || c == 45 || c == 46) {
      return false
    }
  }
  for i in (colon + 1)..<text.length() {
    let c = char_at(text, i)
    if is_space(c) || c == 60 {
      return false
    }
  }
  true
}

///|
fn is_email_autolink(text : String) -> Bool {
  let at = find_char(text, 64, 0)
  if at <= 0 || at >= text.length() - 1 {
    return false
  }
  let dot = find_char(text, 46, at + 2)
  if dot < 0 || dot >= text.length() - 1 {
    return false
  }
  for i in 0..<at {
    let c = char_at(text, i)
    if !(is_ascii_alpha(c) ||
      is_ascii_digit(c) ||
      c == 33 ||
      c == 35 ||
      c == 36 ||
      c == 37 ||
      c == 38 ||
      c == 39 ||
      c == 42 ||
      c == 43 ||
      c == 45 ||
      c == 47 ||
      c == 61 ||
      c == 63 ||
      c == 94 ||
      c == 95 ||
      c == 96 ||
      c == 123 ||
      c == 124 ||
      c == 125 ||
      c == 126 ||
      c == 46) {
      return false
    }
  }
  is_email_domain(text[at + 1:].to_owned())
}

///|
fn is_email_domain(domain : String) -> Bool {
  let mut label_start = 0
  let mut saw_dot = false
  for i in 0..<domain.length() {
    let c = char_at(domain, i)
    if c == 46 {
      if i == label_start ||
        !is_ascii_alnum(char_at(domain, label_start)) ||
        !is_ascii_alnum(char_at(domain, i - 1)) {
        return false
      }
      saw_dot = true
      label_start = i + 1
    } else if !(is_ascii_alnum(c) || c == 45) {
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
    char_at(raw, 0) != 60 ||
    char_at(raw, raw.length() - 1) != 62 {
    return false
  }
  let mut i = 1
  if char_at(raw, i) == 47 {
    i = i + 1
    if i >= raw.length() - 1 || !is_ascii_alpha(char_at(raw, i)) {
      return false
    }
    while i < raw.length() - 1 &&
          (
            is_ascii_alpha(char_at(raw, i)) ||
            is_ascii_digit(char_at(raw, i)) ||
            char_at(raw, i) == 45
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
    if is_space(c) || c == 47 || c == 62 {
      return true
    }
    if !(is_ascii_alpha(c) || is_ascii_digit(c) || c == 45) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn raw_html_tag_end(text : String, start : Int) -> Int? {
  if start + 2 >= text.length() || char_at(text, start) != 60 {
    return None
  }
  let mut i = start + 1
  if char_at(text, i) == 47 {
    i = i + 1
  }
  if i >= text.length() || !is_ascii_alpha(char_at(text, i)) {
    return None
  }
  let closing = char_at(text, start + 1) == 47
  while i < text.length() &&
        (
          is_ascii_alpha(char_at(text, i)) ||
          is_ascii_digit(char_at(text, i)) ||
          char_at(text, i) == 45
        ) {
    i = i + 1
  }
  while i < text.length() {
    let c = char_at(text, i)
    if c == 62 {
      return Some(i + 1)
    } else if is_space(c) {
      i = i + 1
    } else if c == 47 {
      if closing {
        return None
      }
      if i + 1 < text.length() && char_at(text, i + 1) == 62 {
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
      if i < text.length() && char_at(text, i) == 61 {
        i = i + 1
        while i < text.length() && is_space(char_at(text, i)) {
          i = i + 1
        }
        let value_end = html_attr_value_end(text, i)
        match value_end {
          Some(next) => i = next
          None => return None
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
  if quote == 34 || quote == 39 {
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
      if is_space(c) || c == 62 {
        return Some(i)
      }
      if c == 34 || c == 39 || c == 61 || c == 60 || c == 96 {
        return None
      }
      i = i + 1
    }
    Some(i)
  }
}

///|
fn is_html_attr_name_start(c : Int) -> Bool {
  is_ascii_alpha(c) || c == 95 || c == 58
}

///|
fn is_html_attr_name_char(c : Int) -> Bool {
  is_html_attr_name_start(c) || is_ascii_digit(c) || c == 46 || c == 45
}

///|
fn is_ascii_alpha(c : Int) -> Bool {
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
}

///|
fn is_ascii_digit(c : Int) -> Bool {
  c >= 48 && c <= 57
}

///|
fn is_ascii_alnum(c : Int) -> Bool {
  is_ascii_alpha(c) || is_ascii_digit(c)
}

///|
fn is_ascii_punctuation(c : Int) -> Bool {
  (c >= 33 && c <= 47) ||
  (c >= 58 && c <= 64) ||
  (c >= 91 && c <= 96) ||
  (c >= 123 && c <= 126)
}
