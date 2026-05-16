///|
/// Renders Markdown directly to HTML with the built-in CommonMark processor.
///
/// This avoids materializing the intermediate event array for throughput
/// oriented end-to-end processing. Processors with extension rules fall back to
/// the event pipeline so custom syntax still observes registered rules.
pub fn Processor::render_to_html(self : Processor, input : String) -> String {
  if self.registry.has_commonmark_preset_only() {
    render_commonmark_html_fast(input)
  } else {
    self.parse(input).collect() |> to_html
  }
}

///|
fn render_commonmark_html_fast(input : String) -> String {
  let source = split_lines(input)
  let out = StringBuilder::new(size_hint=input.length())
  let mut i = 0
  while i < source.lines.length() {
    let line = source.lines[i]
    let first = first_non_space_index(line)
    if first < 0 {
      i = i + 1
      continue
    }
    let leading = count_leading_spaces(line)
    let trimmed = trim(line)
    if leading <= 3 && trimmed.has_prefix("```") {
      i = render_fast_fenced_code(source.lines, i, out)
    } else if leading <= 3 &&
      trimmed.has_prefix("#") &&
      is_atx_heading_start(trimmed) {
      render_fast_heading(trimmed, out)
      i = i + 1
    } else if leading <= 3 && trimmed.has_prefix(">") {
      i = render_fast_blockquote(source.lines, i, out)
    } else if leading <= 3 &&
      (is_unordered_list_marker(trimmed) || is_ordered_list_marker(trimmed)) {
      i = render_fast_list(source.lines, i, out)
    } else {
      i = render_fast_paragraph(source.lines, i, out)
    }
  }
  out.to_string()
}

///|
fn render_fast_fenced_code(
  lines : Array[String],
  start : Int,
  out : StringBuilder,
) -> Int {
  let opening = fence_marker(trim(lines[start]))
  let info = fence_info(trim(lines[start]), opening)
  out.write_string("<pre><code")
  if info != "" {
    out.write_string(" class=\"language-")
    out.write_string(escape_html(info))
    out.write_string("\"")
  }
  out.write_string(">")
  let mut i = start + 1
  while i < lines.length() && !is_closing_fence_line(lines[i], opening) {
    if i > start + 1 {
      out.write_string("\n")
    }
    out.write_string(escape_html(lines[i]))
    i = i + 1
  }
  out.write_string("\n</code></pre>\n")
  if i < lines.length() {
    i + 1
  } else {
    i
  }
}

///|
fn render_fast_heading(line : String, out : StringBuilder) -> Unit {
  let mut level = 0
  while level < line.length() && level < 6 && char_at(line, level) == 35 {
    level = level + 1
  }
  let content = if level >= line.length() {
    ""
  } else {
    trim(strip_closing_hashes(line[level:].to_owned()))
  }
  out.write_string("<h")
  out.write_string(level.to_string())
  out.write_string(">")
  render_fast_inlines(content, out)
  out.write_string("</h")
  out.write_string(level.to_string())
  out.write_string(">\n")
}

///|
fn render_fast_blockquote(
  lines : Array[String],
  start : Int,
  out : StringBuilder,
) -> Int {
  out.write_string("<blockquote>\n")
  let mut i = start
  while i < lines.length() && is_blockquote_marker_line(lines[i]) {
    out.write_string("<p>")
    render_fast_inlines(strip_blockquote_marker(lines[i]), out)
    out.write_string("</p>\n")
    i = i + 1
  }
  out.write_string("</blockquote>\n")
  i
}

