///|
fn cm_link_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 91 {
    return NoMatch
  }
  let close_text = find_link_text_end(text, i + 1)
  if close_text < 0 {
    return NoMatch
  }
  if link_text_range_may_contain_link(text, i + 1, close_text) {
    return NoMatch
  }
  if link_text_has_unclosed_priority_span(text, i + 1, close_text) {
    return NoMatch
  }
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_text + 2)
    if close_dest < 0 {
      return NoMatch
    }
    let attrs = parse_link_attrs(text[close_text + 2:close_dest].to_owned())
    if attrs.length() == 0 {
      return NoMatch
    }
    return link_inline_match(
      text,
      i,
      close_text,
      close_dest + 1,
      attrs,
      ctx.registry,
      ctx.state,
    )
  }
  match reference_attrs_for_link_text(text, i, close_text, ctx.state) {
    Some(resolved) =>
      link_inline_match(
        text,
        i,
        close_text,
        resolved.end,
        resolved.attrs,
        ctx.registry,
        ctx.state,
      )
    None => NoMatch
  }
}

///|
fn link_inline_match(
  text : String,
  start : Int,
  close_text : Int,
  end : Int,
  attrs : Array[Attr],
  registry : RuleRegistry,
  state : ParseState,
) -> InlineRuleResult {
  let buffer = Events::new()
  let sink = buffer.sink()
  sink.emit(Enter(Element::with_attrs(tag_name("cm:link"), attrs)))
  parse_inlines(text[start + 1:close_text].to_owned(), registry, sink, state)
  sink.emit(Exit(tag_name("cm:link")))
  inline_match(end - start, event_fragment_from_events(buffer.collect()))
}

///|
fn cm_image_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if i + 1 >= text.length() ||
    char_at(text, i) != 33 ||
    char_at(text, i + 1) != 91 {
    return NoMatch
  }
  let close_text = find_link_text_end(text, i + 2)
  if close_text < 0 ||
    link_text_has_unclosed_priority_span(text, i + 2, close_text) {
    return NoMatch
  }
  let alt = image_alt_text(
    text[i + 2:close_text].to_owned(),
    ctx.registry,
    ctx.state,
  )
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_text + 2)
    if close_dest < 0 {
      return NoMatch
    }
    let attrs = parse_link_attrs(text[close_text + 2:close_dest].to_owned())
    if attrs.length() == 0 {
      return NoMatch
    }
    attrs.push({ name: attr_name("alt"), value: alt })
    return inline_match(
      close_dest - i + 1,
      EventFragment::element(Element::with_attrs(tag_name("cm:image"), attrs)),
    )
  }
  match reference_attrs_for_image_alt(text, i, close_text, alt, ctx.state) {
    Some(resolved) =>
      inline_match(
        resolved.end - i,
        EventFragment::element(
          Element::with_attrs(tag_name("cm:image"), resolved.attrs),
        ),
      )
    None => NoMatch
  }
}

