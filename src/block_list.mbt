///|
fn cm_list_block(ctx : BlockContext) -> BlockRuleResult {
  if count_leading_spaces(ctx.lines[ctx.index]) > 3 {
    return NoMatch
  }
  let line = trim(ctx.lines[ctx.index])
  let ordered = is_ordered_list_marker(line)
  let unordered = is_unordered_list_marker(line)
  if !ordered && !unordered {
    return NoMatch
  }
  let ordered_delimiter = if ordered { ordered_list_delimiter(line) } else { 0 }
  let unordered_delimiter = if unordered { char_at(line, 0) } else { 0 }
  let list_attrs = list_attrs(ordered, line)
  let mut i = ctx.index
  let mut loose = false
  let item_texts : Array[String] = []
  let item_starts : Array[Int] = []
  let item_ends : Array[Int] = []
  while i < ctx.lines.length() {
    let item_start = i
    if i > ctx.index && is_thematic_break_marker_line(ctx.lines[i]) {
      break
    }
    let marker_indent = count_leading_spaces(ctx.lines[i])
    if marker_indent > 3 {
      break
    }
    let current = trim(ctx.lines[i])
    if !same_list_marker(
        current, ordered, ordered_delimiter, unordered_delimiter,
      ) {
      break
    }
    let item = if ordered {
      strip_ordered_marker(current)
    } else {
      strip_unordered_marker(current)
    }
    let content_indent = list_item_content_indent(ctx.lines[i], ordered)
    let mut item_text = if count_leading_spaces(item) >= 4 {
      item
    } else {
      trim(item)
    }
    i = i + 1
    let continuation = collect_list_continuation(
      ctx.lines,
      i,
      true,
      content_indent,
    )
    item_text = item_text + continuation.text
    i = continuation.next_index
    let mut item_end = i
    let mut blank_count = 0
    while i < ctx.lines.length() && is_blank(ctx.lines[i]) {
      blank_count = blank_count + 1
      i = i + 1
    }
    if blank_count > 0 &&
      i < ctx.lines.length() &&
      item_text != "" &&
      is_list_continuation_after_blank(ctx.lines[i], content_indent) {
      if is_loose_list_blank_continuation(
          ctx.lines[i],
          content_indent,
          item_text,
        ) {
        loose = true
      }
      for _ in 0..<blank_count {
        item_text = item_text + "\n"
      }
      let continuation = collect_list_continuation(
        ctx.lines,
        i,
        false,
        content_indent,
      )
      item_text = item_text + continuation.text
      i = continuation.next_index
      item_end = i
    } else if blank_count > 0 &&
      i < ctx.lines.length() &&
      same_list_marker(
        trim(ctx.lines[i]),
        ordered,
        ordered_delimiter,
        unordered_delimiter,
      ) {
      loose = true
    } else if blank_count > 0 {
      i = item_end
    }
    let mut collecting = true
    while collecting {
      let mut more_blanks = 0
      let blank_start = i
      while i < ctx.lines.length() && is_blank(ctx.lines[i]) {
        more_blanks = more_blanks + 1
        i = i + 1
      }
      if more_blanks > 0 &&
        i < ctx.lines.length() &&
        item_text != "" &&
        is_list_continuation_after_blank(ctx.lines[i], content_indent) {
        if is_loose_list_blank_continuation(
            ctx.lines[i],
            content_indent,
            item_text,
          ) {
          loose = true
        }
        for _ in 0..<more_blanks {
          item_text = item_text + "\n"
        }
        let continuation = collect_list_continuation(
          ctx.lines,
          i,
          false,
          content_indent,
        )
        item_text = item_text + continuation.text
        i = continuation.next_index
        item_end = i
      } else if more_blanks > 0 &&
        i < ctx.lines.length() &&
        same_list_marker(
          trim(ctx.lines[i]),
          ordered,
          ordered_delimiter,
          unordered_delimiter,
        ) {
        loose = true
      } else {
        if more_blanks > 0 {
          i = blank_start
        }
        collecting = false
      }
    }
    item_texts.push(item_text)
    item_starts.push(item_start)
    item_ends.push(item_end)
  }
  let buffer = Events::new()
  let sink = buffer.owned_sink()
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:list"),
        list_attrs,
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
    ),
  )
  for n in 0..<item_texts.length() {
    sink.emit(
      Enter(
        Element::with_attrs(
          tag_name("cm:item"),
          [],
          range=Some(block_source_range(ctx, item_starts[n], item_ends[n])),
        ),
      ),
    )
    emit_list_item_content(
      item_texts[n],
      ctx.registry,
      ctx.inline_rules,
      sink,
      ctx.state,
      loose~,
    )
    sink.emit(Exit(tag_name("cm:item")))
  }
  sink.emit(Exit(tag_name("cm:list")))
  block_match(i - ctx.index, buffer.into_fragment())
}

