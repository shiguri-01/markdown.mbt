///|
fn link_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  guard char_at(text, i) == '[' else { NoMatch }
  let close_text = find_link_text_end(text, i + 1)
  guard close_text >= 0 else { NoMatch }
  guard !link_text_range_may_contain_link(text, i + 1, close_text) else {
    NoMatch
  }
  guard !link_text_has_unclosed_priority_span(text, i + 1, close_text) else {
    NoMatch
  }
  if direct_link_attrs(text, close_text) is Some((close_dest, attrs)) {
    link_inline_match(
      text,
      i,
      close_text,
      close_dest + 1,
      attrs,
      ctx.services(),
      sink,
    )
  } else if reference_attrs_for_link_text(text, i, close_text, ctx.services())
    is Some(resolved) {
    link_inline_match(
      text,
      i,
      close_text,
      resolved.end,
      resolved.attrs,
      ctx.services(),
      sink,
    )
  } else {
    NoMatch
  }
}

///|
fn direct_link_attrs(text : String, close_text : Int) -> (Int, Array[Attr])? {
  guard close_text + 1 < text.length() && char_at(text, close_text + 1) == '(' else {
    None
  }
  let close_dest = find_link_destination_end(text, close_text + 2)
  guard close_dest >= 0 else { None }
  let attrs = parse_link_attrs(text[close_text + 2:close_dest].to_owned())
  guard attrs.length() > 0 else { None }
  Some((close_dest, attrs))
}

///|
fn link_inline_match(
  text : String,
  start : Int,
  close_text : Int,
  end : Int,
  attrs : Array[Attr],
  services : ParserServices,
  sink : Sink,
) -> InlineRuleResult {
  sink.emit(
    @markdown.Enter(@markdown.Element::with_attrs(tag_name("cm:link"), attrs)),
  )
  services.parse_inline(text[start + 1:close_text].to_owned(), sink)
  sink.emit(@markdown.Exit(tag_name("cm:link")))
  inline_match(end - start)
}

///|
fn image_inline(ctx : InlineContext, sink : Sink) -> InlineRuleResult {
  let text = ctx.source()
  let i = ctx.offset()
  guard i + 1 < text.length() &&
    char_at(text, i) == '!' &&
    char_at(text, i + 1) == '[' else {
    NoMatch
  }
  let close_text = find_link_text_end(text, i + 2)
  guard close_text >= 0 &&
    !link_text_has_unclosed_priority_span(text, i + 2, close_text) else {
    NoMatch
  }
  let alt = image_alt_text(text[i + 2:close_text].to_owned(), ctx.services())
  if direct_link_attrs(text, close_text) is Some((close_dest, attrs)) {
    attrs.push(attr("alt", alt))
    emit_inline_match(
      sink,
      close_dest - i + 1,
      @markdown.EventFragment::element(
        @markdown.Element::with_attrs(tag_name("cm:image"), attrs),
      ),
    )
  } else if reference_attrs_for_image_alt(
      text,
      i,
      close_text,
      alt,
      ctx.services(),
    )
    is Some(resolved) {
    emit_inline_match(
      sink,
      resolved.end - i,
      @markdown.EventFragment::element(
        @markdown.Element::with_attrs(tag_name("cm:image"), resolved.attrs),
      ),
    )
  } else {
    NoMatch
  }
}

///|
fn image_alt_text(text : String, services : ParserServices) -> String {
  let buffer = @markdown.Events()
  services.parse_inline(text, buffer.owned_sink())
  let out = StringBuilder::new(size_hint=text.length())
  for event in buffer.owned_events() {
    match event {
      @markdown.Text(text) => out.write_string(text)
      @markdown.SoftBreak => out.write_string("\n")
      @markdown.HardBreak => out.write_string("\n")
      @markdown.RawHtml(raw) => out.write_string(raw)
      @markdown.Enter(el) =>
        if el.tag().to_string() == "cm:image" {
          out.write_string(attr_value(el.attrs(), "alt", ""))
        }
      _ => ()
    }
  }
  out.to_string()
}

