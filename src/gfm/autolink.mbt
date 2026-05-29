///|
priv struct AutolinkMatch {
  start : Int
  end : Int
  text : String
  href : String
}

///|
fn extended_autolink_core(downstream : Sink) -> Sink {
  let mut skip_depth = 0
  let mut pending : String? = None
  fn flush() -> Unit {
    match pending {
      Some(text) => {
        emit_extended_autolink_text(text, downstream)
        pending = None
      }
      None => ()
    }
  }
  Sink(
    fn(event) {
      match event {
        @markdown.Enter(el) => {
          flush()
          let tag = el.tag().to_string()
          if tag == "cm:link" || tag == "cm:image" || tag == "cm:code_span" {
            skip_depth = skip_depth + 1
          }
          downstream.emit(event)
        }
        @markdown.Exit(tag) => {
          flush()
          let name = tag.to_string()
          downstream.emit(event)
          if name == "cm:link" || name == "cm:image" || name == "cm:code_span" {
            skip_depth = skip_depth - 1
          }
        }
        @markdown.Text(text) =>
          if skip_depth > 0 {
            downstream.emit(event)
          } else {
            match pending {
              Some(prev) => pending = Some(prev + text)
              None => pending = Some(text)
            }
          }
        _ => {
          flush()
          downstream.emit(event)
        }
      }
    },
    finish=fn() {
      flush()
      downstream.finish()
    },
  )
}

///|
fn emit_extended_autolink_text(text : String, sink : Sink) -> Unit {
  let mut i = 0
  let mut plain_start = 0
  while i < text.length() {
    match autolink_at(text, i) {
      Some(link) => {
        if link.start > plain_start {
          sink.emit(@markdown.Text(text[plain_start:link.start].to_owned()))
        }
        emit_autolink(link, sink)
        i = link.end
        plain_start = i
      }
      None => i = i + 1
    }
  }
  if plain_start < text.length() {
    sink.emit(@markdown.Text(text[plain_start:].to_owned()))
  }
}

///|
fn emit_autolink(link : AutolinkMatch, sink : Sink) -> Unit {
  sink.emit(
    @markdown.Enter(
      @markdown.Element::with_attrs(tag_name("cm:link"), [
        attr("destination", link.href),
      ]),
    ),
  )
  sink.emit(@markdown.Text(link.text))
  sink.emit(@markdown.Exit(tag_name("cm:link")))
}

///|
fn autolink_at(text : String, start : Int) -> AutolinkMatch? {
  guard extended_autolink_boundary(text, start) else { None }
  if has_prefix_at(text, "www.", start) {
    return url_autolink_at(text, start, start + 4, "http://")
  }
  if has_prefix_at(text, "http://", start) {
    return url_autolink_at(text, start, start + 7, "")
  }
  if has_prefix_at(text, "https://", start) {
    return url_autolink_at(text, start, start + 8, "")
  }
  if has_prefix_at(text, "ftp://", start) {
    return url_autolink_at(text, start, start + 6, "")
  }
  if has_prefix_at(text, "mailto:", start) {
    return scheme_email_autolink_at(text, start, start + 7, "mailto")
  }
  if has_prefix_at(text, "xmpp:", start) {
    return scheme_email_autolink_at(text, start, start + 5, "xmpp")
  }
  email_autolink_at(text, start)
}

///|
fn extended_autolink_boundary(text : String, start : Int) -> Bool {
  if start == 0 {
    return true
  }
  let prev = char_at(text, start - 1)
  is_space(prev) || prev == '*' || prev == '_' || prev == '~' || prev == '('
}

///|
fn url_autolink_at(
  text : String,
  start : Int,
  domain_start : Int,
  href_prefix : String,
) -> AutolinkMatch? {
  let mut domain_end = scan_domain_end(text, domain_start)
  while domain_end > domain_start && char_at(text, domain_end - 1) == '.' {
    domain_end = domain_end - 1
  }
  guard valid_domain(text, domain_start, domain_end) else { None }
  let mut end = domain_end
  while end < text.length() &&
        !is_space(char_at(text, end)) &&
        char_at(text, end) != '<' {
    end = end + 1
  }
  end = trim_autolink_end(text, start, end)
  guard end >= domain_end else { None }
  let label = text[start:end].to_owned()
  Some({ start, end, text: label, href: href_prefix + label })
}

///|
fn scheme_email_autolink_at(
  text : String,
  start : Int,
  address_start : Int,
  scheme : String,
) -> AutolinkMatch? {
  let email = email_address_end(text, address_start)
  guard email > address_start else { None }
  let mut end = email
  if scheme == "xmpp" && end < text.length() && char_at(text, end) == '/' {
    end = end + 1
    while end < text.length() {
      let c = char_at(text, end)
      if is_ascii_alnum(c) || c == '@' || c == '.' {
        end = end + 1
      } else {
        break
      }
    }
  }
  end = trim_autolink_end(text, start, end)
  let label = text[start:end].to_owned()
  Some({ start, end, text: label, href: label })
}

