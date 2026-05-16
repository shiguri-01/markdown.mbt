///|
fn parse_inlines(
  text : String,
  registry : RuleRegistry,
  sink : EventSink,
) -> Unit {
  parse_inlines_with_rules(text, registry, registry.inline_parse_rules(), sink)
}

///|
fn parse_inlines_with_rules(
  text : String,
  registry : RuleRegistry,
  rules : Array[Rule],
  sink : EventSink,
) -> Unit {
  if rules.length() == 0 {
    if text.length() > 0 {
      sink.emit(Text(text))
    }
    return
  }
  let mut i = 0
  while i < text.length() {
    let mut consumed = 0
    let ctx = { text, index: i, scanner: inline_scanner(text, i), registry }
    for rule in rules {
      match rule.inline {
        Some(f) => if consumed == 0 { consumed = f(ctx, sink) }
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
fn cm_text_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let start = ctx.index
  if start >= text.length() || is_inline_special(text, start) {
    return 0
  }
  let mut end = start
  while end < text.length() && !is_inline_special(text, end) {
    end = end + 1
  }
  if start == 0 && end == text.length() {
    sink.emit(Text(text))
  } else {
    sink.emit(Text(text[start:end].to_owned()))
  }
  end - start
}

///|
fn cm_escape_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) == 92 &&
    i + 1 < text.length() &&
    is_ascii_punctuation(char_at(text, i + 1)) {
    sink.emit(Text(text[i + 1:i + 2].to_owned()))
    2
  } else {
    0
  }
}

///|
fn cm_hard_break_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if i + 1 < text.length() &&
    char_at(text, i) == 92 &&
    char_at(text, i + 1) == 10 {
    sink.emit(HardBreak)
    2
  } else if char_at(text, i) == 32 {
    let mut end = i
    while end < text.length() && char_at(text, end) == 32 {
      end = end + 1
    }
    if end - i >= 2 && end < text.length() && char_at(text, end) == 10 {
      sink.emit(HardBreak)
      end - i + 1
    } else {
      0
    }
  } else {
    0
  }
}

///|
fn cm_soft_break_inline(ctx : InlineContext, sink : EventSink) -> Int {
  if char_at(ctx.text, ctx.index) == 10 {
    sink.emit(SoftBreak)
    1
  } else {
    0
  }
}

///|
fn cm_code_span_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 96 {
    return 0
  }
  let width = delimiter_run_len(text, i, 96)
  let end = find_code_span_end(text, i + width, width)
  if end < 0 {
    return 0
  }
  sink.emit(Enter(Element::new(tag_name("cm:code_span"))))
  sink.emit(Text(normalize_code_span(text[i + width:end].to_owned())))
  sink.emit(Exit(tag_name("cm:code_span")))
  end - i + width
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
fn cm_autolink_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 60 {
    return 0
  }
  let end = find_char(text, 62, i + 1)
  if end < 0 {
    return 0
  }
  let destination = text[i + 1:end].to_owned()
  let href = if is_uri_autolink(destination) {
    destination
  } else if is_email_autolink(destination) {
    "mailto:" + destination
  } else {
    return 0
  }
  sink.emit(
    Enter(
      Element::with_attrs(tag_name("cm:link"), [
        { name: attr_name("destination"), value: href },
      ]),
    ),
  )
  sink.emit(Text(destination))
  sink.emit(Exit(tag_name("cm:link")))
  end - i + 1
}

///|
fn cm_raw_html_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 60 {
    return 0
  }
  match raw_html_inline_end(text, i) {
    Some(end) => {
      sink.emit(Html(text[i:end].to_owned()))
      return end - i
    }
    None => ()
  }
  let end = find_char(text, 62, i + 1)
  if end < 0 {
    return 0
  }
  let raw = text[i:end + 1].to_owned()
  if !looks_like_raw_html(raw) {
    return 0
  }
  sink.emit(Html(raw))
  end - i + 1
}

