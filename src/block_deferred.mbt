///|
priv enum DeferredBlockItem {
  DeferredEvent(Event)
  DeferredFragment(EventFragment)
  DeferredInline(String)
}

///|
fn parse_commonmark_deferred_blocks_into(
  lines : Array[String],
  line_starts : Array[Int],
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Unit {
  let items : Array[DeferredBlockItem] = []
  parse_commonmark_deferred_range_into(
    lines,
    line_starts,
    0,
    lines.length(),
    registry,
    items,
    state,
  )
  let inline_rules = registry.inline_parse_rules()
  let inline_mode = inline_parse_mode(inline_rules)
  replay_deferred_block_items(
    items, registry, inline_rules, inline_mode, sink, state,
  )
}

///|
fn parse_commonmark_deferred_range_into(
  lines : Array[String],
  line_starts : Array[Int],
  start : Int,
  end : Int,
  registry : RuleRegistry,
  items : Array[DeferredBlockItem],
  state : ParseState,
) -> Unit {
  let mut i = start
  let stop = if end > lines.length() { lines.length() } else { end }
  while i < stop {
    let ctx = deferred_block_context(lines, line_starts, i, registry, state)
    let mut consumed = 0
    match cm_blank_block(ctx) {
      Match(lines, fragment) => {
        append_deferred_fragment(items, fragment)
        consumed = lines.to_int()
      }
      NoMatch => ()
    }
    if consumed == 0 {
      match cm_fenced_code_block(ctx) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match cm_indented_code_block(ctx) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match cm_thematic_break_block(ctx) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match deferred_setext_heading_block(ctx, items) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match cm_html_block(ctx) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match deferred_atx_heading_block(ctx, items) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match deferred_blockquote_block(ctx, items) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match deferred_list_block(ctx, items) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match cm_reference_definition_block(ctx) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => ()
      }
    }
    if consumed == 0 {
      match deferred_paragraph_block(ctx, items) {
        Match(lines, fragment) => {
          append_deferred_fragment(items, fragment)
          consumed = lines.to_int()
        }
        NoMatch => consumed = 1
      }
    }
    i = i + consumed
  }
}

///|
fn deferred_block_context(
  lines : Array[String],
  line_starts : Array[Int],
  index : Int,
  registry : RuleRegistry,
  state : ParseState,
) -> BlockContext {
  {
    lines,
    line_starts,
    index,
    registry,
    inline_rules: [],
    inline_mode: CustomInlinePipeline,
    state,
    collect_only: false,
  }
}

///|
fn deferred_block_sink(items : Array[DeferredBlockItem]) -> Sink {
  Sink(fn(event) { append_deferred_event(items, event) })
}

///|
fn emit_block_inline(
  items : Array[DeferredBlockItem],
  _ctx : BlockContext,
  _sink : Sink,
  text : String,
) -> Unit {
  append_deferred_inline(items, text)
}

///|
fn parse_payload_with_block_context(
  payload : BlockPayload,
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
) -> Unit {
  let source = payload.source()
  parse_commonmark_deferred_range_into(
    source.lines,
    source.line_starts,
    0,
    source.lines.length(),
    ctx.registry,
    items,
    ctx.state,
  )
}

///|
fn append_deferred_event(
  items : Array[DeferredBlockItem],
  event : Event,
) -> Unit {
  items.push(DeferredEvent(event))
}

///|
fn append_deferred_fragment(
  items : Array[DeferredBlockItem],
  fragment : EventFragment,
) -> Unit {
  if fragment.events.length() == 1 {
    items.push(DeferredEvent(fragment.events[0]))
  } else if fragment.events.length() != 0 {
    items.push(DeferredFragment(fragment))
  }
}

///|
fn append_deferred_inline(
  items : Array[DeferredBlockItem],
  text : String,
) -> Unit {
  if text != "" {
    items.push(DeferredInline(text))
  }
}

///|
fn append_deferred_items(
  target : Array[DeferredBlockItem],
  source : Array[DeferredBlockItem],
) -> Unit {
  for item in source {
    target.push(item)
  }
}

///|
fn replay_deferred_block_items(
  items : Array[DeferredBlockItem],
  registry : RuleRegistry,
  inline_rules : Array[RuleEntry],
  inline_mode : InlineParseMode,
  sink : Sink,
  state : ParseState,
) -> Unit {
  for item in items {
    match item {
      DeferredEvent(event) => sink.emit(event)
      DeferredFragment(fragment) => emit_deferred_fragment(fragment, sink)
      DeferredInline(text) =>
        parse_inlines_with_rules(
          text, registry, inline_rules, inline_mode, sink, state,
        )
    }
  }
}

///|
fn emit_deferred_fragment(fragment : EventFragment, sink : Sink) -> Unit {
  for event in fragment.events {
    sink.emit(event)
  }
}