///|
fn email_autolink_at(text : String, start : Int) -> AutolinkMatch? {
  let end = email_address_end(text, start)
  guard end > start else { None }
  let label = text[start:end].to_owned()
  Some({ start, end, text: label, href: "mailto:" + label })
}

///|
fn email_address_end(text : String, start : Int) -> Int {
  guard start < text.length() && is_email_local_char(char_at(text, start)) else {
    -1
  }
  let mut at = -1
  let mut i = start
  while i < text.length() {
    let c = char_at(text, i)
    if c == '@' {
      at = i
      break
    }
    if !is_email_local_char(c) {
      return -1
    }
    i = i + 1
  }
  guard at > start && at + 1 < text.length() else { -1 }
  let mut domain_end = scan_domain_end(text, at + 1)
  while domain_end > at + 1 && char_at(text, domain_end - 1) == '.' {
    domain_end = domain_end - 1
  }
  guard valid_domain(text, at + 1, domain_end) else { -1 }
  trim_autolink_end(text, start, domain_end)
}

///|
fn is_email_local_char(c : Int) -> Bool {
  is_ascii_alnum(c) ||
  c == '.' ||
  c == '!' ||
  c == '#' ||
  c == '$' ||
  c == '%' ||
  c == '&' ||
  c == '\'' ||
  c == '*' ||
  c == '+' ||
  c == '-' ||
  c == '/' ||
  c == '=' ||
  c == '?' ||
  c == '^' ||
  c == '_' ||
  c == '`' ||
  c == '{' ||
  c == '|' ||
  c == '}' ||
  c == '~'
}

///|
fn scan_domain_end(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let c = char_at(text, i)
    if is_ascii_alnum(c) || c == '_' || c == '-' || c == '.' {
      i = i + 1
    } else {
      break
    }
  }
  i
}

///|
fn valid_domain(text : String, start : Int, end : Int) -> Bool {
  guard end > start else { false }
  let mut segment_count = 0
  let mut last_segment_start = start
  let mut prev_segment_start = -1
  let mut saw_dot = false
  let mut i = start
  while i <= end {
    if i == end || char_at(text, i) == '.' {
      if i == last_segment_start {
        return false
      }
      if !is_ascii_alnum(char_at(text, last_segment_start)) ||
        !is_ascii_alnum(char_at(text, i - 1)) {
        return false
      }
      prev_segment_start = last_segment_start
      last_segment_start = i + 1
      segment_count = segment_count + 1
      if i < end {
        saw_dot = true
      }
    } else {
      let c = char_at(text, i)
      if !(is_ascii_alnum(c) || c == '_' || c == '-') {
        return false
      }
    }
    i = i + 1
  }
  guard saw_dot && segment_count >= 2 else { false }
  let penultimate = domain_segment_before(text, start, end)
  !domain_segment_has_underscore(text, penultimate, prev_segment_start - 1) &&
  !domain_segment_has_underscore(text, prev_segment_start, end)
}

///|
fn domain_segment_before(text : String, start : Int, end : Int) -> Int {
  let mut dots = 0
  for i in (end - 1)>=..start {
    if char_at(text, i) == '.' {
      dots = dots + 1
      if dots == 2 {
        return i + 1
      }
    }
  }
  start
}

///|
fn domain_segment_has_underscore(text : String, start : Int, end : Int) -> Bool {
  for i in start..<end {
    if char_at(text, i) == '_' {
      return true
    }
  }
  false
}

///|
fn trim_autolink_end(text : String, start : Int, end : Int) -> Int {
  let mut out = end
  while out > start && is_trailing_autolink_punctuation(char_at(text, out - 1)) {
    out = out - 1
  }
  while out > start &&
        char_at(text, out - 1) == ')' &&
        closing_parens_exceed_opening(text, start, out) {
    out = out - 1
  }
  if out > start && char_at(text, out - 1) == ';' {
    let entity = entity_suffix_start(text, start, out)
    if entity >= start {
      out = entity
    }
  }
  out
}

///|
fn is_trailing_autolink_punctuation(c : Int) -> Bool {
  c == '?' ||
  c == '!' ||
  c == '.' ||
  c == ',' ||
  c == ':' ||
  c == '*' ||
  c == '_' ||
  c == '~'
}

///|
fn closing_parens_exceed_opening(text : String, start : Int, end : Int) -> Bool {
  let mut open = 0
  let mut close = 0
  for i in start..<end {
    if char_at(text, i) == '(' {
      open = open + 1
    } else if char_at(text, i) == ')' {
      close = close + 1
    }
  }
  close > open
}

///|
fn entity_suffix_start(text : String, start : Int, end : Int) -> Int {
  let mut i = end - 2
  guard i >= start && is_ascii_alnum(char_at(text, i)) else { -1 }
  while i >= start && is_ascii_alnum(char_at(text, i)) {
    i = i - 1
  }
  if i >= start && char_at(text, i) == '&' {
    i
  } else {
    -1
  }
}