///|
fn raw_html_inline_end(text : String, start : Int) -> Int? {
  let rest = text[start:].to_owned()
  if rest.has_prefix("<!--") {
    let end = find_substring(text, "-->", start + 4)
    if end >= 0 {
      Some(end + 3)
    } else {
      None
    }
  } else if rest.has_prefix("<?") {
    let end = find_substring(text, "?>", start + 2)
    if end >= 0 {
      Some(end + 2)
    } else {
      None
    }
  } else if rest.has_prefix("<![CDATA[") {
    let end = find_substring(text, "]]>", start + 9)
    if end >= 0 {
      Some(end + 3)
    } else {
      None
    }
  } else if looks_like_html_declaration(rest) {
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
fn cm_entity_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 38 {
    return 0
  }
  let end = find_char(text, 59, i + 1)
  if end < 0 || end - i > 32 {
    return 0
  }
  let name = text[i + 1:end].to_owned()
  match decode_entity(name) {
    Some(decoded) => {
      sink.emit(Text(decoded))
      end - i + 1
    }
    None => 0
  }
}

///|
fn cm_link_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 91 {
    return 0
  }
  let close_text = find_link_text_end(text, i + 1)
  if close_text < 0 ||
    close_text + 1 >= text.length() ||
    char_at(text, close_text + 1) != 40 {
    return 0
  }
  let close_dest = find_link_destination_end(text, close_text + 2)
  if close_dest < 0 {
    return 0
  }
  let attrs = parse_link_attrs(text[close_text + 2:close_dest].to_owned())
  if attrs.length() == 0 {
    return 0
  }
  sink.emit(Enter(Element::with_attrs(tag_name("cm:link"), attrs)))
  parse_inlines(text[i + 1:close_text].to_owned(), ctx.registry, sink)
  sink.emit(Exit(tag_name("cm:link")))
  close_dest - i + 1
}

///|
fn cm_image_inline(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  if i + 1 >= text.length() ||
    char_at(text, i) != 33 ||
    char_at(text, i + 1) != 91 {
    return 0
  }
  let close_text = find_link_text_end(text, i + 2)
  if close_text < 0 ||
    close_text + 1 >= text.length() ||
    char_at(text, close_text + 1) != 40 {
    return 0
  }
  let close_dest = find_link_destination_end(text, close_text + 2)
  if close_dest < 0 {
    return 0
  }
  let alt = image_alt_text(text[i + 2:close_text].to_owned(), ctx.registry)
  let attrs = parse_link_attrs(text[close_text + 2:close_dest].to_owned())
  if attrs.length() == 0 {
    return 0
  }
  attrs.push({ name: attr_name("alt"), value: alt })
  sink.emit(Enter(Element::with_attrs(tag_name("cm:image"), attrs)))
  sink.emit(Exit(tag_name("cm:image")))
  close_dest - i + 1
}

///|
fn image_alt_text(text : String, registry : RuleRegistry) -> String {
  let sink : EventSink = { events: [] }
  parse_inlines(text, registry, sink)
  let mut out = ""
  for event in sink.events {
    match event {
      Text(text) => out = out + text
      SoftBreak => out = out + "\n"
      HardBreak => out = out + "\n"
      Html(raw) => out = out + raw
      _ => ()
    }
  }
  out
}