///|
fn deferred_paragraph_block(
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
) -> BlockRuleResult {
  let mut i = ctx.index
  while i < ctx.lines.length() &&
        !is_blank(ctx.lines[i]) &&
        (i == ctx.index || !is_paragraph_interrupt(ctx.lines[i])) {
    i = i + 1
  }
  if i == ctx.index {
    block_match(1, EventFragment::empty())
  } else {
    let sink = deferred_block_sink(items)
    sink.emit(
      Enter(
        Element::with_attrs(
          tag_name("cm:paragraph"),
          [],
          range=Some(block_source_range(ctx, ctx.index, i)),
        ),
      ),
    )
    let inline_text = if i == ctx.index + 1 {
      strip_trailing_spaces(paragraph_line(ctx.lines[ctx.index]))
    } else {
      paragraph_text(ctx, i)
    }
    emit_block_inline(items, ctx, sink, inline_text)
    sink.emit(Exit(tag_name("cm:paragraph")))
    block_match(i - ctx.index, EventFragment::empty())
  }
}

///|
fn deferred_atx_heading_block(
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
) -> BlockRuleResult {
  guard count_leading_spaces(ctx.lines[ctx.index]) <= 3 else { NoMatch }
  let line = trim(ctx.lines[ctx.index])
  let mut level = 0
  while level < line.length() && level < 6 && char_at(line, level) == '#' {
    level = level + 1
  }
  guard level > 0 else { NoMatch }
  guard level >= line.length() || is_space(char_at(line, level)) else {
    NoMatch
  }
  let content = if level >= line.length() {
    ""
  } else {
    trim(strip_closing_hashes(line[level:].to_owned()))
  }
  let sink = deferred_block_sink(items)
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:heading"),
        [{ name: attr_name("level"), value: heading_level_value(level) }],
        range=Some(block_source_range(ctx, ctx.index, ctx.index + 1)),
      ),
    ),
  )
  emit_block_inline(items, ctx, sink, content)
  sink.emit(Exit(tag_name("cm:heading")))
  block_match(1, EventFragment::empty())
}

///|
fn deferred_setext_heading_block(
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
) -> BlockRuleResult {
  guard is_setext_heading_paragraph_start(ctx.lines[ctx.index]) else { NoMatch }
  let underline_index = find_setext_underline(ctx)
  guard underline_index >= 0 else { NoMatch }
  let level = setext_heading_level_line(ctx.lines[underline_index])
  let sink = deferred_block_sink(items)
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:heading"),
        [{ name: attr_name("level"), value: heading_level_value(level) }],
        range=Some(block_source_range(ctx, ctx.index, underline_index + 1)),
      ),
    ),
  )
  emit_block_inline(
    items,
    ctx,
    sink,
    setext_heading_content(ctx, underline_index),
  )
  sink.emit(Exit(tag_name("cm:heading")))
  block_match(underline_index - ctx.index + 1, EventFragment::empty())
}

///|
fn deferred_blockquote_block(
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
) -> BlockRuleResult {
  guard is_blockquote_marker_line(ctx.lines[ctx.index]) else { NoMatch }
  let mut i = ctx.index
  let mut used_lazy = false
  let first = strip_blockquote_marker(ctx.lines[i])
  if is_single_line_blockquote(ctx, first, i + 1) {
    return deferred_single_line_blockquote(ctx, items, first)
  }
  let inner = BlockPayload(first)
  i = i + 1
  let result = append_blockquote_lazy_lines(ctx, inner, first, i)
  i = result.next_index
  if result.used_lazy {
    used_lazy = true
  }
  while i < ctx.lines.length() && is_blockquote_marker_line(ctx.lines[i]) {
    let stripped = strip_blockquote_marker(ctx.lines[i])
    inner.append(stripped)
    i = i + 1
    let result = append_blockquote_lazy_lines(ctx, inner, stripped, i)
    i = result.next_index
    if result.used_lazy {
      used_lazy = true
    }
  }
  let sink = deferred_block_sink(items)
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:block_quote"),
        [],
        range=Some(block_source_range(ctx, ctx.index, i)),
      ),
    ),
  )
  let lazy_starts_with_block = used_lazy &&
    blockquote_inner_starts_with_block(inner)
  let inner_text = if inner.may_contain_reference ||
    (used_lazy && !lazy_starts_with_block) {
    inner.to_text()
  } else {
    ""
  }
  match parse_reference_definition(trim(inner_text)) {
    Some(definition) => ctx.state.add_reference(definition)
    None =>
      if lazy_starts_with_block {
        parse_payload_with_block_context(inner, ctx, items)
      } else if used_lazy {
        sink.emit(Enter(Element(tag_name("cm:paragraph"))))
        emit_block_inline(items, ctx, sink, inner_text)
        sink.emit(Exit(tag_name("cm:paragraph")))
      } else if inner.length == 1 &&
        inner.first != "" &&
        count_leading_spaces(inner.first) < 4 &&
        !is_paragraph_interrupt(inner.first) {
        sink.emit(Enter(Element(tag_name("cm:paragraph"))))
        emit_block_inline(items, ctx, sink, paragraph_line(inner.first))
        sink.emit(Exit(tag_name("cm:paragraph")))
      } else {
        parse_payload_with_block_context(inner, ctx, items)
      }
  }
  sink.emit(Exit(tag_name("cm:block_quote")))
  block_match(i - ctx.index, EventFragment::empty())
}

