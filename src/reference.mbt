///|
priv struct ReferenceDefinition {
  label : String
  destination : String
  title : String
}

///|
priv struct ParseState {
  references : Array[ReferenceDefinition]
}

///|
fn ParseState::new() -> ParseState {
  { references: [] }
}

///|
fn ParseState::add_reference(
  self : ParseState,
  definition : ReferenceDefinition,
) -> Unit {
  if find_reference(self.references, definition.label) is None {
    self.references.push(definition)
  }
}

///|
fn ParseState::find_reference(
  self : ParseState,
  label : String,
) -> ReferenceDefinition? {
  find_reference(self.references, normalize_reference_label(label))
}

///|
priv struct ParsedReferenceDefinition {
  definition : ReferenceDefinition
  next_index : Int
}

///|
fn cm_reference_definition_block(ctx : BlockContext) -> BlockRuleResult {
  match parse_reference_definition_at(ctx.lines, ctx.index) {
    Some(parsed) => {
      ctx.state.add_reference(parsed.definition)
      block_match(parsed.next_index - ctx.index, EventFragment::empty())
    }
    None => NoMatch
  }
}

///|
priv struct ResolvedReferenceAttrs {
  attrs : Array[Attr]
  end : Int
}

///|
fn reference_attrs_for_link_text(
  text : String,
  start : Int,
  close_text : Int,
  state : ParseState,
) -> ResolvedReferenceAttrs? {
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == 91 {
    let close_label = find_link_text_end(text, close_text + 2)
    if close_label > close_text {
      let raw_label = text[close_text + 2:close_label].to_owned()
      let label = if raw_label == "" {
        text[start + 1:close_text].to_owned()
      } else {
        raw_label
      }
      return reference_attrs_for_label(label, close_label + 1, state)
    }
  }
  if should_rewrite_shortcut_reference(text, close_text) {
    if is_reference_label_range_blank(text, start + 1, close_text) {
      return None
    }
    let label_text = text[start + 1:close_text].to_owned()
    reference_attrs_for_label(label_text, close_text + 1, state)
  } else {
    None
  }
}

///|
fn reference_attrs_for_image_alt(
  text : String,
  start : Int,
  close_alt : Int,
  alt : String,
  state : ParseState,
) -> ResolvedReferenceAttrs? {
  if close_alt + 1 < text.length() && char_at(text, close_alt + 1) == 91 {
    let close_label = find_link_text_end(text, close_alt + 2)
    if close_label > close_alt {
      let raw_label = text[close_alt + 2:close_label].to_owned()
      let label = if raw_label == "" {
        text[start + 2:close_alt].to_owned()
      } else {
        raw_label
      }
      return reference_attrs_for_label_with_alt(
        label,
        close_label + 1,
        alt,
        state,
      )
    }
  }
  if close_alt + 1 >= text.length() || char_at(text, close_alt + 1) != 40 {
    if is_reference_label_range_blank(text, start + 2, close_alt) {
      return None
    }
    let label_text = text[start + 2:close_alt].to_owned()
    reference_attrs_for_label_with_alt(label_text, close_alt + 1, alt, state)
  } else {
    None
  }
}

///|
fn reference_attrs_for_label(
  label : String,
  end : Int,
  state : ParseState,
) -> ResolvedReferenceAttrs? {
  match state.find_reference(label) {
    Some(definition) => Some({ attrs: reference_attrs(definition), end })
    None => None
  }
}

///|
fn reference_attrs_for_label_with_alt(
  label : String,
  end : Int,
  alt : String,
  state : ParseState,
) -> ResolvedReferenceAttrs? {
  match state.find_reference(label) {
    Some(definition) => {
      let attrs = reference_attrs(definition)
      attrs.push({ name: attr_name("alt"), value: alt })
      Some({ attrs, end })
    }
    None => None
  }
}