///|
fn is_list_marker_item_content(text : String) -> Bool {
  let trimmed = trim(text)
  is_ordered_list_marker(trimmed) || is_unordered_list_marker(trimmed)
}

///|
fn emit_list_item_content(
  item_text : String,
  registry : RuleRegistry,
  inline_rules : Array[RuleEntry],
  sink : Sink,
  state : ParseState,
  loose? : Bool = false,
) -> Unit {
  match parse_reference_definition(trim(item_text)) {
    Some(definition) => {
      state.add_reference(definition)
      return
    }
    None => ()
  }
  if !loose &&
    item_text != "" &&
    !contains_char(item_text, 10) &&
    count_leading_spaces(item_text) < 4 &&
    !is_list_marker_item_content(item_text) &&
    !is_paragraph_interrupt(item_text) {
    parse_inlines_with_rules(item_text, registry, inline_rules, sink, state)
    return
  }
  let buffer = Events::new()
  parse_blocks_into(item_text, registry, buffer.owned_sink(), state)
  let events = buffer.owned_events()
  if !loose && events.length() >= 2 && is_single_paragraph_events(events) {
    for i in 1..<(events.length() - 1) {
      sink.emit(events[i])
    }
  } else if !loose {
    emit_without_paragraph_wrappers(events, sink)
  } else {
    for event in events {
      sink.emit(event)
    }
  }
}

///|
fn emit_without_paragraph_wrappers(events : Array[Event], sink : Sink) -> Unit {
  let mut depth = 0
  let mut previous_text = false
  for event in events {
    match event {
      Enter(el) =>
        if el.tag.value == "cm:paragraph" && depth == 0 {
          ()
        } else {
          if depth == 0 && previous_text && is_tight_list_block_child(el.tag) {
            sink.emit(SoftBreak)
          }
          sink.emit(event)
          depth = depth + 1
          previous_text = false
        }
      Exit(tag) =>
        if tag.value == "cm:paragraph" && depth == 0 {
          ()
        } else {
          sink.emit(event)
          depth = depth - 1
          previous_text = false
        }
      Text(_) => {
        sink.emit(event)
        previous_text = depth == 0
      }
      _ => {
        sink.emit(event)
        previous_text = false
      }
    }
  }
}

///|
fn is_tight_list_block_child(tag : Tag) -> Bool {
  tag.value == "cm:list" ||
  tag.value == "cm:block_quote" ||
  tag.value == "cm:code_block" ||
  tag.value == "cm:heading"
}

///|
priv struct ListContinuation {
  text : String
  next_index : Int
}