///|
fn find_link_text_end(text : String, start : Int) -> Int {
  find_link_text_end_before(text, start, text.length())
}

///|
fn find_link_text_end_before(text : String, start : Int, end : Int) -> Int {
  let mut i = start
  let mut depth = 0
  while i < end {
    let c = char_at(text, i)
    if c == '\\' && i + 1 < end {
      i = i + 2
    } else if c == '`' {
      let width = delimiter_run_len(text, i, '`')
      let close = find_code_span_end_before(text, i + width, width, end)
      if close >= 0 {
        i = close + width
      } else {
        i = i + width
      }
    } else if c == '[' {
      depth = depth + 1
      i = i + 1
    } else if c == ']' {
      if depth == 0 {
        return i
      }
      depth = depth - 1
      i = i + 1
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn normalize_attribute_text(text : String) -> String {
  let out = StringBuilder::new(size_hint=text.length())
  let mut i = 0
  let mut start = 0
  while i < text.length() {
    if char_at(text, i) == '\\' &&
      i + 1 < text.length() &&
      is_ascii_punctuation(char_at(text, i + 1)) {
      if start < i {
        out.write_view(text[start:i])
      }
      out.write_view(text[i + 1:i + 2])
      i = i + 2
      start = i
    } else if char_at(text, i) == '&' {
      let end = find_char(text, ';', i + 1)
      if end > i {
        let name = text[i + 1:end].to_owned()
        match decode_entity(name) {
          Some(decoded) => {
            if start < i {
              out.write_view(text[start:i])
            }
            out.write_string(decoded)
            i = end + 1
            start = i
          }
          None => i = i + 1
        }
      } else {
        i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  if start < text.length() {
    out.write_view(text[start:])
  }
  out.to_string()
}

///|
fn find_link_destination_end(text : String, start : Int) -> Int {
  if start < text.length() && char_at(text, start) == '<' {
    let close_angle = find_angle_link_destination_close(text, start + 1)
    if close_angle < 0 {
      return -1
    }
    let mut i = close_angle + 1
    while i < text.length() && is_space(char_at(text, i)) {
      i = i + 1
    }
    return find_char(text, ')', i)
  }
  let mut i = start
  let mut depth = 0
  while i < text.length() {
    let c = char_at(text, i)
    if c == '\\' && i + 1 < text.length() {
      i = i + 2
    } else if c == '(' {
      depth = depth + 1
      i = i + 1
    } else if c == ')' {
      if depth == 0 {
        return i
      }
      depth = depth - 1
      i = i + 1
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn find_angle_link_destination_close(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let c = char_at(text, i)
    if c == '\\' && i + 1 < text.length() {
      i = i + 2
    } else if c == '\n' || c == '\r' || c == '<' {
      return -1
    } else if c == '>' {
      return i
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn link_text_range_may_contain_link(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  let mut i = start
  while i < end {
    if char_at(text, i) == '[' {
      if i > start && char_at(text, i - 1) == '!' {
        i = i + 1
        continue
      }
      let close_text = find_link_text_end_before(text, i + 1, end)
      if close_text > i &&
        close_text + 1 < end &&
        (
          char_at(text, close_text + 1) == '(' ||
          char_at(text, close_text + 1) == '['
        ) {
        return true
      }
      i = if close_text > i { close_text + 1 } else { i + 1 }
    } else {
      i = i + 1
    }
  }
  false
}

///|
fn link_text_has_unclosed_priority_span(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  let mut i = start
  while i < end {
    let c = char_at(text, i)
    if c == '`' {
      let width = delimiter_run_len(text, i, '`')
      let close = find_code_span_end(text, i + width, width)
      if close < 0 || close >= end {
        return true
      }
      i = close + width
    } else if c == '<' {
      if raw_html_inline_end(text, i) is Some(close) {
        if close > end {
          return true
        }
        i = close
      } else {
        let close = find_char(text, '>', i + 1)
        if close >= end {
          if looks_like_raw_html_start_at(text, i) {
            return true
          }
          let candidate = text[i + 1:close].to_owned()
          if is_uri_autolink(candidate) || is_email_autolink(candidate) {
            return true
          }
        }
        i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  false
}

///|
fn looks_like_raw_html_start_at(text : String, start : Int) -> Bool {
  start + 1 < text.length() &&
  (
    is_ascii_alpha(char_at(text, start + 1)) ||
    char_at(text, start + 1) == '/' ||
    char_at(text, start + 1) == '!' ||
    char_at(text, start + 1) == '?'
  )
}

///|
fn parse_link_attrs(spec : String) -> Array[Attr] {
  let trimmed = trim(spec)
  let attrs : Array[Attr] = []
  let split = find_link_title_split(trimmed)
  if split < 0 {
    if !is_valid_link_destination(trimmed) {
      return attrs
    }
    attrs.push(attr("destination", normalize_link_destination(trimmed)))
  } else {
    let destination = trim(trimmed[:split].to_owned())
    if !is_valid_link_destination(destination) {
      return attrs
    }
    attrs.push(attr("destination", normalize_link_destination(destination)))
    attrs.push(
      attr(
        "title",
        normalize_attribute_text(
          trimmed[split + 2:trimmed.length() - 1].to_owned(),
        ),
      ),
    )
  }
  attrs
}

///|
fn is_valid_link_destination(destination : String) -> Bool {
  let trimmed = trim(destination)
  if trimmed.length() >= 2 &&
    char_at(trimmed, 0) == '<' &&
    char_at(trimmed, trimmed.length() - 1) == '>' {
    is_valid_angle_link_destination(trimmed[1:trimmed.length() - 1].to_owned())
  } else {
    !contains_unescaped_space(trimmed) &&
    !contains_unescaped_angle_bracket(trimmed)
  }
}

///|
fn contains_unescaped_angle_bracket(text : String) -> Bool {
  for i in 0..<text.length() {
    let c = char_at(text, i)
    if (c == '<' || c == '>') && !is_escaped_char(text, i) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn is_valid_angle_link_destination(destination : String) -> Bool {
  for i in 0..<destination.length() {
    let c = char_at(destination, i)
    if c == '<' || c == '>' || c == '\n' || c == '\r' {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn normalize_link_destination(destination : String) -> String {
  let trimmed = trim(destination)
  let decoded = if trimmed.length() >= 2 &&
    char_at(trimmed, 0) == '<' &&
    char_at(trimmed, trimmed.length() - 1) == '>' {
    normalize_attribute_text(trimmed[1:trimmed.length() - 1].to_owned())
  } else {
    normalize_attribute_text(trimmed)
  }
  percent_encode_uri(decoded)
}

///|
fn percent_encode_uri(input : String) -> String {
  let first = first_uri_encode_index(input, encode_brackets=false)
  if first < 0 {
    return input
  }
  let out = StringBuilder::new(size_hint=input.length())
  if first > 0 {
    out.write_view(input[:first])
  }
  let mut i = first
  let mut start = first
  while i < input.length() {
    let c = char_at(input, i)
    if c == 37 &&
      i + 2 < input.length() &&
      is_ascii_hex_digit(char_at(input, i + 1)) &&
      is_ascii_hex_digit(char_at(input, i + 2)) {
      i = i + 3
    } else if is_uri_safe_char(c) {
      i = i + 1
    } else if c < 128 {
      if start < i {
        out.write_view(input[start:i])
      }
      out.write_percent_byte(c)
      i = i + 1
      start = i
    } else {
      if start < i {
        out.write_view(input[start:i])
      }
      out.write_percent_utf8(c)
      i = i + 1
      start = i
    }
  }
  if start < input.length() {
    out.write_view(input[start:])
  }
  out.to_string()
}

///|
fn first_uri_encode_index(input : String, encode_brackets~ : Bool) -> Int {
  let mut i = 0
  while i < input.length() {
    let c = char_at(input, i)
    if c == 37 &&
      i + 2 < input.length() &&
      is_ascii_hex_digit(char_at(input, i + 1)) &&
      is_ascii_hex_digit(char_at(input, i + 2)) {
      i = i + 3
    } else if encode_brackets && (c == '[' || c == ']') {
      return i
    } else if is_uri_safe_char(c) {
      i = i + 1
    } else {
      return i
    }
  }
  -1
}

///|
fn is_uri_safe_char(c : Int) -> Bool {
  is_ascii_alnum(c) ||
  c == '-' ||
  c == '.' ||
  c == '_' ||
  c == '~' ||
  c == '!' ||
  c == '$' ||
  c == '&' ||
  c == '\'' ||
  c == '(' ||
  c == ')' ||
  c == '*' ||
  c == '+' ||
  c == ',' ||
  c == ';' ||
  c == '=' ||
  c == ':' ||
  c == '/' ||
  c == '?' ||
  c == '#' ||
  c == '[' ||
  c == ']' ||
  c == '@'
}

///|
fn is_ascii_hex_digit(c : Int) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')
}

///|
fn StringBuilder::write_percent_utf8(self : StringBuilder, c : Int) -> Unit {
  if c <= 0x7FF {
    self
    ..write_percent_byte(0xC0 | (c >> 6))
    .write_percent_byte(0x80 | (c & 0x3F))
  } else if c <= 0xFFFF {
    self
    ..write_percent_byte(0xE0 | (c >> 12))
    ..write_percent_byte(0x80 | ((c >> 6) & 0x3F))
    .write_percent_byte(0x80 | (c & 0x3F))
  } else {
    self
    ..write_percent_byte(0xF0 | (c >> 18))
    ..write_percent_byte(0x80 | ((c >> 12) & 0x3F))
    ..write_percent_byte(0x80 | ((c >> 6) & 0x3F))
    .write_percent_byte(0x80 | (c & 0x3F))
  }
}

///|
fn StringBuilder::write_percent_byte(self : StringBuilder, byte : Int) -> Unit {
  self
  ..write_string("%")
  ..write_string(hex_digit((byte >> 4) & 0xF))
  .write_string(hex_digit(byte & 0xF))
}

///|
fn hex_digit(value : Int) -> String {
  if value < 10 {
    ascii_char('0' + value)
  } else {
    ascii_char('A' + value - 10)
  }
}

///|
fn contains_unescaped_space(text : String) -> Bool {
  let mut i = 0
  while i < text.length() {
    if char_at(text, i) == '\\' &&
      i + 1 < text.length() &&
      is_ascii_punctuation(char_at(text, i + 1)) {
      i = i + 2
    } else if is_space(char_at(text, i)) {
      return true
    } else {
      i = i + 1
    }
  }
  false
}

///|
fn find_link_title_split(spec : String) -> Int {
  for i in 0..<spec.length() {
    if is_space(char_at(spec, i)) && i + 2 < spec.length() {
      let open = char_at(spec, i + 1)
      let close : Int = if open == '(' { ')' } else { open }
      if (open == '"' || open == '\'' || open == '(') &&
        char_at(spec, spec.length() - 1) == close &&
        !is_escaped_char(spec, spec.length() - 1) &&
        !contains_unescaped_title_close(
          spec[i + 2:spec.length() - 1].to_owned(),
          close,
        ) {
        return i
      }
    }
  }
  -1
}

///|
fn contains_unescaped_title_close(text : String, close : Int) -> Bool {
  for i in 0..<text.length() {
    if char_at(text, i) == close && !is_escaped_char(text, i) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn is_escaped_char(text : String, index : Int) -> Bool {
  let mut count = 0
  let mut i = index - 1
  while i >= 0 && char_at(text, i) == '\\' {
    count = count + 1
    i = i - 1
  }
  count % 2 == 1
}