///|
fn is_reference_label_range_blank(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  let mut i = start
  while i < end {
    if !is_space(char_at(text, i)) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn reference_attrs(definition : ReferenceDefinition) -> Array[Attr] {
  let attrs = [
    { name: attr_name("destination"), value: definition.destination },
  ]
  if definition.title != "" {
    attrs.push({ name: attr_name("title"), value: definition.title })
  }
  attrs
}

///|
fn may_be_reference_definition_line(line : String) -> Bool {
  let first = first_non_space_index(line)
  first >= 0 && first <= 3 && char_at(line, first) == 91
}

///|
fn parse_reference_definition_at(
  lines : Array[String],
  start : Int,
) -> ParsedReferenceDefinition? {
  match collect_reference_label(lines, start) {
    Some(label_end) => {
      let label = normalize_reference_label(label_end.label)
      if label == "" || !is_valid_reference_label_text(label_end.label) {
        return None
      }
      let mut i = label_end.next_index
      let mut spec = label_end.rest
      while is_blank(spec) && i < lines.length() {
        if is_blank(lines[i]) {
          return None
        }
        spec = lines[i]
        i = i + 1
      }
      let destination = parse_reference_destination_from_spec(spec)
      match destination {
        Some(dest) => {
          let mut title = ""
          let rest = trim(dest.rest)
          if rest != "" {
            match parse_reference_title_lines(rest, lines, i) {
              Some(parsed_title) => {
                title = parsed_title.title
                i = parsed_title.next_index
              }
              None => return None
            }
          } else if i < lines.length() {
            match parse_reference_title_lines(trim(lines[i]), lines, i + 1) {
              Some(parsed_title) => {
                title = parsed_title.title
                i = parsed_title.next_index
              }
              None => ()
            }
          }
          Some({
            definition: { label, destination: dest.destination, title },
            next_index: i,
          })
        }
        None => None
      }
    }
    None =>
      parse_reference_definition(lines[start]).map(fn(def) {
        { definition: def, next_index: start + 1 }
      })
  }
}

///|
priv struct ReferenceLabelEnd {
  label : String
  rest : String
  next_index : Int
}

///|
fn collect_reference_label(
  lines : Array[String],
  start : Int,
) -> ReferenceLabelEnd? {
  if start >= lines.length() || !may_be_reference_definition_line(lines[start]) {
    return None
  }
  let first = first_non_space_index(lines[start])
  let label = StringBuilder::new()
  let mut line_index = start
  let mut pos = first + 1
  while line_index < lines.length() {
    let line = lines[line_index]
    while pos < line.length() {
      let c = char_at(line, pos)
      if c == 92 && pos + 1 < line.length() {
        label.write_view(line[pos:pos + 2])
        pos = pos + 2
      } else if c == 93 {
        if pos + 1 < line.length() && char_at(line, pos + 1) == 58 {
          return Some({
            label: label.to_string(),
            rest: line[pos + 2:].to_owned(),
            next_index: line_index + 1,
          })
        }
        return None
      } else {
        label.write_view(line[pos:pos + 1])
        pos = pos + 1
      }
    }
    line_index = line_index + 1
    if line_index < lines.length() {
      label.write_string("\n")
      pos = 0
    }
  }
  None
}

///|
priv struct ReferenceDestinationRest {
  destination : String
  rest : String
}

///|
fn parse_reference_destination_from_spec(
  spec : String,
) -> ReferenceDestinationRest? {
  let trimmed = trim(spec)
  if trimmed == "" {
    return None
  }
  if char_at(trimmed, 0) == 60 {
    let close = find_angle_link_destination_close(trimmed, 1)
    if close < 0 {
      return None
    }
    let rest = trimmed[close + 1:].to_owned()
    if !is_blank(rest) && !is_space(char_at(rest, 0)) {
      return None
    }
    return Some({
      destination: normalize_link_destination(trimmed[:close + 1].to_owned()),
      rest,
    })
  }
  let mut i = 0
  let mut depth = 0
  while i < trimmed.length() {
    let c = char_at(trimmed, i)
    if c == 92 && i + 1 < trimmed.length() {
      i = i + 2
    } else if is_space(c) && depth == 0 {
      let destination = trimmed[:i].to_owned()
      if !is_valid_link_destination(destination) {
        return None
      }
      return Some({
        destination: normalize_link_destination(destination),
        rest: trimmed[i:].to_owned(),
      })
    } else if c == 40 {
      depth = depth + 1
      i = i + 1
    } else if c == 41 {
      if depth == 0 {
        return None
      }
      depth = depth - 1
      i = i + 1
    } else {
      i = i + 1
    }
  }
  if !is_valid_link_destination(trimmed) {
    None
  } else {
    Some({ destination: normalize_link_destination(trimmed), rest: "" })
  }
}

///|
priv struct ParsedReferenceTitle {
  title : String
  next_index : Int
}

///|
fn parse_reference_title_lines(
  first : String,
  lines : Array[String],
  next : Int,
) -> ParsedReferenceTitle? {
  let trimmed = trim(first)
  if trimmed.length() < 1 {
    return None
  }
  let open = char_at(trimmed, 0)
  let close = if open == 40 { 41 } else { open }
  if open != 34 && open != 39 && open != 40 {
    return None
  }
  let content = StringBuilder::new()
  let mut i = 1
  while i < trimmed.length() {
    if char_at(trimmed, i) == close && !is_escaped_char(trimmed, i) {
      if trim(trimmed[i + 1:].to_owned()) == "" {
        return Some({
          title: normalize_attribute_text(content.to_string()),
          next_index: next,
        })
      }
      return None
    }
    content.write_view(trimmed[i:i + 1])
    i = i + 1
  }
  let mut line_index = next
  while line_index < lines.length() {
    if is_blank(lines[line_index]) {
      return None
    }
    content.write_string("\n")
    let line = lines[line_index]
    let mut j = 0
    while j < line.length() {
      if char_at(line, j) == close && !is_escaped_char(line, j) {
        if trim(line[j + 1:].to_owned()) == "" {
          return Some({
            title: normalize_attribute_text(content.to_string()),
            next_index: line_index + 1,
          })
        }
        return None
      }
      content.write_view(line[j:j + 1])
      j = j + 1
    }
    line_index = line_index + 1
  }
  None
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
  if !is_valid_reference_label_range(trimmed, 1, close) {
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
fn should_rewrite_shortcut_reference(input : String, close_text : Int) -> Bool {
  if close_text + 1 >= input.length() {
    true
  } else if char_at(input, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(input, close_text + 2)
    close_dest < 0 ||
    parse_link_attrs(input[close_text + 2:close_dest].to_owned()).length() == 0
  } else {
    true
  }
}

///|
fn is_valid_reference_label_text(label : String) -> Bool {
  is_valid_reference_label_range(label, 0, label.length())
}

///|
fn is_valid_reference_label_range(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  let mut i = start
  while i < end {
    let c = char_at(text, i)
    if c == 92 && i + 1 < end && is_ascii_punctuation(char_at(text, i + 1)) {
      i = i + 2
    } else if c == 91 || c == 93 {
      return false
    } else {
      i = i + 1
    }
  }
  true
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
  collapse_spaces(
    commonmark_case_fold(normalize_reference_label_escapes(trim(label))),
  )
}

///|
fn normalize_reference_label_escapes(label : String) -> String {
  let mut first_escape = -1
  for i in 0..<label.length() {
    if char_at(label, i) == 92 &&
      i + 1 < label.length() &&
      (char_at(label, i + 1) == 91 || char_at(label, i + 1) == 93) {
      first_escape = i
      break
    }
  }
  if first_escape < 0 {
    return label
  }
  let out = StringBuilder::new(size_hint=label.length())
  if first_escape > 0 {
    out.write_view(label[:first_escape])
  }
  let mut i = first_escape
  while i < label.length() {
    let c = char_at(label, i)
    if c == 92 &&
      i + 1 < label.length() &&
      (char_at(label, i + 1) == 91 || char_at(label, i + 1) == 93) {
      out.write_view(label[i + 1:i + 2])
      i = i + 2
    } else {
      out.write_view(label[i:i + 1])
      i = i + 1
    }
  }
  out.to_string()
}

///|
fn ascii_lower(input : String) -> String {
  let mut first_upper = -1
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if c >= 65 && c <= 90 {
      first_upper = i
      break
    }
  }
  if first_upper < 0 {
    return input
  }
  let out = StringBuilder::new(size_hint=input.length())
  if first_upper > 0 {
    out.write_view(input[:first_upper])
  }
  for i in first_upper..<input.length() {
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
fn commonmark_case_fold(input : String) -> String {
  let mut first_fold = -1
  for i in 0..<input.length() {
    let c = char_at(input, i)
    if (c >= 65 && c <= 90) || (c >= 128 && unicode_case_fold_char(c) != None) {
      first_fold = i
      break
    }
  }
  if first_fold < 0 {
    return input
  }
  let out = StringBuilder::new(size_hint=input.length())
  if first_fold > 0 {
    out.write_view(input[:first_fold])
  }
  for i in first_fold..<input.length() {
    let c = char_at(input, i)
    match unicode_case_fold_char(c) {
      Some(folded) => out.write_string(folded)
      None => out.write_view(input[i:i + 1])
    }
  }
  out.to_string()
}

///|
fn collapse_spaces(input : String) -> String {
  let mut first_space = -1
  let mut previous_space = false
  for i in 0..<input.length() {
    let c = char_at(input, i)
    let current_space = is_space(c)
    if current_space && c != 32 {
      first_space = i
      break
    }
    if current_space && previous_space {
      first_space = i - 1
      break
    }
    previous_space = current_space
  }
  if first_space < 0 {
    return input
  }
  let out = StringBuilder::new(size_hint=input.length())
  if first_space > 0 {
    out.write_view(input[:first_space])
  }
  let mut in_space = false
  for i in first_space..<input.length() {
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
