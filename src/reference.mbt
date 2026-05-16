///|
priv struct ReferenceDefinition {
  label : String
  destination : String
  title : String
}

///|
fn resolve_reference_definitions(input : String) -> String {
  if !may_have_reference_definition(input) {
    return input
  }
  let refs : Array[ReferenceDefinition] = []
  let body_lines : Array[String] = []
  let mut removed_definition = false
  let lines : Array[String] = []
  for line in input.split("\n") {
    lines.push(line.to_owned())
  }
  let mut i = 0
  while i < lines.length() {
    match parse_reference_definition(lines[i]) {
      Some(def) => {
        let continuation = if def.title == "" && i + 1 < lines.length() {
          parse_reference_title_continuation(lines[i + 1])
        } else {
          None
        }
        match continuation {
          Some(title) => {
            refs.push({ label: def.label, destination: def.destination, title })
            removed_definition = true
            i = i + 2
          }
          None => {
            refs.push(def)
            removed_definition = true
            i = i + 1
          }
        }
      }
      None => {
        body_lines.push(lines[i])
        i = i + 1
      }
    }
  }
  if refs.length() == 0 {
    input
  } else {
    let body = if removed_definition { join_lines(body_lines) } else { input }
    rewrite_reference_links(body, refs)
  }
}

///|
fn may_have_reference_definition(input : String) -> Bool {
  let mut line_start = 0
  while line_start < input.length() {
    let mut i = line_start
    let mut spaces = 0
    while i < input.length() && spaces < 4 && char_at(input, i) == 32 {
      i = i + 1
      spaces = spaces + 1
    }
    if spaces <= 3 && i < input.length() && char_at(input, i) == 91 {
      let close = find_link_text_end(input, i + 1)
      if close > i &&
        close + 1 < input.length() &&
        char_at(input, close + 1) == 58 {
        return true
      }
    }
    let next = find_char(input, 10, line_start)
    if next < 0 {
      return false
    }
    line_start = next + 1
  }
  false
}

///|
fn parse_reference_definition(line : String) -> ReferenceDefinition? {
  let trimmed = trim(line)
  if !trimmed.has_prefix("[") {
    return None
  }
  let close = find_link_text_end(trimmed, 1)
  if close <= 1 ||
    close + 1 >= trimmed.length() ||
    char_at(trimmed, close + 1) != 58 {
    return None
  }
  let label = normalize_reference_label(trimmed[1:close].to_owned())
  let spec = trim(trimmed[close + 2:].to_owned())
  if label == "" || spec == "" {
    return None
  }
  let attrs = parse_link_attrs(spec)
  let mut has_destination = false
  let mut destination = ""
  let mut title = ""
  for attr in attrs {
    if attr.name.value == "destination" {
      has_destination = true
      destination = attr.value
    } else if attr.name.value == "title" {
      title = attr.value
    }
  }
  if !has_destination {
    None
  } else {
    Some({ label, destination, title })
  }
}

///|
fn parse_reference_title_continuation(line : String) -> String? {
  if count_leading_spaces(line) == 0 {
    return None
  }
  let trimmed = trim(line)
  if trimmed.length() < 2 {
    return None
  }
  let open = char_at(trimmed, 0)
  let close = if open == 40 { 41 } else { open }
  if (open == 34 || open == 39 || open == 40) &&
    char_at(trimmed, trimmed.length() - 1) == close {
    Some(normalize_attribute_text(trimmed[1:trimmed.length() - 1].to_owned()))
  } else {
    None
  }
}

///|
fn rewrite_reference_links(
  input : String,
  refs : Array[ReferenceDefinition],
) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut i = 0
  while i < input.length() {
    if i + 1 < input.length() &&
      char_at(input, i) == 33 &&
      char_at(input, i + 1) == 91 {
      let close_alt = find_link_text_end(input, i + 2)
      if close_alt > i {
        if close_alt + 1 < input.length() && char_at(input, close_alt + 1) == 91 {
          let close_label = find_link_text_end(input, close_alt + 2)
          if close_label > close_alt {
            let alt = input[i + 2:close_alt].to_owned()
            let raw_label = input[close_alt + 2:close_label].to_owned()
            let label = if raw_label == "" { alt } else { raw_label }
            match find_reference(refs, normalize_reference_label(label)) {
              Some(def) => {
                out.write_string(reference_rewrite("![", alt, def))
                i = close_label + 1
                continue
              }
              None => ()
            }
          }
        } else if close_alt + 1 >= input.length() ||
          char_at(input, close_alt + 1) != 40 {
          let alt = input[i + 2:close_alt].to_owned()
          match find_reference(refs, normalize_reference_label(alt)) {
            Some(definition) => {
              out.write_string(reference_rewrite("![", alt, definition))
              i = close_alt + 1
              continue
            }
            None => ()
          }
        }
      }
    } else if char_at(input, i) == 91 {
      let close_text = find_link_text_end(input, i + 1)
      if close_text > i &&
        close_text + 1 < input.length() &&
        char_at(input, close_text + 1) == 91 {
        let close_label = find_link_text_end(input, close_text + 2)
        if close_label > close_text {
          let text = input[i + 1:close_text].to_owned()
          let raw_label = input[close_text + 2:close_label].to_owned()
          let label = if raw_label == "" { text } else { raw_label }
          match find_reference(refs, normalize_reference_label(label)) {
            Some(def) => {
              out.write_string(reference_rewrite("[", text, def))
              i = close_label + 1
              continue
            }
            None => ()
          }
        }
      } else if close_text > i &&
        (
          close_text + 1 >= input.length() ||
          char_at(input, close_text + 1) != 40
        ) {
        let text = input[i + 1:close_text].to_owned()
        match find_reference(refs, normalize_reference_label(text)) {
          Some(definition) => {
            out.write_string(reference_rewrite("[", text, definition))
            i = close_text + 1
            continue
          }
          None => ()
        }
      }
    }
    out.write_view(input[i:i + 1])
    i = i + 1
  }
  out.to_string()
}

///|
fn reference_rewrite(
  prefix : String,
  text : String,
  definition : ReferenceDefinition,
) -> String {
  let mut out = prefix + text + "](" + reference_destination_literal(definition)
  if definition.title != "" {
    out = out + " \"" + definition.title + "\""
  }
  out + ")"
}

///|
fn reference_destination_literal(definition : ReferenceDefinition) -> String {
  if definition.destination == "" && definition.title != "" {
    "<>"
  } else if contains_space(definition.destination) {
    "<" + definition.destination + ">"
  } else {
    definition.destination
  }
}

///|
fn find_reference(
  refs : Array[ReferenceDefinition],
  label : String,
) -> ReferenceDefinition? {
  for definition in refs {
    if definition.label == label {
      return Some(definition)
    }
  }
  None
}

///|
fn normalize_reference_label(label : String) -> String {
  collapse_spaces(ascii_lower(normalize_attribute_text(trim(label))))
}

///|
fn ascii_lower(input : String) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if c >= 65 && c <= 90 {
      out.write_string(ascii_char(c + 32))
    } else {
      out.write_view(input[i:i + 1])
    }
  }
  out.to_string()
}

///|
fn collapse_spaces(input : String) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut in_space = false
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if is_space(c) {
      if !in_space {
        out.write_string(" ")
      }
      in_space = true
    } else {
      out.write_view(input[i:i + 1])
      in_space = false
    }
  }
  out.to_string()
}

///|
fn join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  for i in 0..<lines.length() {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
  }
  out.to_string()
}