///|
fn collect_list_continuation(
  lines : Array[String],
  start : Int,
  allow_lazy : Bool,
  content_indent : Int,
) -> ListContinuation {
  let mut i = start
  let text = StringBuilder::new()
  while i < lines.length() &&
        !is_blank(lines[i]) &&
        !is_list_sibling_marker(lines[i], content_indent) {
    let leading = count_leading_spaces(lines[i])
    if leading >= content_indent {
      text.write_string("\n")
      text.write_view(lines[i][content_indent:])
      i = i + 1
    } else if leading >= 2 &&
      !is_ordered_list_marker(trim(lines[i])) &&
      !is_unordered_list_marker(trim(lines[i])) {
      text.write_string("\n")
      text.write_view(lines[i][2:])
      i = i + 1
    } else if allow_lazy && !is_paragraph_interrupt(lines[i]) {
      text.write_string("\n")
      text.write_string(list_lazy_continuation_line(lines[i]))
      i = i + 1
    } else {
      break
    }
  }
  { text: text.to_string(), next_index: i }
}

///|
fn list_lazy_continuation_line(line : String) -> String {
  if count_leading_spaces(line) > 3 {
    line
  } else {
    paragraph_line(line)
  }
}

///|
fn is_list_sibling_marker(line : String, content_indent : Int) -> Bool {
  count_leading_spaces(line) < content_indent &&
  count_leading_spaces(line) <= 3 &&
  (is_ordered_list_marker(trim(line)) || is_unordered_list_marker(trim(line)))
}

///|
fn list_item_content_indent(line : String, ordered : Bool) -> Int {
  let leading = count_leading_spaces(line)
  let current = trim(line)
  let marker_width = if ordered { ordered_marker_end(current) + 1 } else { 1 }
  let mut spaces = 0
  let mut i = marker_width
  while i < current.length() && char_at(current, i) == 32 && spaces < 5 {
    spaces = spaces + 1
    i = i + 1
  }
  if spaces > 0 && spaces < 5 {
    leading + marker_width + spaces
  } else {
    leading + marker_width + 1
  }
}

///|
fn is_list_continuation_after_blank(
  line : String,
  content_indent : Int,
) -> Bool {
  !is_blank(line) && count_leading_spaces(line) >= content_indent
}

///|
fn is_loose_list_blank_continuation(
  line : String,
  content_indent : Int,
  item_text : String,
) -> Bool {
  let leading = count_leading_spaces(line)
  !has_open_fenced_code(item_text) &&
  (
    leading == content_indent ||
    (leading >= content_indent + 4 && !has_nested_list_marker(item_text))
  )
}

///|
fn has_open_fenced_code(text : String) -> Bool {
  let mut fence = ""
  for line in text.split("\n") {
    if fence == "" {
      let marker = fence_marker(trim(line.to_owned()))
      if marker != "" {
        fence = marker
      }
    } else if is_closing_fence_line(line.to_owned(), fence) {
      fence = ""
    }
  }
  fence != ""
}

///|
fn has_nested_list_marker(text : String) -> Bool {
  for line in text.split("\n") {
    let trimmed = trim(line.to_owned())
    if is_ordered_list_marker(trimmed) || is_unordered_list_marker(trimmed) {
      return true
    }
  }
  false
}

///|
fn same_list_marker(
  line : String,
  ordered : Bool,
  ordered_delimiter : Int,
  unordered_delimiter : Int,
) -> Bool {
  if ordered {
    is_ordered_list_marker(line) &&
    ordered_list_delimiter(line) == ordered_delimiter
  } else {
    is_unordered_list_marker(line) && char_at(line, 0) == unordered_delimiter
  }
}

///|
fn is_single_paragraph_events(events : Array[Event]) -> Bool {
  match events[0] {
    Enter(el) => if el.tag.value != "cm:paragraph" { return false }
    _ => return false
  }
  match events[events.length() - 1] {
    Exit(tag) => if tag.value != "cm:paragraph" { return false }
    _ => return false
  }
  let mut depth = 0
  for i in 0..<events.length() {
    match events[i] {
      Enter(_) => depth = depth + 1
      Exit(_) => {
        depth = depth - 1
        if depth == 0 && i < events.length() - 1 {
          return false
        }
      }
      _ => ()
    }
  }
  depth == 0
}