///|
fn deferred_single_line_blockquote(
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
  inner : String,
) -> BlockRuleResult {
  let sink = deferred_block_sink(items)
  sink.emit(
    Enter(
      Element::with_attrs(
        tag_name("cm:block_quote"),
        [],
        range=Some(block_source_range(ctx, ctx.index, ctx.index + 1)),
      ),
    ),
  )
  if may_contain_reference_definition(inner) {
    match parse_reference_definition(trim(inner)) {
      Some(definition) => ctx.state.add_reference(definition)
      None => deferred_single_line_blockquote_content(ctx, items, inner, sink)
    }
  } else {
    deferred_single_line_blockquote_content(ctx, items, inner, sink)
  }
  sink.emit(Exit(tag_name("cm:block_quote")))
  block_match(1, EventFragment::empty())
}

///|
fn deferred_single_line_blockquote_content(
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
  inner : String,
  sink : Sink,
) -> Unit {
  if inner != "" &&
    count_leading_spaces(inner) < 4 &&
    !is_paragraph_interrupt(inner) {
    sink.emit(Enter(Element(tag_name("cm:paragraph"))))
    emit_block_inline(items, ctx, sink, paragraph_line(inner))
    sink.emit(Exit(tag_name("cm:paragraph")))
  } else {
    parse_payload_with_block_context(BlockPayload(inner), ctx, items)
  }
}

///|
fn deferred_list_block(
  ctx : BlockContext,
  items : Array[DeferredBlockItem],
) -> BlockRuleResult {
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
    item_sources.push({
      payload: item_payload,
      source_start: item_start,
      source_end: item_end,
    })
  }
  let sink = deferred_block_sink(items)
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
    emit_deferred_list_item_content(
      item_source,
      ctx.registry,
      items,
      ctx.state,
      loose~,
    )
    sink.emit(Exit(tag_name("cm:item")))
  }
  sink.emit(Exit(tag_name("cm:list")))
  block_match(i - ctx.index, EventFragment::empty())
}

///|
fn emit_deferred_list_item_content(
  item_source : ListItemSource,
  registry : RuleRegistry,
  items : Array[DeferredBlockItem],
  state : ParseState,
  loose? : Bool = false,
) -> Unit {
  if item_source.payload.may_contain_reference &&
    item_source.payload.length == 1 {
    match parse_reference_definition(trim(item_source.payload.first)) {
      Some(definition) => {
        state.add_reference(definition)
        return
      }
      None => ()
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
    append_deferred_inline(items, item_line)
    return
  }
  let child_items : Array[DeferredBlockItem] = []
  let source = item_source.payload.source()
  parse_commonmark_deferred_range_into(
    source.lines,
    source.line_starts,
    0,
    source.lines.length(),
    registry,
    child_items,
    state,
  )
  if !loose && deferred_is_single_paragraph_items(child_items) {
    for i in 1..<(child_items.length() - 1) {
      items.push(child_items[i])
    }
  } else if !loose {
    emit_deferred_without_paragraph_wrappers(child_items, items)
  } else {
    append_deferred_items(items, child_items)
  }
}

///|
fn deferred_is_single_paragraph_items(items : Array[DeferredBlockItem]) -> Bool {
  if items.length() < 2 {
    return false
  }
  match items[0] {
    DeferredEvent(Enter(el)) =>
      if el.tag.value != "cm:paragraph" {
        return false
      }
    _ => return false
  }
  match items[items.length() - 1] {
    DeferredEvent(Exit(tag)) => if tag.value != "cm:paragraph" { return false }
    _ => return false
  }
  let mut depth = 0
  for i in 0..<items.length() {
    match items[i] {
      DeferredEvent(Enter(_)) => depth = depth + 1
      DeferredEvent(Exit(_)) => {
        depth = depth - 1
        if depth == 0 && i < items.length() - 1 {
          return false
        }
      }
      _ => ()
    }
  }
  depth == 0
}

///|
fn emit_deferred_without_paragraph_wrappers(
  source : Array[DeferredBlockItem],
  sink : Array[DeferredBlockItem],
) -> Unit {
  let mut depth = 0
  let mut previous_text = false
  for item in source {
    match item {
      DeferredEvent(Enter(el)) =>
        if el.tag.value == "cm:paragraph" && depth == 0 {
          ()
        } else {
          if depth == 0 && previous_text && is_tight_list_block_child(el.tag) {
            append_deferred_event(sink, SoftBreak)
          }
          sink.push(item)
          depth = depth + 1
          previous_text = false
        }
      DeferredEvent(Exit(tag)) =>
        if tag.value == "cm:paragraph" && depth == 0 {
          ()
        } else {
          sink.push(item)
          depth = depth - 1
          previous_text = false
        }
      DeferredEvent(Text(_)) => {
        sink.push(item)
        previous_text = depth == 0
      }
      DeferredInline(_) => {
        sink.push(item)
        previous_text = depth == 0
      }
      _ => {
        sink.push(item)
        previous_text = false
      }
    }
  }
}
