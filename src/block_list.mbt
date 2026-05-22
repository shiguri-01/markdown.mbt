///|
fn cm_list_block(ctx : BlockContext) -> BlockRuleResult {
  guard count_leading_spaces(ctx.lines[ctx.index]) <= 3 else { NoMatch }
  let line = trim(ctx.lines[ctx.index])
  let ordered = is_ordered_list_marker(line)
  let unordered = is_unordered_list_marker(line)
  guard ordered || unordered else { NoMatch }
  let ordered_delimiter = if ordered { ordered_list_delimiter(line) } else { 0 }
  let unordered_delimiter = if unordered { char_at(line, 0) } else { 0 }
  let list_attrs = list_attrs(ordered, line)
  let mut i = ctx.index
  let mut loose = false
  let item_sources : Array[ListItemSource] = []
  while i < ctx.lines.length() {
    let item_start = i
    if i > ctx.index && is_thematic_break_marker_line(ctx.lines[i]) {
      break
    }
    let marker_indent = count_leading_spaces(ctx.lines[i])
    if marker_indent > 3 {
      break
    }
    if !same_list_marker_line_at(
        ctx.lines[i],
        marker_indent,
        ordered,
        ordered_delimiter,
        unordered_delimiter,
      ) {
      break
    }
    let item = strip_list_marker_line_at(ctx.lines[i], marker_indent, ordered)
    let content_indent = list_item_content_indent(ctx.lines[i], ordered)
    let first_line = if count_leading_spaces(item) >= 4 {
      item
    } else {
      trim(item)
    }
    let item_payload = BlockPayload(first_line)
    i = i + 1
    i = collect_list_continuation_into(
      item_payload,
      ctx.lines,
      i,
      true,
      content_indent,
    )
    let mut item_end = i
    let mut blank_count = 0
    while i < ctx.lines.length() && is_blank(ctx.lines[i]) {
      blank_count = blank_count + 1
      i = i + 1
    }
    if blank_count > 0 &&
      i < ctx.lines.length() &&
      item_payload.is_not_empty() &&
      is_list_continuation_after_blank(ctx.lines[i], content_indent) {
      if is_loose_list_blank_continuation(
          ctx.lines[i],
          content_indent,
          item_payload,
        ) {
        loose = true
      }
      for _ in 0..<blank_count {
        item_payload.append("")
      }
      i = collect_list_continuation_into(
        item_payload,
        ctx.lines,
        i,
        false,
        content_indent,
      )
      item_end = i
    } else if blank_count > 0 &&
      i < ctx.lines.length() &&
      same_list_marker_line(
        ctx.lines[i],
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
        item_payload.is_not_empty() &&
        is_list_continuation_after_blank(ctx.lines[i], content_indent) {
        if is_loose_list_blank_continuation(
            ctx.lines[i],
            content_indent,
            item_payload,
          ) {
          loose = true
        }
        for _ in 0..<more_blanks {
          item_payload.append("")
        }
        i = collect_list_continuation_into(
          item_payload,
          ctx.lines,
          i,
          false,
          content_indent,
        )
        item_end = i
      } else if more_blanks > 0 &&
        i < ctx.lines.length() &&
        same_list_marker_line(
          ctx.lines[i],
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
    let item_source = {
      payload: item_payload,
      source_start: item_start,
      source_end: item_end,
    }
    if ctx.collect_only {
      if item_source.payload.may_contain_reference {
        collect_list_item_references(item_source, ctx.registry, ctx.state)
      }
    } else {
      item_sources.push(item_source)
    }
  }
  if ctx.collect_only {
    return block_match(i - ctx.index, EventFragment::empty())
  }
  let buffer = Events()
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
  for item_source in item_sources {
    sink.emit(
      Enter(
        Element::with_attrs(
          tag_name("cm:item"),
          [],
          range=Some(
            block_source_range(
              ctx,
              item_source.source_start,
              item_source.source_end,
            ),
          ),
        ),
      ),
    )
    emit_list_item_content(
      item_source,
      ctx.registry,
      ctx.inline_rules,
      ctx.inline_mode,
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
priv struct ListItemSource {
  payload : BlockPayload
  source_start : Int
  source_end : Int
}

///|
fn collect_list_item_references(
  item_source : ListItemSource,
  registry : RuleRegistry,
  state : ParseState,
) -> Unit {
  item_source.payload.collect_references(registry, state)
}

///|
fn is_list_marker_item_content(text : String) -> Bool {
  let trimmed = trim(text)
  is_ordered_list_marker(trimmed) || is_unordered_list_marker(trimmed)
}

///|
fn emit_list_item_content(
  item_source : ListItemSource,
  registry : RuleRegistry,
  inline_rules : Array[RuleEntry],
  inline_mode : InlineParseMode,
  sink : Sink,
  state : ParseState,
  loose? : Bool = false,
) -> Unit {
  if item_source.payload.may_contain_reference &&
    item_source.payload.length == 1 {
    if parse_reference_definition(trim(item_source.payload.first))
      is Some(definition) {
      state.add_reference(definition)
      return
    }
  }
  let single_line = item_source.payload.length == 1
  let item_line = if single_line { item_source.payload.first } else { "" }
  if !loose &&
    single_line &&
    item_line != "" &&
    count_leading_spaces(item_line) < 4 &&
    !is_list_marker_item_content(item_line) &&
    !is_paragraph_interrupt(item_line) {
    parse_inlines_with_rules(
      item_line, registry, inline_rules, inline_mode, sink, state,
    )
    return
  }
  let buffer = Events()
  item_source.payload.parse_into(registry, buffer.owned_sink(), state)
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
fn collect_list_continuation_into(
  payload : BlockPayload,
  lines : Array[String],
  start : Int,
  allow_lazy : Bool,
  content_indent : Int,
) -> Int {
  let mut i = start
  while i < lines.length() &&
        !is_blank(lines[i]) &&
        !is_list_sibling_marker(lines[i], content_indent) {
    let leading = count_leading_spaces(lines[i])
    if leading >= content_indent {
      payload.append(lines[i][content_indent:].to_owned())
      i = i + 1
    } else if leading >= 2 &&
      !is_ordered_list_marker(trim(lines[i])) &&
      !is_unordered_list_marker(trim(lines[i])) {
      payload.append(lines[i][2:].to_owned())
      i = i + 1
    } else if allow_lazy && !is_paragraph_interrupt(lines[i]) {
      payload.append(list_lazy_continuation_line(lines[i]))
      i = i + 1
    } else {
      break
    }
  }
  i
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
  let spaces = for spaces in 0..<5 {
    let i = marker_width + spaces
    if i >= current.length() || char_at(current, i) != ' ' {
      break spaces
    }
  } nobreak {
    5
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
  payload : BlockPayload,
) -> Bool {
  let leading = count_leading_spaces(line)
  !has_open_fenced_code_payload(payload) &&
  (
    leading == content_indent ||
    (leading >= content_indent + 4 && !has_nested_list_marker_payload(payload))
  )
}

///|
fn has_open_fenced_code_payload(payload : BlockPayload) -> Bool {
  let mut fence = ""
  if payload.length == 1 {
    return fence_marker(trim(payload.first)) != ""
  }
  let source = payload.source()
  for line in source.lines {
    if fence == "" {
      let marker = fence_marker(trim(line))
      if marker != "" {
        fence = marker
      }
    } else if is_closing_fence_line(line, fence) {
      fence = ""
    }
  }
  fence != ""
}

///|
fn has_nested_list_marker_payload(payload : BlockPayload) -> Bool {
  if payload.length == 1 {
    let trimmed = trim(payload.first)
    return is_ordered_list_marker(trimmed) || is_unordered_list_marker(trimmed)
  }
  let source = payload.source()
  for line in source.lines {
    let trimmed = trim(line)
    if is_ordered_list_marker(trimmed) || is_unordered_list_marker(trimmed) {
      return true
    }
  }
  false
}

///|
fn same_list_marker_line(
  line : String,
  ordered : Bool,
  ordered_delimiter : Int,
  unordered_delimiter : Int,
) -> Bool {
  let leading = count_leading_spaces(line)
  guard leading <= 3 else { false }
  same_list_marker_line_at(
    line, leading, ordered, ordered_delimiter, unordered_delimiter,
  )
}

///|
fn same_list_marker_line_at(
  line : String,
  leading : Int,
  ordered : Bool,
  ordered_delimiter : Int,
  unordered_delimiter : Int,
) -> Bool {
  if ordered {
    let marker = ordered_marker_end_at(line, leading)
    is_ordered_list_marker_at(line, leading, marker) &&
    char_at(line, marker) == ordered_delimiter
  } else {
    is_unordered_list_marker_at(line, leading) &&
    char_at(line, leading) == unordered_delimiter
  }
}

///|
fn strip_list_marker_line_at(
  line : String,
  leading : Int,
  ordered : Bool,
) -> String {
  if ordered {
    strip_ordered_marker_at(line, leading)
  } else {
    strip_unordered_marker_at(line, leading)
  }
}

///|
fn is_single_paragraph_events(events : Array[Event]) -> Bool {
  guard events[0] is Enter(el) else { false }
  guard el.tag.value == "cm:paragraph" else { false }
  guard events[events.length() - 1] is Exit(tag) else { false }
  guard tag.value == "cm:paragraph" else { false }
  let mut depth = 0
  for i in 0..<events.length() {
    match events[i] {
      Enter(_) => depth = depth + 1
      Exit(_) => {
        depth = depth - 1
        if depth == 0 && i < events.length() - 1 {
          break false
        }
      }
      _ => ()
    }
  } nobreak {
    depth == 0
  }
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
    char_at(line, start) == '-' ||
    char_at(line, start) == '*' ||
    char_at(line, start) == '+'
  ) &&
  (start + 1 >= line.length() || is_space(char_at(line, start + 1)))
}

///|
fn strip_unordered_marker_at(line : String, start : Int) -> String {
  if start + 1 >= line.length() {
    ""
  } else if char_at(line, start + 1) == '\t' {
    expand_tabs_from_column(line[start + 2:].to_owned(), 4, 2)
  } else {
    line[start + 2:].to_owned()
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
  (char_at(line, marker) == '.' || char_at(line, marker) == ')') &&
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
    value = value * 10 + char_at(line, i) - '0'
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
fn strip_ordered_marker_at(line : String, start : Int) -> String {
  let marker = ordered_marker_end_at(line, start)
  if marker + 2 > line.length() {
    ""
  } else if marker + 1 < line.length() && char_at(line, marker + 1) == '\t' {
    let marker_width = marker - start
    expand_tabs_from_column(
      line[marker + 2:].to_owned(),
      ((marker_width + 1) / 4 + 1) * 4,
      ((marker_width + 1) / 4 + 1) * 4 - marker_width - 2,
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
  let length = for i in start..<line.length() {
    let c = char_at(line, i)
    if c < '0' || c > '9' {
      break i - start
    }
  } nobreak {
    line.length() - start
  }
  if length == 0 || length > 9 {
    -1
  } else {
    start + length
  }
}

///|
fn has_nonblank_after_marker(line : String, start : Int) -> Bool {
  guard start <= line.length() else { false }
  for i in start..<line.length() {
    if !is_space(char_at(line, i)) {
      break true
    }
  } nobreak {
    false
  }
}
