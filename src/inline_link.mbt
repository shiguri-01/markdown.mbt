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
  let buffer = EventBuffer::new()
  parse_inlines(text, registry, buffer.sink())
  let mut out = ""
  for event in buffer.collect() {
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
