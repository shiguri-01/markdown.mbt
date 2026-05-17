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
    if count_leading_spaces(ctx.lines[i]) > 3 {
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
    let mut item_text = trim(item)
    i = i + 1
    let continuation = collect_list_continuation(ctx.lines, i, true)
    item_text = item_text + continuation.text
    i = continuation.next_index
    let mut item_end = i
    let mut blank_count = 0
    while i < ctx.lines.length() && trim(ctx.lines[i]) == "" {
      blank_count = blank_count + 1
      i = i + 1
    }
    if blank_count > 0 &&
      i < ctx.lines.length() &&
      is_list_continuation_after_blank(ctx.lines[i]) {
      loose = true
      for _ in 0..<blank_count {
        item_text = item_text + "\n"
      }
      let continuation = collect_list_continuation(ctx.lines, i, false)
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
    item_texts.push(item_text)
    item_starts.push(item_start)
    item_ends.push(item_end)
  }
  let buffer = Events::new()
  let sink = buffer.sink()
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
      loose~,
    )
    sink.emit(Exit(tag_name("cm:item")))
  }
  sink.emit(Exit(tag_name("cm:list")))
  block_match(i - ctx.index, event_fragment_from_events(buffer.collect()))
}

///|
fn emit_list_item_content(
  item_text : String,
  registry : RuleRegistry,
  inline_rules : Array[RuleEntry],
  sink : Sink,
  loose? : Bool = false,
) -> Unit {
  if !loose &&
    item_text != "" &&
    !contains_char(item_text, 10) &&
    !is_paragraph_interrupt(item_text) {
    parse_inlines_with_rules(item_text, registry, inline_rules, sink)
    return
  }
  let buffer = Events::new()
  parse_blocks_into(item_text, registry, buffer.sink())
  let events = buffer.collect()
  if !loose && events.length() >= 2 && is_single_paragraph_events(events) {
    for i in 1..<(events.length() - 1) {
      sink.emit(events[i])
    }
  } else {
    for event in events {
      sink.emit(event)
    }
  }
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
) -> ListContinuation {
  let mut i = start
  let text = StringBuilder::new()
  while i < lines.length() &&
        trim(lines[i]) != "" &&
        !is_ordered_list_marker(trim(lines[i])) &&
        !is_unordered_list_marker(trim(lines[i])) {
    if count_leading_spaces(lines[i]) >= 2 {
      text.write_string("\n")
      text.write_view(lines[i][2:])
      i = i + 1
    } else if allow_lazy && !is_paragraph_interrupt(lines[i]) {
      text.write_string("\n")
      text.write_string(paragraph_line(lines[i]))
      i = i + 1
    } else {
      break
    }
  }
  { text: text.to_string(), next_index: i }
}

///|
fn is_list_continuation_after_blank(line : String) -> Bool {
  trim(line) != "" &&
  count_leading_spaces(line) >= 2 &&
  !is_ordered_list_marker(trim(line)) &&
  !is_unordered_list_marker(trim(line))
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
  count_leading_spaces(line) <= 3 &&
  is_ordered_list_marker(trim(line)) &&
  ordered_list_start(trim(line)) == 1
}

///|
fn is_unordered_list_marker_line(line : String) -> Bool {
  count_leading_spaces(line) <= 3 && is_unordered_list_marker(trim(line))
}

///|
fn is_unordered_list_marker(line : String) -> Bool {
  line.length() >= 1 &&
  (char_at(line, 0) == 45 || char_at(line, 0) == 42 || char_at(line, 0) == 43) &&
  (line.length() == 1 || is_space(char_at(line, 1)))
}

///|
fn strip_unordered_marker(line : String) -> String {
  if line.length() <= 1 {
    ""
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
  marker > 0 &&
  marker < line.length() &&
  (char_at(line, marker) == 46 || char_at(line, marker) == 41) &&
  (marker + 1 >= line.length() || is_space(char_at(line, marker + 1)))
}

///|
fn ordered_list_start(line : String) -> Int {
  let marker = ordered_marker_end(line)
  let mut value = 0
  for i in 0..<marker {
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
  } else {
    line[marker + 2:].to_owned()
  }
}

///|
fn ordered_marker_end(line : String) -> Int {
  let mut i = 0
  while i < line.length() && char_at(line, i) >= 48 && char_at(line, i) <= 57 {
    i = i + 1
  }
  if i == 0 || i > 9 {
    -1
  } else {
    i
  }
}
