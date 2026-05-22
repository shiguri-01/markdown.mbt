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
    let consumed = if is_commonmark_inline_special(text, i, end) {
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
fn is_commonmark_inline_special(text : String, index : Int, end : Int) -> Bool {
  if char_at(text, index) != ' ' {
    return is_inline_special(text, index)
  }
  let mut i = index
  while i < end && char_at(text, i) == ' ' {
    i = i + 1
  }
  i < end && char_at(text, i) == '\n'
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
  if c == '`' {
    return emit_commonmark_code_span(text, start, end, sink)
  }
  if c == '<' {
    let raw_or_auto = emit_commonmark_angle_span(text, start, end, sink)
    if raw_or_auto > 0 {
      return raw_or_auto
    }
  }
  if c == '!' && start + 1 < end && char_at(text, start + 1) == '[' {
    let image = emit_commonmark_image(text, start, end, registry, sink, state)
    if image > 0 {
      return image
    }
  }
  if allow_links && c == '[' {
    let link = emit_commonmark_link(text, start, end, registry, sink, state)
    if link > 0 {
      return link
    }
  }
  if c == '*' || c == '_' {
    let emphasis = emit_commonmark_emphasis(
      text, start, end, registry, sink, state, allow_links,
    )
    if emphasis > 0 {
      return emphasis
    }
  }
  if c == '\\' && start + 1 < end && char_at(text, start + 1) == '\n' {
    sink.emit(HardBreak)
    return 2
  }
  if c == '\\' &&
    start + 1 < end &&
    is_ascii_punctuation(char_at(text, start + 1)) {
    sink.emit(Text(text[start + 1:start + 2].to_owned()))
    return 2
  }
  if c == ' ' {
    let mut space_end = start
    while space_end < end && char_at(text, space_end) == ' ' {
      space_end = space_end + 1
    }
    if space_end < end && char_at(text, space_end) == '\n' {
      if space_end - start >= 2 {
        sink.emit(HardBreak)
        return space_end - start + 1
      }
      return space_end - start
    }
  }
  if c == '\n' {
    sink.emit(SoftBreak)
    return 1
  }
  if c == '&' {
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
  if start > 0 && char_at(text, start - 1) == '`' {
    return 0
  }
  let width = delimiter_run_len(text, start, '`')
  let close = find_code_span_end_before(text, start + width, width, end)
  if close < 0 {
    return 0
  }
  sink.emit(Enter(Element(tag_name("cm:code_span"))))
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
    if char_at(text, i) == '`' {
      let run = delimiter_run_len(text, i, '`')
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
        sink.emit(RawHtml(text[start:close].to_owned()))
        return close - start
      }
    None => ()
  }
  match raw_html_tag_end(text, start) {
    Some(close) =>
      if close <= end {
        let raw = text[start:close].to_owned()
        if looks_like_raw_html(raw) {
          sink.emit(RawHtml(raw))
          return close - start
        }
      }
    None => ()
  }
  let close = find_char(text, '>', start + 1)
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
  let close = find_char(text, ';', start + 1)
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
  if link_text_range_may_contain_link(text, start + 1, close_text) ||
    link_text_has_unclosed_priority_span(text, start + 1, close_text) {
    return 0
  }
  if close_text + 1 < end && char_at(text, close_text + 1) == '(' {
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
  if close_alt + 1 < end && char_at(text, close_alt + 1) == '(' {
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
    sink.emit(Enter(Element(tag_name("cm:emphasis"))))
  }
  sink.emit(Enter(Element(tag)))
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
  sink.emit(Enter(Element(tag)))
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
  sink.emit(Enter(Element(tag)))
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
  if (other != '*' && other != '_') || other == marker {
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
    sink.emit(Enter(Element(tag_name("cm:emphasis"))))
  }
  for _ in 0..<strong_count {
    sink.emit(Enter(Element(tag_name("cm:strong"))))
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
      sink.emit(Enter(Element(tag_name("cm:strong"))))
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
      sink.emit(Enter(Element(tag_name("cm:emphasis"))))
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
          sink.emit(Enter(Element(tag_name("cm:emphasis"))))
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
        sink.emit(Enter(Element(tag_name("cm:emphasis"))))
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
      sink.emit(Enter(Element(tag_name("cm:emphasis"))))
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
  if c == '`' {
    let width = delimiter_run_len(text, start, '`')
    let close = find_code_span_end_before(text, start + width, width, end)
    if close >= 0 {
      return Some(close + width)
    }
  } else if c == '<' {
    match raw_html_inline_end(text, start) {
      Some(close) => if close <= end { return Some(close) }
      None => ()
    }
    match raw_html_tag_end(text, start) {
      Some(close) => if close <= end { return Some(close) }
      None => ()
    }
    let close = find_char(text, '>', start + 1)
    if close >= 0 && close < end {
      let candidate = text[start + 1:close].to_owned()
      if is_uri_autolink(candidate) || is_email_autolink(candidate) {
        return Some(close + 1)
      }
    }
  }
  None
}
