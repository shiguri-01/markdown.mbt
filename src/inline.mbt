///|
fn parse_inlines(
  text : String,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Unit {
  parse_inlines_with_rules(
    text,
    registry,
    registry.inline_parse_rules(),
    sink,
    state,
  )
}

///|
fn parse_inlines_with_rules(
  text : String,
  registry : RuleRegistry,
  rules : Array[RuleEntry],
  sink : Sink,
  state : ParseState,
) -> Unit {
  if registry.has_commonmark_inline_pipeline() {
    parse_commonmark_inline_range(
      text,
      0,
      text.length(),
      registry,
      sink,
      state,
      true,
    )
    return
  }
  if rules.length() == 0 {
    if text.length() > 0 {
      sink.emit(Text(text))
    }
    return
  }
  let mut i = 0
  while i < text.length() {
    let mut consumed = 0
    let ctx = {
      text,
      index: i,
      scanner: inline_scanner(text, i),
      registry,
      state,
    }
    for rule in rules {
      match rule.inline {
        Some(f) =>
          if consumed == 0 {
            match f(ctx) {
              Match(chars, fragment) => {
                emit_fragment(sink, fragment)
                consumed = chars.to_int()
              }
              NoMatch => ()
            }
          }
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
fn parse_commonmark_inline_range(
  text : String,
  start : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Unit {
  let mut i = start
  let mut text_start = start
  while i < end {
    let consumed = if is_inline_special(text, i) {
      if text_start < i {
        sink.emit(Text(text[text_start:i].to_owned()))
        text_start = i
      }
      commonmark_inline_span(text, i, end, registry, sink, state, allow_links)
    } else {
      0
    }
    if consumed > 0 {
      i = i + consumed
      text_start = i
    } else {
      i = i + 1
    }
  }
  if text_start < end {
    sink.emit(Text(text[text_start:end].to_owned()))
  }
}

///|
fn commonmark_inline_span(
  text : String,
  start : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Int {
  let c = char_at(text, start)
  if c == 96 {
    return emit_commonmark_code_span(text, start, end, sink)
  }
  if c == 60 {
    let raw_or_auto = emit_commonmark_angle_span(text, start, end, sink)
    if raw_or_auto > 0 {
      return raw_or_auto
    }
  }
  if c == 33 && start + 1 < end && char_at(text, start + 1) == 91 {
    let image = emit_commonmark_image(text, start, end, registry, sink, state)
    if image > 0 {
      return image
    }
  }
  if allow_links && c == 91 {
    let link = emit_commonmark_link(text, start, end, registry, sink, state)
    if link > 0 {
      return link
    }
  }
  if c == 42 || c == 95 {
    let emphasis = emit_commonmark_emphasis(
      text, start, end, registry, sink, state, allow_links,
    )
    if emphasis > 0 {
      return emphasis
    }
  }
  if c == 92 && start + 1 < end && char_at(text, start + 1) == 10 {
    sink.emit(HardBreak)
    return 2
  }
  if c == 92 &&
    start + 1 < end &&
    is_ascii_punctuation(char_at(text, start + 1)) {
    sink.emit(Text(text[start + 1:start + 2].to_owned()))
    return 2
  }
  if c == 32 {
    let mut space_end = start
    while space_end < end && char_at(text, space_end) == 32 {
      space_end = space_end + 1
    }
    if space_end < end && char_at(text, space_end) == 10 {
      if space_end - start >= 2 {
        sink.emit(HardBreak)
        return space_end - start + 1
      }
      return space_end - start
    }
  }
  if c == 10 {
    sink.emit(SoftBreak)
    return 1
  }
  if c == 38 {
    let entity = emit_commonmark_entity(text, start, end, sink)
    if entity > 0 {
      return entity
    }
  }
  0
}

///|
fn emit_commonmark_code_span(
  text : String,
  start : Int,
  end : Int,
  sink : Sink,
) -> Int {
  if start > 0 && char_at(text, start - 1) == 96 {
    return 0
  }
  let width = delimiter_run_len(text, start, 96)
  let close = find_code_span_end_before(text, start + width, width, end)
  if close < 0 {
    return 0
  }
  sink.emit(Enter(Element::new(tag_name("cm:code_span"))))
  sink.emit(Text(normalize_code_span(text[start + width:close].to_owned())))
  sink.emit(Exit(tag_name("cm:code_span")))
  close - start + width
}

///|
fn find_code_span_end_before(
  text : String,
  start : Int,
  width : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i < end {
    if char_at(text, i) == 96 {
      let run = delimiter_run_len(text, i, 96)
      if run == width && i + width <= end {
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
fn emit_commonmark_angle_span(
  text : String,
  start : Int,
  end : Int,
  sink : Sink,
) -> Int {
  match raw_html_inline_end(text, start) {
    Some(close) =>
      if close <= end {
        sink.emit(Html(text[start:close].to_owned()))
        return close - start
      }
    None => ()
  }
  match raw_html_tag_end(text, start) {
    Some(close) =>
      if close <= end {
        let raw = text[start:close].to_owned()
        if looks_like_raw_html(raw) {
          sink.emit(Html(raw))
          return close - start
        }
      }
    None => ()
  }
  let close = find_char(text, 62, start + 1)
  if close < 0 || close >= end {
    return 0
  }
  let destination = text[start + 1:close].to_owned()
  let href = if is_uri_autolink(destination) {
    percent_encode_autolink_uri(destination)
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
  close - start + 1
}

///|
fn emit_commonmark_entity(
  text : String,
  start : Int,
  end : Int,
  sink : Sink,
) -> Int {
  let close = find_char(text, 59, start + 1)
  if close < 0 || close >= end || close - start > 32 {
    return 0
  }
  let name = text[start + 1:close].to_owned()
  match decode_entity(name) {
    Some(decoded) => {
      sink.emit(Text(decoded))
      close - start + 1
    }
    None => 0
  }
}

///|
fn emit_commonmark_link(
  text : String,
  start : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Int {
  let close_text = find_link_text_end(text, start + 1)
  if close_text < 0 || close_text >= end {
    return 0
  }
  if link_text_may_contain_link(text[start + 1:close_text].to_owned()) ||
    link_text_has_unclosed_priority_span(text, start + 1, close_text) {
    return 0
  }
  if close_text + 1 < end && char_at(text, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_text + 2)
    if close_dest > close_text && close_dest < end {
      let attrs = parse_link_attrs(text[close_text + 2:close_dest].to_owned())
      if attrs.length() > 0 {
        emit_link_element(
          text,
          start + 1,
          close_text,
          attrs,
          registry,
          sink,
          state,
        )
        return close_dest - start + 1
      }
    }
  }
  match reference_attrs_for_link_text(text, start, close_text, state) {
    Some(resolved) =>
      if resolved.end <= end {
        emit_link_element(
          text,
          start + 1,
          close_text,
          resolved.attrs,
          registry,
          sink,
          state,
        )
        resolved.end - start
      } else {
        0
      }
    None => 0
  }
}

///|
fn emit_link_element(
  text : String,
  start : Int,
  end : Int,
  attrs : Array[Attr],
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Unit {
  sink.emit(Enter(Element::with_attrs(tag_name("cm:link"), attrs)))
  parse_commonmark_inline_range(text, start, end, registry, sink, state, false)
  sink.emit(Exit(tag_name("cm:link")))
}

///|
fn emit_commonmark_image(
  text : String,
  start : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
) -> Int {
  let close_alt = find_link_text_end(text, start + 2)
  if close_alt < 0 || close_alt >= end {
    return 0
  }
  let alt = image_alt_text(
    text[start + 2:close_alt].to_owned(),
    registry,
    state,
  )
  if close_alt + 1 < end && char_at(text, close_alt + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_alt + 2)
    if close_dest > close_alt && close_dest < end {
      let attrs = parse_link_attrs(text[close_alt + 2:close_dest].to_owned())
      if attrs.length() > 0 {
        attrs.push({ name: attr_name("alt"), value: alt })
        sink.emit(Enter(Element::with_attrs(tag_name("cm:image"), attrs)))
        sink.emit(Exit(tag_name("cm:image")))
        return close_dest - start + 1
      }
    }
  }
  match reference_attrs_for_image_alt(text, start, close_alt, alt, state) {
    Some(resolved) =>
      if resolved.end <= end {
        sink.emit(
          Enter(Element::with_attrs(tag_name("cm:image"), resolved.attrs)),
        )
        sink.emit(Exit(tag_name("cm:image")))
        resolved.end - start
      } else {
        0
      }
    None => 0
  }
}

///|
fn emit_commonmark_emphasis(
  text : String,
  start : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Int {
  let marker = char_at(text, start)
  if start > 0 && char_at(text, start - 1) == marker {
    return 0
  }
  let run = delimiter_run_len(text, start, marker)
  if run > 12 || !delimiter_can_open(text, start, run, marker) {
    return 0
  }
  if run >= 4 {
    let consumed = emit_commonmark_long_emphasis_run(
      text, start, run, marker, end, registry, sink, state, allow_links,
    )
    if consumed > 0 {
      return consumed
    }
  }
  let width = if run >= 3 { 3 } else if run >= 2 { 2 } else { 1 }
  let mut close = find_commonmark_emphasis_close(
    text,
    marker,
    start + width,
    width,
    end,
  )
  if close < 0 {
    let split = emit_commonmark_split_opening_run(
      text, start, run, marker, end, registry, sink, state, allow_links,
    )
    if split > 0 {
      return split
    }
    return emit_commonmark_partial_emphasis(
      text, start, run, marker, end, registry, sink, state, allow_links,
    )
  }
  let close_run = delimiter_run_len(text, close, marker)
  if close_run > width &&
    inner_opener_of_width_between(
      text,
      marker,
      start + width,
      close,
      close_run - width,
    ) {
    emit_commonmark_emphasis_element(
      text,
      start + width,
      close + close_run - width,
      width,
      registry,
      sink,
      state,
      allow_links,
    )
    return close - start + close_run
  }
  if exact_inner_opener_can_use_close(text, marker, start + width, close, width) {
    if close_run > width {
      emit_commonmark_emphasis_element(
        text,
        start + width,
        close + close_run - width,
        width,
        registry,
        sink,
        state,
        allow_links,
      )
      return close - start + close_run
    }
    let next = find_commonmark_emphasis_close(
      text,
      marker,
      close + delimiter_run_len(text, close, marker),
      width,
      end,
    )
    if next < 0 {
      return 0
    }
    close = next
  }
  if width == 1 && emphasis_would_split_link_text(text, start, close) {
    return 0
  }
  emit_commonmark_emphasis_element(
    text,
    start + width,
    close,
    width,
    registry,
    sink,
    state,
    allow_links,
  )
  close - start + width
}

///|
fn inner_opener_of_width_between(
  text : String,
  marker : Int,
  start : Int,
  close : Int,
  width : Int,
) -> Bool {
  let mut i = start
  while i < close {
    match priority_inline_span_end(text, i, close) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    match other_emphasis_span_end_for_inner_scan(text, marker, i, close) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run == width &&
      !is_escaped_char(text, i) &&
      delimiter_can_open(text, i, run, marker) {
      return true
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  false
}

///|
fn emit_commonmark_emphasis_element(
  text : String,
  start : Int,
  end : Int,
  width : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Unit {
  let tag = if width >= 2 {
    tag_name("cm:strong")
  } else {
    tag_name("cm:emphasis")
  }
  if width == 3 {
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
  }
  sink.emit(Enter(Element::new(tag)))
  parse_commonmark_inline_range(
    text, start, end, registry, sink, state, allow_links,
  )
  sink.emit(Exit(tag))
  if width == 3 {
    sink.emit(Exit(tag_name("cm:emphasis")))
  }
}

///|
fn emit_commonmark_split_opening_run(
  text : String,
  start : Int,
  run : Int,
  marker : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Int {
  let width = if run == 2 {
    1
  } else if run == 3 {
    return emit_commonmark_split_three_opening_run(
      text, start, marker, end, registry, sink, state, allow_links,
    )
  } else if run == 4 {
    2
  } else {
    return 0
  }
  let inner_close = find_commonmark_emphasis_close(
    text,
    marker,
    start + run,
    width,
    end,
  )
  if inner_close < 0 {
    return 0
  }
  let outer_close = find_commonmark_emphasis_close(
    text,
    marker,
    inner_close + width,
    width,
    end,
  )
  if outer_close < 0 {
    return 0
  }
  let tag = if width >= 2 {
    tag_name("cm:strong")
  } else {
    tag_name("cm:emphasis")
  }
  sink.emit(Enter(Element::new(tag)))
  let content = text[start + width:outer_close].to_owned()
  parse_commonmark_inline_range(
    content,
    0,
    content.length(),
    registry,
    sink,
    state,
    allow_links,
  )
  sink.emit(Exit(tag))
  outer_close - start + width
}

///|
fn emit_commonmark_split_three_opening_run(
  text : String,
  start : Int,
  marker : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Int {
  let outer_em = emit_commonmark_split_mixed_opening_run(
    text,
    start,
    marker,
    end,
    outer_width=1,
    inner_width=2,
    registry,
    sink,
    state,
    allow_links,
  )
  if outer_em > 0 {
    return outer_em
  }
  emit_commonmark_split_mixed_opening_run(
    text,
    start,
    marker,
    end,
    outer_width=2,
    inner_width=1,
    registry,
    sink,
    state,
    allow_links,
  )
}

///|
fn emit_commonmark_split_mixed_opening_run(
  text : String,
  start : Int,
  marker : Int,
  end : Int,
  outer_width~ : Int,
  inner_width~ : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Int {
  let inner_close = find_commonmark_emphasis_close(
    text,
    marker,
    start + 3,
    inner_width,
    end,
  )
  if inner_close < 0 {
    return 0
  }
  let outer_close = find_commonmark_emphasis_close(
    text,
    marker,
    inner_close + inner_width,
    outer_width,
    end,
  )
  if outer_close < 0 {
    return 0
  }
  let tag = if outer_width >= 2 {
    tag_name("cm:strong")
  } else {
    tag_name("cm:emphasis")
  }
  sink.emit(Enter(Element::new(tag)))
  let content = text[start + outer_width:outer_close].to_owned()
  parse_commonmark_inline_range(
    content,
    0,
    content.length(),
    registry,
    sink,
    state,
    allow_links,
  )
  sink.emit(Exit(tag))
  outer_close - start + outer_width
}

///|
fn exact_inner_opener_can_use_close(
  text : String,
  marker : Int,
  start : Int,
  close : Int,
  width : Int,
) -> Bool {
  let mut i = start
  while i < close {
    match priority_inline_span_end(text, i, close) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    match other_emphasis_span_end_for_inner_scan(text, marker, i, close) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run == width &&
      !is_escaped_char(text, i) &&
      delimiter_can_open(text, i, run, marker) {
      return true
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  false
}

///|
fn other_emphasis_span_end_for_inner_scan(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Int? {
  let other = char_at(text, start)
  if (other != 42 && other != 95) || other == marker {
    return None
  }
  let run = delimiter_run_len(text, start, other)
  if run > 3 || !delimiter_can_open(text, start, run, other) {
    return None
  }
  let width = if run >= 2 { 2 } else { 1 }
  let close = find_commonmark_emphasis_close(
    text,
    other,
    start + width,
    width,
    end,
  )
  if close >= 0 {
    Some(close + width)
  } else {
    None
  }
}

///|
fn emit_commonmark_long_emphasis_run(
  text : String,
  start : Int,
  run : Int,
  marker : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Int {
  let close = find_commonmark_exact_run_close(
    text,
    marker,
    start + run,
    run,
    end,
  )
  if close < 0 {
    return 0
  }
  let strong_count = run / 2
  if run % 2 == 1 {
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
  }
  for _ in 0..<strong_count {
    sink.emit(Enter(Element::new(tag_name("cm:strong"))))
  }
  parse_commonmark_inline_range(
    text,
    start + run,
    close,
    registry,
    sink,
    state,
    allow_links,
  )
  for _ in 0..<strong_count {
    sink.emit(Exit(tag_name("cm:strong")))
  }
  if run % 2 == 1 {
    sink.emit(Exit(tag_name("cm:emphasis")))
  }
  close - start + run
}

///|
fn find_commonmark_exact_run_close(
  text : String,
  marker : Int,
  start : Int,
  width : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i + width <= end {
    match priority_inline_span_end(text, i, end) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run >= width &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, width, marker) {
      return i
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  -1
}

///|
fn find_commonmark_emphasis_close(
  text : String,
  marker : Int,
  start : Int,
  width : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i + width <= end {
    match priority_inline_span_end(text, i, end) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run >= width &&
      (width != 1 || run == 1) &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, width, marker) {
      return i
    }
    if run > 0 {
      i = if is_escaped_char(text, i) { i + 1 } else { i + run }
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn emit_commonmark_partial_emphasis(
  text : String,
  start : Int,
  run : Int,
  marker : Int,
  end : Int,
  registry : RuleRegistry,
  sink : Sink,
  state : ParseState,
  allow_links : Bool,
) -> Int {
  if run >= 3 {
    let close = find_commonmark_emphasis_close(
      text,
      marker,
      start + run,
      2,
      end,
    )
    if close >= 0 {
      sink.emit(Text(text[start:start + run - 2].to_owned()))
      sink.emit(Enter(Element::new(tag_name("cm:strong"))))
      parse_commonmark_inline_range(
        text,
        start + run,
        close,
        registry,
        sink,
        state,
        allow_links,
      )
      sink.emit(Exit(tag_name("cm:strong")))
      return close - start + 2
    }
  }
  if run >= 2 {
    let close = find_commonmark_emphasis_close(
      text,
      marker,
      start + run,
      1,
      end,
    )
    if close >= 0 {
      sink.emit(Text(text[start:start + run - 1].to_owned()))
      sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
      parse_commonmark_inline_range(
        text,
        start + run,
        close,
        registry,
        sink,
        state,
        allow_links,
      )
      sink.emit(Exit(tag_name("cm:emphasis")))
      return close - start + 1
    }
  }
  if run == 1 {
    let close = find_commonmark_relaxed_single_close(
      text,
      marker,
      start + 1,
      end,
    )
    if close >= 0 {
      let close_run = delimiter_run_len(text, close, marker)
      if close_run > 1 &&
        !has_delimiter_run_between(text, marker, start + 1, close) &&
        delimiter_can_open(text, close, close_run, marker) {
        let later = find_later_compound_emphasis_close(
          text,
          marker,
          close + close_run,
          end,
        )
        if later >= 0 {
          let later_run = delimiter_run_len(text, later, marker)
          sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
          parse_commonmark_inline_range(
            text,
            start + 1,
            later + later_run - 1,
            registry,
            sink,
            state,
            allow_links,
          )
          sink.emit(Exit(tag_name("cm:emphasis")))
          return later - start + later_run
        }
      }
      if close_run > 1 &&
        has_delimiter_run_between(text, marker, start + 1, close) {
        sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
        parse_commonmark_inline_range(
          text,
          start + 1,
          close + close_run - 1,
          registry,
          sink,
          state,
          allow_links,
        )
        sink.emit(Exit(tag_name("cm:emphasis")))
        return close - start + close_run
      }
    }
    if close >= 0 && !has_delimiter_run_between(text, marker, start + 1, close) {
      sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
      parse_commonmark_inline_range(
        text,
        start + 1,
        close,
        registry,
        sink,
        state,
        allow_links,
      )
      sink.emit(Exit(tag_name("cm:emphasis")))
      return close - start + 1
    }
  }
  0
}

///|
fn find_later_compound_emphasis_close(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i < end {
    match priority_inline_span_end(text, i, end) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run > 1 &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, 1, marker) {
      return i
    }
    i = if run > 0 { i + run } else { i + 1 }
  }
  -1
}

///|
fn find_commonmark_relaxed_single_close(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Int {
  let mut i = start
  while i < end {
    match priority_inline_span_end(text, i, end) {
      Some(next) => {
        i = next
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run > 1 &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, 1, marker) {
      return i
    }
    if run > 0 {
      i = if is_escaped_char(text, i) { i + 1 } else { i + run }
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn has_delimiter_run_between(
  text : String,
  marker : Int,
  start : Int,
  end : Int,
) -> Bool {
  let mut i = start
  while i < end {
    if char_at(text, i) == marker && !is_escaped_char(text, i) {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn priority_inline_span_end(text : String, start : Int, end : Int) -> Int? {
  let c = char_at(text, start)
  if c == 96 {
    let width = delimiter_run_len(text, start, 96)
    let close = find_code_span_end_before(text, start + width, width, end)
    if close >= 0 {
      return Some(close + width)
    }
  } else if c == 60 {
    match raw_html_inline_end(text, start) {
      Some(close) => if close <= end { return Some(close) }
      None => ()
    }
    match raw_html_tag_end(text, start) {
      Some(close) => if close <= end { return Some(close) }
      None => ()
    }
    let close = find_char(text, 62, start + 1)
    if close >= 0 && close < end {
      let candidate = text[start + 1:close].to_owned()
      if is_uri_autolink(candidate) || is_email_autolink(candidate) {
        return Some(close + 1)
      }
    }
  }
  None
}

///|
fn cm_text_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let start = ctx.index
  if start >= text.length() || is_inline_special(text, start) {
    return NoMatch
  }
  let mut end = start
  while end < text.length() && !is_inline_special(text, end) {
    end = end + 1
  }
  let fragment = if start == 0 && end == text.length() {
    EventFragment::text(text)
  } else {
    EventFragment::text(text[start:end].to_owned())
  }
  inline_match(end - start, fragment)
}

///|
fn cm_escape_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) == 92 &&
    i + 1 < text.length() &&
    is_ascii_punctuation(char_at(text, i + 1)) {
    inline_match(2, EventFragment::text(text[i + 1:i + 2].to_owned()))
  } else {
    NoMatch
  }
}

///|
fn cm_hard_break_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if i + 1 < text.length() &&
    char_at(text, i) == 92 &&
    char_at(text, i + 1) == 10 {
    inline_match(2, EventFragment::hard_break())
  } else if char_at(text, i) == 32 {
    let mut end = i
    while end < text.length() && char_at(text, end) == 32 {
      end = end + 1
    }
    if end - i >= 2 && end < text.length() && char_at(text, end) == 10 {
      inline_match(end - i + 1, EventFragment::hard_break())
    } else if end < text.length() && char_at(text, end) == 10 {
      inline_match(end - i, EventFragment::empty())
    } else {
      NoMatch
    }
  } else {
    NoMatch
  }
}

///|
fn cm_soft_break_inline(ctx : InlineContext) -> InlineRuleResult {
  if char_at(ctx.text, ctx.index) == 10 {
    inline_match(1, EventFragment::soft_break())
  } else {
    NoMatch
  }
}

///|
fn cm_code_span_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 96 {
    return NoMatch
  }
  if i > 0 && char_at(text, i - 1) == 96 {
    return NoMatch
  }
  let width = delimiter_run_len(text, i, 96)
  let end = find_code_span_end(text, i + width, width)
  if end < 0 {
    return NoMatch
  }
  inline_match(
    end - i + width,
    EventFragment::element(Element::new(tag_name("cm:code_span")), children=[
      EventFragment::text(normalize_code_span(text[i + width:end].to_owned())),
    ]),
  )
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
fn cm_autolink_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 60 {
    return NoMatch
  }
  let end = find_char(text, 62, i + 1)
  if end < 0 {
    return NoMatch
  }
  let destination = text[i + 1:end].to_owned()
  let href = if is_uri_autolink(destination) {
    percent_encode_autolink_uri(destination)
  } else if is_email_autolink(destination) {
    "mailto:" + destination
  } else {
    return NoMatch
  }
  inline_match(
    end - i + 1,
    EventFragment::element(
      Element::with_attrs(tag_name("cm:link"), [
        { name: attr_name("destination"), value: href },
      ]),
      children=[EventFragment::text(destination)],
    ),
  )
}

///|
fn cm_raw_html_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 60 {
    return NoMatch
  }
  match raw_html_inline_end(text, i) {
    Some(end) =>
      return inline_match(end - i, EventFragment::html(text[i:end].to_owned()))
    None => ()
  }
  match raw_html_tag_end(text, i) {
    Some(end) => {
      let raw = text[i:end].to_owned()
      if looks_like_raw_html(raw) {
        return inline_match(end - i, EventFragment::html(raw))
      }
    }
    None => ()
  }
  NoMatch
}

///|
fn raw_html_inline_end(text : String, start : Int) -> Int? {
  let rest = text[start:].to_owned()
  if rest.has_prefix("<!--") {
    if rest.has_prefix("<!-->") || rest.has_prefix("<!--->") {
      let end = find_substring(text, "-->", start + 4)
      if end >= 0 {
        return Some(end + 2)
      }
      return None
    }
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
fn cm_entity_inline(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  if char_at(text, i) != 38 {
    return NoMatch
  }
  let end = find_char(text, 59, i + 1)
  if end < 0 || end - i > 32 {
    return NoMatch
  }
  let name = text[i + 1:end].to_owned()
  match decode_entity(name) {
    Some(decoded) => inline_match(end - i + 1, EventFragment::text(decoded))
    None => NoMatch
  }
}

///|
fn cm_emphasis_delimiter(ctx : InlineContext) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  let marker = char_at(text, i)
  if marker != 42 && marker != 95 {
    return NoMatch
  }
  if i > 0 && char_at(text, i - 1) == marker {
    return NoMatch
  }
  let run = delimiter_run_len(text, i, marker)
  if run > 12 {
    return inline_match(run, EventFragment::text(text[i:i + run].to_owned()))
  }
  if !delimiter_can_open(text, i, run, marker) {
    return NoMatch
  }
  if run >= 4 {
    let end = find_closing_run(text, marker, i + run, run)
    if end < 0 {
      return emphasis_partial_run_fallback(ctx, run)
    }
    let buffer = Events::new()
    let sink = buffer.sink()
    let strong_count = run / 2
    if run % 2 == 1 {
      sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
    }
    for _ in 0..<strong_count {
      sink.emit(Enter(Element::new(tag_name("cm:strong"))))
    }
    parse_inlines(text[i + run:end].to_owned(), ctx.registry, sink, ctx.state)
    for _ in 0..<strong_count {
      sink.emit(Exit(tag_name("cm:strong")))
    }
    if run % 2 == 1 {
      sink.emit(Exit(tag_name("cm:emphasis")))
    }
    inline_match(end - i + run, event_fragment_from_events(buffer.collect()))
  } else if run >= 3 {
    let end = find_closing_run(text, marker, i + 3, 3)
    if end < 0 {
      return emphasis_partial_run_fallback(ctx, run)
    }
    let buffer = Events::new()
    let sink = buffer.sink()
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
    sink.emit(Enter(Element::new(tag_name("cm:strong"))))
    parse_inlines(text[i + 3:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:strong")))
    sink.emit(Exit(tag_name("cm:emphasis")))
    inline_match(end - i + 3, event_fragment_from_events(buffer.collect()))
  } else if run >= 2 {
    let end = find_closing_run(text, marker, i + 2, 2)
    if end < 0 {
      return emphasis_partial_run_fallback(ctx, run)
    }
    let buffer = Events::new()
    let sink = buffer.sink()
    sink.emit(Enter(Element::new(tag_name("cm:strong"))))
    parse_inlines(text[i + 2:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:strong")))
    inline_match(end - i + 2, event_fragment_from_events(buffer.collect()))
  } else {
    let end = find_closing_single(text, marker, i + 1)
    if end < 0 {
      return NoMatch
    }
    if emphasis_would_split_link_text(text, i, end) {
      return NoMatch
    }
    let buffer = Events::new()
    let sink = buffer.sink()
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
    parse_inlines(text[i + 1:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:emphasis")))
    inline_match(end - i + 1, event_fragment_from_events(buffer.collect()))
  }
}

///|
fn emphasis_partial_run_fallback(
  ctx : InlineContext,
  run : Int,
) -> InlineRuleResult {
  let text = ctx.text
  let i = ctx.index
  let marker = char_at(text, i)
  if run >= 3 {
    let end = find_closing_run(text, marker, i + run, 2)
    if end >= 0 {
      let buffer = Events::new()
      let sink = buffer.sink()
      sink.emit(Text(text[i:i + run - 2].to_owned()))
      sink.emit(Enter(Element::new(tag_name("cm:strong"))))
      parse_inlines(text[i + run:end].to_owned(), ctx.registry, sink, ctx.state)
      sink.emit(Exit(tag_name("cm:strong")))
      return inline_match(
        end - i + 2,
        event_fragment_from_events(buffer.collect()),
      )
    }
  }
  let end = find_closing_single(text, marker, i + run)
  if end >= 0 {
    if run == 2 && delimiter_run_len(text, end, marker) >= 2 {
      return NoMatch
    }
    let buffer = Events::new()
    let sink = buffer.sink()
    sink.emit(Text(text[i:i + run - 1].to_owned()))
    sink.emit(Enter(Element::new(tag_name("cm:emphasis"))))
    parse_inlines(text[i + run:end].to_owned(), ctx.registry, sink, ctx.state)
    sink.emit(Exit(tag_name("cm:emphasis")))
    return inline_match(
      end - i + 1,
      event_fragment_from_events(buffer.collect()),
    )
  }
  NoMatch
}

///|
fn emphasis_would_split_link_text(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  if emphasis_close_splits_link_label(text, start, end) {
    return true
  }
  if start + 1 >= text.length() || char_at(text, start + 1) != 91 {
    return false
  }
  if link_text_may_contain_link(text[start + 2:end].to_owned()) {
    return false
  }
  if end + 1 >= text.length() || char_at(text, end + 1) != 93 {
    return false
  }
  let close_text = end + 1
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_text + 2)
    close_dest > close_text &&
    parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() > 0
  } else if close_text + 1 < text.length() &&
    char_at(text, close_text + 1) == 91 {
    true
  } else {
    true
  }
}

///|
fn emphasis_close_splits_link_label(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  if char_at(text, start) != 95 {
    return false
  }
  if end + 1 >= text.length() || char_at(text, end + 1) != 93 {
    return false
  }
  let mut open = -1
  let mut i = start + 1
  while i < end {
    if char_at(text, i) == 91 && !is_escaped_char(text, i) {
      open = i
    }
    i = i + 1
  }
  if open < 0 {
    return false
  }
  let close_text = end + 1
  if close_text + 1 < text.length() && char_at(text, close_text + 1) == 40 {
    let close_dest = find_link_destination_end(text, close_text + 2)
    close_dest > close_text &&
    parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() > 0
  } else if close_text + 1 < text.length() &&
    char_at(text, close_text + 1) == 91 {
    true
  } else {
    true
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
    match inline_span_end_for_delimiter_scan(text, i) {
      Some(end) => {
        i = end
        continue
      }
      None => ()
    }
    if delimiter_run_len(text, i, marker) >= width &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, width, marker) {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn find_closing_single(text : String, marker : Int, start : Int) -> Int {
  let exact = find_closing_single_run(text, marker, start, true)
  if exact >= 0 {
    return exact
  }
  find_closing_single_run(text, marker, start, false)
}

///|
fn find_closing_single_run(
  text : String,
  marker : Int,
  start : Int,
  exact_only : Bool,
) -> Int {
  let mut i = start
  while i < text.length() {
    match inline_span_end_for_delimiter_scan(text, i) {
      Some(end) => {
        i = end
        continue
      }
      None => ()
    }
    let run = if char_at(text, i) == marker {
      delimiter_run_len(text, i, marker)
    } else {
      0
    }
    if run > 0 &&
      (!exact_only || run == 1) &&
      !is_escaped_char(text, i) &&
      delimiter_can_close(text, i, 1, marker) {
      return i
    }
    if run > 0 {
      i = if is_escaped_char(text, i) { i + 1 } else { i + run }
    } else {
      i = i + 1
    }
  }
  -1
}

///|
fn delimiter_can_open(
  text : String,
  start : Int,
  width : Int,
  marker : Int,
) -> Bool {
  let left = is_left_flanking_delimiter(text, start, width)
  let right = is_right_flanking_delimiter(text, start, width)
  if marker == 42 {
    left
  } else if is_intraword_underscore(text, start, width) {
    false
  } else {
    left &&
    (
      !right ||
      start == 0 ||
      is_punctuation_for_flanking(char_at(text, start - 1))
    )
  }
}

///|
fn delimiter_can_close(
  text : String,
  start : Int,
  width : Int,
  marker : Int,
) -> Bool {
  let left = is_left_flanking_delimiter(text, start, width)
  let right = is_right_flanking_delimiter(text, start, width)
  if marker == 42 {
    right
  } else if is_intraword_underscore(text, start, width) {
    false
  } else {
    right &&
    (
      !left ||
      start + width >= text.length() ||
      is_punctuation_for_flanking(char_at(text, start + width))
    )
  }
}

///|
fn is_left_flanking_delimiter(text : String, start : Int, width : Int) -> Bool {
  if start + width >= text.length() {
    return false
  }
  let after = char_at(text, start + width)
  if is_space_for_delimiter_flanking(after) {
    return false
  }
  if is_punctuation_for_flanking(after) {
    start == 0 ||
    is_space_for_delimiter_flanking(char_at(text, start - 1)) ||
    is_punctuation_for_flanking(char_at(text, start - 1))
  } else {
    true
  }
}

///|
fn is_right_flanking_delimiter(text : String, start : Int, width : Int) -> Bool {
  if start == 0 {
    return false
  }
  let before = char_at(text, start - 1)
  if is_space_for_delimiter_flanking(before) {
    return false
  }
  if start + width >= text.length() {
    return true
  }
  if is_punctuation_for_flanking(before) {
    let after = char_at(text, start + width)
    is_space_for_delimiter_flanking(after) || is_punctuation_for_flanking(after)
  } else {
    true
  }
}

///|
fn is_space_for_delimiter_flanking(c : Int) -> Bool {
  is_unicode_whitespace(c)
}

///|
fn is_punctuation_for_flanking(c : Int) -> Bool {
  is_ascii_punctuation(c) || is_unicode_punctuation_or_symbol(c)
}

///|
fn is_intraword_underscore(text : String, start : Int, width : Int) -> Bool {
  start > 0 &&
  start + width < text.length() &&
  is_word_for_underscore(char_at(text, start - 1)) &&
  is_word_for_underscore(char_at(text, start + width))
}

///|
fn is_word_for_underscore(c : Int) -> Bool {
  !is_unicode_whitespace(c) && !is_punctuation_for_flanking(c)
}

///|
fn inline_span_end_for_delimiter_scan(text : String, start : Int) -> Int? {
  let c = char_at(text, start)
  if c == 96 {
    let width = delimiter_run_len(text, start, 96)
    let end = find_code_span_end(text, start + width, width)
    if end >= 0 {
      return Some(end + width)
    }
  } else if c == 60 {
    match raw_html_inline_end(text, start) {
      Some(end) => return Some(end)
      None => ()
    }
    match raw_html_tag_end(text, start) {
      Some(end) => return Some(end)
      None => ()
    }
    let end = find_char(text, 62, start + 1)
    if end >= 0 {
      let destination = text[start + 1:end].to_owned()
      if is_uri_autolink(destination) || is_email_autolink(destination) {
        return Some(end + 1)
      }
    }
  } else if c == 91 {
    let close_text = find_link_text_end(text, start + 1)
    if close_text > start &&
      close_text + 1 < text.length() &&
      char_at(text, close_text + 1) == 40 {
      let close_dest = find_link_destination_end(text, close_text + 2)
      if close_dest > close_text &&
        parse_link_attrs(text[close_text + 2:close_dest].to_owned()).length() >
        0 {
        return Some(close_dest + 1)
      }
    }
  }
  None
}

///|
fn percent_encode_autolink_uri(input : String) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut i = 0
  while i < input.length() {
    let c = char_at(input, i)
    if c == 91 || c == 93 {
      write_percent_byte(out, c)
      i = i + 1
    } else if c == 37 &&
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
fn raw_html_tag_end(text : String, start : Int) -> Int? {
  if start + 2 >= text.length() || char_at(text, start) != 60 {
    return None
  }
  let mut i = start + 1
  if char_at(text, i) == 47 {
    i = i + 1
  }
  if i >= text.length() || !is_ascii_alpha(char_at(text, i)) {
    return None
  }
  let closing = char_at(text, start + 1) == 47
  while i < text.length() &&
        (
          is_ascii_alpha(char_at(text, i)) ||
          is_ascii_digit(char_at(text, i)) ||
          char_at(text, i) == 45
        ) {
    i = i + 1
  }
  while i < text.length() {
    let c = char_at(text, i)
    if c == 62 {
      return Some(i + 1)
    } else if is_space(c) {
      i = i + 1
    } else if c == 47 {
      if closing {
        return None
      }
      if i + 1 < text.length() && char_at(text, i + 1) == 62 {
        i = i + 1
      } else {
        return None
      }
    } else if !closing &&
      i > start &&
      is_space(char_at(text, i - 1)) &&
      is_html_attr_name_start(c) {
      i = i + 1
      while i < text.length() && is_html_attr_name_char(char_at(text, i)) {
        i = i + 1
      }
      while i < text.length() && is_space(char_at(text, i)) {
        i = i + 1
      }
      if i < text.length() && char_at(text, i) == 61 {
        i = i + 1
        while i < text.length() && is_space(char_at(text, i)) {
          i = i + 1
        }
        let value_end = html_attr_value_end(text, i)
        match value_end {
          Some(next) => i = next
          None => return None
        }
      }
    } else {
      return None
    }
  }
  None
}

///|
fn html_attr_value_end(text : String, start : Int) -> Int? {
  if start >= text.length() {
    return None
  }
  let quote = char_at(text, start)
  if quote == 34 || quote == 39 {
    let end = find_char(text, quote, start + 1)
    if end < 0 {
      None
    } else {
      Some(end + 1)
    }
  } else {
    let mut i = start
    while i < text.length() {
      let c = char_at(text, i)
      if is_space(c) || c == 62 {
        return Some(i)
      }
      if c == 34 || c == 39 || c == 61 || c == 60 || c == 96 {
        return None
      }
      i = i + 1
    }
    Some(i)
  }
}

///|
fn is_html_attr_name_start(c : Int) -> Bool {
  is_ascii_alpha(c) || c == 95 || c == 58
}

///|
fn is_html_attr_name_char(c : Int) -> Bool {
  is_html_attr_name_start(c) || is_ascii_digit(c) || c == 46 || c == 45
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