///|
fn image_alt_text(
  text : String,
  registry : RuleRegistry,
  state : ParseState,
) -> String {
  let buffer = Events::new()
  parse_inlines(text, registry, buffer.sink(), state)
  let out = StringBuilder::new(size_hint=text.length())
  for event in buffer.collect() {
    match event {
      Text(text) => out.write_string(text)
      SoftBreak => out.write_string("\n")
      HardBreak => out.write_string("\n")
      Html(raw) => out.write_string(raw)
      Enter(el) =>
        if el.tag.value == "cm:image" {
          out.write_string(attr_value(el.attrs, "alt", ""))
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
    if c == 92 && i + 1 < end {
      i = i + 2
    } else if c == 96 {
      let width = delimiter_run_len(text, i, 96)
      let close = find_code_span_end_before(text, i + width, width, end)
      if close >= 0 {
        i = close + width
      } else {
        i = i + width
      }
    } else if c == 91 {
      depth = depth + 1
      i = i + 1
    } else if c == 93 {
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
  while i < text.length() {
    if char_at(text, i) == 92 &&
      i + 1 < text.length() &&
      is_ascii_punctuation(char_at(text, i + 1)) {
      out.write_view(text[i + 1:i + 2])
      i = i + 2
    } else if char_at(text, i) == 38 {
      let end = find_char(text, 59, i + 1)
      if end > i {
        let name = text[i + 1:end].to_owned()
        match decode_entity(name) {
          Some(decoded) => {
            out.write_string(decoded)
            i = end + 1
          }
          None => {
            out.write_view(text[i:i + 1])
            i = i + 1
          }
        }
      } else {
        out.write_view(text[i:i + 1])
        i = i + 1
      }
    } else {
      out.write_view(text[i:i + 1])
      i = i + 1
    }
  }
  out.to_string()
}

///|
fn find_link_destination_end(text : String, start : Int) -> Int {
  if start < text.length() && char_at(text, start) == 60 {
    let close_angle = find_angle_link_destination_close(text, start + 1)
    if close_angle < 0 {
      return -1
    }
    let mut i = close_angle + 1
    while i < text.length() && is_space(char_at(text, i)) {
      i = i + 1
    }
    return find_char(text, 41, i)
  }
  let mut i = start
  let mut depth = 0
  while i < text.length() {
    let c = char_at(text, i)
    if c == 92 && i + 1 < text.length() {
      i = i + 2
    } else if c == 40 {
      depth = depth + 1
      i = i + 1
    } else if c == 41 {
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
    if c == 92 && i + 1 < text.length() {
      i = i + 2
    } else if c == 10 || c == 13 || c == 60 {
      return -1
    } else if c == 62 {
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
    if char_at(text, i) == 91 {
      if i > start && char_at(text, i - 1) == 33 {
        i = i + 1
        continue
      }
      let close_text = find_link_text_end_before(text, i + 1, end)
      if close_text > i &&
        close_text + 1 < end &&
        (
          char_at(text, close_text + 1) == 40 ||
          char_at(text, close_text + 1) == 91
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
    if c == 96 {
      let width = delimiter_run_len(text, i, 96)
      let close = find_code_span_end(text, i + width, width)
      if close < 0 || close >= end {
        return true
      }
      i = close + width
    } else if c == 60 {
      match raw_html_inline_end(text, i) {
        Some(close) => if close > end { return true } else { i = close }
        None => {
          let close = find_char(text, 62, i + 1)
          if close >= end && looks_like_raw_html_start_at(text, i) {
            return true
          }
          if close >= end {
            let candidate = text[i + 1:close].to_owned()
            if is_uri_autolink(candidate) || is_email_autolink(candidate) {
              return true
            }
          }
          i = i + 1
        }
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
    char_at(text, start + 1) == 47 ||
    char_at(text, start + 1) == 33 ||
    char_at(text, start + 1) == 63
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
    attrs.push({
      name: attr_name("destination"),
      value: normalize_link_destination(trimmed),
    })
  } else {
    let destination = trim(trimmed[:split].to_owned())
    if !is_valid_link_destination(destination) {
      return attrs
    }
    attrs.push({
      name: attr_name("destination"),
      value: normalize_link_destination(destination),
    })
    attrs.push({
      name: attr_name("title"),
      value: normalize_attribute_text(
        trimmed[split + 2:trimmed.length() - 1].to_owned(),
      ),
    })
  }
  attrs
}

///|
fn is_valid_link_destination(destination : String) -> Bool {
  let trimmed = trim(destination)
  if trimmed.length() >= 2 &&
    char_at(trimmed, 0) == 60 &&
    char_at(trimmed, trimmed.length() - 1) == 62 {
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
    if (c == 60 || c == 62) && !is_escaped_char(text, i) {
      return true
    }
  }
  false
}

///|
fn is_valid_angle_link_destination(destination : String) -> Bool {
  for i in 0..<destination.length() {
    let c = char_at(destination, i)
    if c == 60 || c == 62 || c == 10 || c == 13 {
      return false
    }
  }
  true
}

///|
fn normalize_link_destination(destination : String) -> String {
  let trimmed = trim(destination)
  let decoded = if trimmed.length() >= 2 &&
    char_at(trimmed, 0) == 60 &&
    char_at(trimmed, trimmed.length() - 1) == 62 {
    normalize_attribute_text(trimmed[1:trimmed.length() - 1].to_owned())
  } else {
    normalize_attribute_text(trimmed)
  }
  percent_encode_uri(decoded)
}

///|
fn percent_encode_uri(input : String) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut i = 0
  while i < input.length() {
    let c = char_at(input, i)
    if c == 37 &&
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
fn is_uri_safe_char(c : Int) -> Bool {
  is_ascii_alnum(c) ||
  c == 45 ||
  c == 46 ||
  c == 95 ||
  c == 126 ||
  c == 33 ||
  c == 36 ||
  c == 38 ||
  c == 39 ||
  c == 40 ||
  c == 41 ||
  c == 42 ||
  c == 43 ||
  c == 44 ||
  c == 59 ||
  c == 61 ||
  c == 58 ||
  c == 47 ||
  c == 63 ||
  c == 35 ||
  c == 91 ||
  c == 93 ||
  c == 64
}

///|
fn is_ascii_hex_digit(c : Int) -> Bool {
  (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
}

///|
fn write_percent_utf8(out : StringBuilder, c : Int) -> Unit {
  if c <= 0x7FF {
    write_percent_byte(out, 0xC0 | (c >> 6))
    write_percent_byte(out, 0x80 | (c & 0x3F))
  } else if c <= 0xFFFF {
    write_percent_byte(out, 0xE0 | (c >> 12))
    write_percent_byte(out, 0x80 | ((c >> 6) & 0x3F))
    write_percent_byte(out, 0x80 | (c & 0x3F))
  } else {
    write_percent_byte(out, 0xF0 | (c >> 18))
    write_percent_byte(out, 0x80 | ((c >> 12) & 0x3F))
    write_percent_byte(out, 0x80 | ((c >> 6) & 0x3F))
    write_percent_byte(out, 0x80 | (c & 0x3F))
  }
}

///|
fn write_percent_byte(out : StringBuilder, byte : Int) -> Unit {
  out.write_string("%")
  out.write_string(hex_digit((byte >> 4) & 0xF))
  out.write_string(hex_digit(byte & 0xF))
}

///|
fn hex_digit(value : Int) -> String {
  if value < 10 {
    ascii_char(48 + value)
  } else {
    ascii_char(55 + value)
  }
}

///|
fn contains_unescaped_space(text : String) -> Bool {
  let mut i = 0
  while i < text.length() {
    if char_at(text, i) == 92 &&
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
      let close = if open == 40 { 41 } else { open }
      if (open == 34 || open == 39 || open == 40) &&
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
      return true
    }
  }
  false
}

///|
fn is_escaped_char(text : String, index : Int) -> Bool {
  let mut count = 0
  let mut i = index - 1
  while i >= 0 && char_at(text, i) == 92 {
    count = count + 1
    i = i - 1
  }
  count % 2 == 1
}