///|
fn render_fast_list(
  lines : Array[String],
  start : Int,
  out : StringBuilder,
) -> Int {
  let first = trim(lines[start])
  let ordered = is_ordered_list_marker(first)
  let delimiter = if ordered {
    ordered_list_delimiter(first)
  } else {
    char_at(first, 0)
  }
  if ordered {
    out.write_string("<ol")
    let list_start = ordered_list_start(first)
    if list_start != 1 {
      out.write_string(" start=\"")
      out.write_string(list_start.to_string())
      out.write_string("\"")
    }
    out.write_string(">\n")
  } else {
    out.write_string("<ul>\n")
  }
  let mut i = start
  while i < lines.length() {
    if count_leading_spaces(lines[i]) > 3 {
      break
    }
    let current = trim(lines[i])
    if ordered {
      if !is_ordered_list_marker(current) ||
        ordered_list_delimiter(current) != delimiter {
        break
      }
    } else if !is_unordered_list_marker(current) ||
      char_at(current, 0) != delimiter {
      break
    }
    let item = if ordered {
      strip_ordered_marker(current)
    } else {
      strip_unordered_marker(current)
    }
    out.write_string("<li>")
    render_fast_inlines(trim(item), out)
    out.write_string("</li>\n")
    i = i + 1
  }
  if ordered {
    out.write_string("</ol>\n")
  } else {
    out.write_string("</ul>\n")
  }
  i
}

///|
fn render_fast_paragraph(
  lines : Array[String],
  start : Int,
  out : StringBuilder,
) -> Int {
  out.write_string("<p>")
  let mut i = start
  while i < lines.length() &&
        !is_blank(lines[i]) &&
        (i == start || !is_paragraph_interrupt(lines[i])) {
    if i > start {
      out.write_string("\n")
    }
    render_fast_inlines(paragraph_line(lines[i]), out)
    i = i + 1
  }
  out.write_string("</p>\n")
  i
}

///|
fn render_fast_inlines(text : String, out : StringBuilder) -> Unit {
  let mut i = 0
  let mut text_start = 0
  while i < text.length() {
    let c = char_at(text, i)
    if c == 38 || c == 60 || c == 62 || c == 34 || c == 96 || c == 42 || c == 91 {
      if text_start < i {
        out.write_string(escape_html(text[text_start:i].to_owned()))
      }
      if c == 96 {
        let end = find_char(text, 96, i + 1)
        if end > i {
          out.write_string("<code>")
          out.write_string(escape_html(text[i + 1:end].to_owned()))
          out.write_string("</code>")
          i = end + 1
          text_start = i
          continue
        }
      } else if c == 42 {
        let consumed = render_fast_emphasis(text, i, out)
        if consumed > 0 {
          i = i + consumed
          text_start = i
          continue
        }
      } else if c == 91 {
        let consumed = render_fast_link(text, i, out)
        if consumed > 0 {
          i = i + consumed
          text_start = i
          continue
        }
      } else if c == 60 {
        let end = find_char(text, 62, i + 1)
        if end > i {
          out.write_view(text[i:end + 1])
          i = end + 1
          text_start = i
          continue
        }
      }
      out.write_string(escape_html(text[i:i + 1].to_owned()))
      i = i + 1
      text_start = i
    } else {
      i = i + 1
    }
  }
  if text_start < text.length() {
    out.write_string(escape_html(text[text_start:].to_owned()))
  }
}

///|
fn render_fast_emphasis(text : String, start : Int, out : StringBuilder) -> Int {
  if start + 1 < text.length() && char_at(text, start + 1) == 42 {
    let end = find_substring(text, "**", start + 2)
    if end >= 0 {
      out.write_string("<strong>")
      render_fast_inlines(text[start + 2:end].to_owned(), out)
      out.write_string("</strong>")
      return end - start + 2
    }
  }
  let end = find_char(text, 42, start + 1)
  if end > start {
    out.write_string("<em>")
    render_fast_inlines(text[start + 1:end].to_owned(), out)
    out.write_string("</em>")
    return end - start + 1
  }
  0
}

///|
fn render_fast_link(text : String, start : Int, out : StringBuilder) -> Int {
  let close_text = find_link_text_end(text, start + 1)
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
  out.write_string("<a href=\"")
  out.write_string(escape_html(attr_value(attrs, "destination", "")))
  out.write_string("\"")
  let title = attr_value(attrs, "title", "")
  if title != "" {
    out.write_string(" title=\"")
    out.write_string(escape_html(title))
    out.write_string("\"")
  }
  out.write_string(">")
  render_fast_inlines(text[start + 1:close_text].to_owned(), out)
  out.write_string("</a>")
  close_dest - start + 1
}
