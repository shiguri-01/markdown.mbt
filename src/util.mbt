///|
fn char_at(text : String, index : Int) -> Int {
  text[index].to_int()
}

///|
fn find_char(text : String, needle : Int, start : Int) -> Int {
  for i in start..<text.length() {
    if char_at(text, i) == needle {
      break i
    }
  } nobreak {
    -1
  }
}

///|
fn find_substring(text : String, needle : String, start : Int) -> Int {
  if needle == "" {
    return start
  }
  guard needle.length() <= text.length() else { -1 }
  let limit = text.length() - needle.length()
  for i in start..<=limit {
    let mut matched = true
    for j in 0..<needle.length() {
      if char_at(text, i + j) != char_at(needle, j) {
        matched = false
        break
      }
    }
    if matched {
      return i
    }
  }
  -1
}

///|
fn contains_char(text : String, needle : Int) -> Bool {
  find_char(text, needle, 0) >= 0
}

///|
fn is_space(c : Int) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn has_prefix_at(text : String, prefix : String, start : Int) -> Bool {
  guard start >= 0 && start + prefix.length() <= text.length() else { false }
  for i in 0..<prefix.length() {
    if char_at(text, start + i) != char_at(prefix, i) {
      break false
    }
  } nobreak {
    true
  }
}