///|
fn find_link_text_end(text : String, start : Int) -> Int {
  let mut i = start
  let mut depth = 0
  while i < text.length() {
    let c = char_at(text, i)
    if c == 92 && i + 1 < text.length() {
      i = i + 2
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
fn cm_emphasis_delimiter(ctx : InlineContext, sink : EventSink) -> Int {
  let text = ctx.text
  let i = ctx.index
  let marker = char_at(text, i)
  if marker != 42 && marker != 95 {
    return 0
  }
  let run = delimiter_run_len(text, i, marker)
  if run >= 3 {
    if is_intraword_underscore_delimiter(text, i, 3, marker) {
      return 0
    }
    let end = find_closing_run(text, marker, i + 3, 3)
    if end < 0 {
      return 0
    }
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
    sink.emit(Enter(Element::new(tag_name("cm:strong"))))
    parse_inlines(text[i + 3:end].to_owned(), ctx.registry, sink)
    sink.emit(Exit(tag_name("cm:strong")))
    sink.emit(Exit(tag_name("cm:emphasis")))
    end - i + 3
  } else if run >= 2 {
    if is_intraword_underscore_delimiter(text, i, 2, marker) {
      return 0
    }
    let end = find_closing_run(text, marker, i + 2, 2)
    if end < 0 {
      return 0
    }
    sink.emit(Enter(Element::new(tag_name("cm:strong"))))
    parse_inlines(text[i + 2:end].to_owned(), ctx.registry, sink)
    sink.emit(Exit(tag_name("cm:strong")))
    end - i + 2
  } else {
    if is_intraword_underscore_delimiter(text, i, 1, marker) {
      return 0
    }
    let end = find_closing_single(text, marker, i + 1)
    if end < 0 {
      return 0
    }
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
    parse_inlines(text[i + 1:end].to_owned(), ctx.registry, sink)
    sink.emit(Exit(tag_name("cm:emphasis")))
    end - i + 1
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
    if delimiter_run_len(text, i, marker) >= width &&
      !is_escaped_char(text, i) &&
      !is_intraword_underscore_delimiter(text, i, width, marker) {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn find_closing_single(text : String, marker : Int, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    if char_at(text, i) == marker &&
      (i == 0 || char_at(text, i - 1) != marker) &&
      (i + 1 >= text.length() || char_at(text, i + 1) != marker) &&
      !is_escaped_char(text, i) &&
      !is_intraword_underscore_delimiter(text, i, 1, marker) {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn is_intraword_underscore_delimiter(
  text : String,
  start : Int,
  width : Int,
  marker : Int,
) -> Bool {
  marker == 95 &&
  start > 0 &&
  start + width < text.length() &&
  is_ascii_alnum(char_at(text, start - 1)) &&
  is_ascii_alnum(char_at(text, start + width))
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
    !contains_unescaped_space(trimmed)
  }
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
  if trimmed.length() >= 2 &&
    char_at(trimmed, 0) == 60 &&
    char_at(trimmed, trimmed.length() - 1) == 62 {
    normalize_attribute_text(trimmed[1:trimmed.length() - 1].to_owned())
  } else {
    normalize_attribute_text(trimmed)
  }
}

///|
fn contains_space(text : String) -> Bool {
  for i in 0..<text.length() {
    if is_space(char_at(text, i)) {
      return true
    }
  }
  false
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
        !is_escaped_char(spec, spec.length() - 1) {
        return i
      }
    }
  }
  -1
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
fn decode_entity(name : String) -> String? {
  match name {
    "amp" => Some("&")
    "lt" => Some("<")
    "gt" => Some(">")
    "quot" => Some("\"")
    "apos" => Some("'")
    _ =>
      if name.has_prefix("#x") || name.has_prefix("#X") {
        decode_numeric_entity(name[2:].to_owned(), true)
      } else if name.has_prefix("#") {
        decode_numeric_entity(name[1:].to_owned(), false)
      } else {
        None
      }
  }
}

///|
fn decode_numeric_entity(digits : String, hex : Bool) -> String? {
  if digits == "" {
    return None
  }
  let mut value = 0
  for i in 0..<digits.length() {
    let digit = if hex {
      hex_digit_value(char_at(digits, i))
    } else {
      decimal_digit_value(char_at(digits, i))
    }
    if digit < 0 {
      return None
    }
    let base = if hex { 16 } else { 10 }
    value = value * base + digit
  }
  if value >= 32 && value <= 126 {
    Some(ascii_char(value))
  } else {
    None
  }
}

///|
fn decimal_digit_value(c : Int) -> Int {
  if c >= 48 && c <= 57 {
    c - 48
  } else {
    -1
  }
}

///|
fn hex_digit_value(c : Int) -> Int {
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 65 && c <= 70 {
    c - 55
  } else if c >= 97 && c <= 102 {
    c - 87
  } else {
    -1
  }
}

///|
fn normalize_code_span(text : String) -> String {
  let mut normalized = ""
  for i in 0..<text.length() {
    if is_space(char_at(text, i)) {
      normalized = normalized + " "
    } else {
      normalized = normalized + text[i:i + 1].to_owned()
    }
  }
  if normalized.length() >= 2 &&
    char_at(normalized, 0) == 32 &&
    char_at(normalized, normalized.length() - 1) == 32 &&
    has_non_space(normalized) {
    normalized[1:normalized.length() - 1].to_owned()
  } else {
    normalized
  }
}

///|
fn has_non_space(text : String) -> Bool {
  for i in 0..<text.length() {
    if char_at(text, i) != 32 {
      return true
    }
  }
  false
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