///|
fn is_ordered_list_paragraph_interrupt(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  let marker = ordered_marker_end_at(line, leading)
  leading <= 3 &&
  is_ordered_list_marker_at(line, leading, marker) &&
  ordered_list_start_at(line, leading, marker) == 1 &&
  has_nonblank_after_marker(line, marker + 2)
}

///|
fn is_unordered_list_marker_line(line : String) -> Bool {
  let leading = count_leading_spaces(line)
  leading <= 3 &&
  is_unordered_list_marker_at(line, leading) &&
  has_nonblank_after_marker(line, leading + 2)
}

///|
fn is_unordered_list_marker(line : String) -> Bool {
  is_unordered_list_marker_at(line, 0)
}

///|
fn is_unordered_list_marker_at(line : String, start : Int) -> Bool {
  start < line.length() &&
  (
    char_at(line, start) == 45 ||
    char_at(line, start) == 42 ||
    char_at(line, start) == 43
  ) &&
  (start + 1 >= line.length() || is_space(char_at(line, start + 1)))
}

///|
fn strip_unordered_marker(line : String) -> String {
  if line.length() <= 1 {
    ""
  } else if char_at(line, 1) == 9 {
    expand_tabs_from_column(line[2:].to_owned(), 4, 2)
  } else {
    line[2:].to_owned()
  }
}

///|
fn list_attrs(ordered : Bool, line : String) -> Array[Attr] {
  let attrs = [
    {
      name: attr_name("ordered"),
      value: if ordered {
        "true"
      } else {
        "false"
      },
    },
  ]
  if ordered {
    attrs.push({
      name: attr_name("start"),
      value: ordered_list_start(line).to_string(),
    })
  }
  attrs
}

///|
fn is_ordered_list_marker(line : String) -> Bool {
  let marker = ordered_marker_end(line)
  is_ordered_list_marker_at(line, 0, marker)
}

///|
fn is_ordered_list_marker_at(line : String, start : Int, marker : Int) -> Bool {
  marker > start &&
  marker < line.length() &&
  (char_at(line, marker) == 46 || char_at(line, marker) == 41) &&
  (marker + 1 >= line.length() || is_space(char_at(line, marker + 1)))
}

///|
fn ordered_list_start(line : String) -> Int {
  let marker = ordered_marker_end(line)
  ordered_list_start_at(line, 0, marker)
}

///|
fn ordered_list_start_at(line : String, start : Int, marker : Int) -> Int {
  let mut value = 0
  for i in start..<marker {
    value = value * 10 + char_at(line, i) - 48
  }
  value
}

///|
fn ordered_list_delimiter(line : String) -> Int {
  let marker = ordered_marker_end(line)
  if marker >= 0 && marker < line.length() {
    char_at(line, marker)
  } else {
    0
  }
}

///|
fn strip_ordered_marker(line : String) -> String {
  let marker = ordered_marker_end(line)
  if marker + 2 > line.length() {
    ""
  } else if marker + 1 < line.length() && char_at(line, marker + 1) == 9 {
    expand_tabs_from_column(
      line[marker + 2:].to_owned(),
      ((marker + 1) / 4 + 1) * 4,
      ((marker + 1) / 4 + 1) * 4 - marker - 2,
    )
  } else {
    line[marker + 2:].to_owned()
  }
}

///|
fn ordered_marker_end(line : String) -> Int {
  ordered_marker_end_at(line, 0)
}

///|
fn ordered_marker_end_at(line : String, start : Int) -> Int {
  let mut i = 0
  while start + i < line.length() &&
        char_at(line, start + i) >= 48 &&
        char_at(line, start + i) <= 57 {
    i = i + 1
  }
  if i == 0 || i > 9 {
    -1
  } else {
    start + i
  }
}

///|
fn has_nonblank_after_marker(line : String, start : Int) -> Bool {
  if start > line.length() {
    return false
  }
  for i in start..<line.length() {
    if !is_space(char_at(line, i)) {
      return true
    }
  }
  false
}
