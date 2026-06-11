///|
priv struct BlockPayloadSource {
  lines : Array[String]
  line_starts : Array[Int]
}

///|
priv struct BlockPayload {
  first : String
  mut lines : Array[String]?
  mut line_starts : Array[Int]?
  mut next_start : Int
  mut length : Int
  mut may_contain_reference : Bool
}

///|
fn BlockPayload::BlockPayload(first : String) -> BlockPayload {
  {
    first,
    lines: None,
    line_starts: None,
    next_start: first.length() + 1,
    length: 1,
    may_contain_reference: may_contain_reference_definition(first),
  }
}

///|
fn BlockPayload::append(self : BlockPayload, line : String) -> Unit {
  self.materialize()
  if self.lines is Some(lines) {
    lines.push(line)
  }
  if self.line_starts is Some(line_starts) {
    line_starts.push(self.next_start)
  }
  self.next_start = self.next_start + line.length() + 1
  self.length = self.length + 1
  if !self.may_contain_reference && may_contain_reference_definition(line) {
    self.may_contain_reference = true
  }
}

///|
fn BlockPayload::materialize(self : BlockPayload) -> Unit {
  if self.lines is None {
    self.lines = Some([self.first])
    self.line_starts = Some([0])
  }
}

///|
fn BlockPayload::source(self : BlockPayload) -> BlockPayloadSource {
  match (self.lines, self.line_starts) {
    (Some(lines), Some(line_starts)) => { lines, line_starts }
    _ => { lines: [self.first], line_starts: [0] }
  }
}

///|
fn BlockPayload::to_text(self : BlockPayload) -> String {
  match self.lines {
    Some(lines) => block_lines_text(lines)
    None => self.first
  }
}

///|
fn BlockPayload::is_not_empty(self : BlockPayload) -> Bool {
  match self.lines {
    Some(lines) => block_lines_not_empty(lines)
    None => self.first != ""
  }
}

///|
fn BlockPayload::parse_into(
  self : BlockPayload,
  services : ParserServices,
  sink : Sink,
) -> Unit {
  let source = self.source()
  services.parse_block_lines(source.lines, source.line_starts, sink)
}

///|
fn BlockPayload::collect_references(
  self : BlockPayload,
  services : ParserServices,
) -> Unit {
  let source = self.source()
  services.collect_block_lines(source.lines, source.line_starts)
}

///|
fn may_contain_reference_definition(input : String) -> Bool {
  let first_label_opener = find_char(input, '[', 0)
  first_label_opener >= 0 &&
  find_substring(input, "]:", first_label_opener + 1) >= 0
}

///|
fn block_lines_not_empty(lines : Array[String]) -> Bool {
  for line in lines {
    if line != "" {
      return true
    }
  }
  false
}

///|
fn block_lines_text(lines : Array[String]) -> String {
  if lines.length() == 0 {
    return ""
  }
  if lines.length() == 1 {
    return lines[0]
  }
  let text = StringBuilder::new()
  for i in 0..<lines.length() {
    if i > 0 {
      text <+ "\n"
    }
    text <+ "\{lines[i]}"
  }
  text.to_string()
}
