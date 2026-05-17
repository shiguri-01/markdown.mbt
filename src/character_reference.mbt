///|
fn decode_entity(name : String) -> String? {
  if name.has_prefix("#x") || name.has_prefix("#X") {
    decode_numeric_entity(name[2:].to_owned(), 16)
  } else if name.has_prefix("#") {
    decode_numeric_entity(name[1:].to_owned(), 10)
  } else {
    lookup_html5_named_character_reference(name)
  }
}

///|
fn decode_numeric_entity(digits : String, base : Int) -> String? {
  if digits == "" {
    return None
  }
  if (base == 10 && digits.length() > 7) || (base == 16 && digits.length() > 6) {
    return None
  }
  let mut value = 0
  for i in 0..<digits.length() {
    let digit = if base == 16 {
      hex_digit_value(char_at(digits, i))
    } else {
      decimal_digit_value(char_at(digits, i))
    }
    if digit < 0 {
      return None
    }
    if value <= 0x110000 {
      value = value * base + digit
    }
  }
  Some(numeric_character_reference_to_string(value))
}

///|
fn numeric_character_reference_to_string(value : Int) -> String {
  match html_c1_numeric_character_reference_replacement(value) {
    Some(replacement) => replacement
    None =>
      if value == 0 || value > 0x10FFFF || (value >= 0xD800 && value <= 0xDFFF) {
        "�"
      } else {
        unicode_scalar_to_string(value)
      }
  }
}

///|
fn html_c1_numeric_character_reference_replacement(value : Int) -> String? {
  match value {
    0x80 => Some("€")
    0x82 => Some("‚")
    0x83 => Some("ƒ")
    0x84 => Some("„")
    0x85 => Some("…")
    0x86 => Some("†")
    0x87 => Some("‡")
    0x88 => Some("ˆ")
    0x89 => Some("‰")
    0x8A => Some("Š")
    0x8B => Some("‹")
    0x8C => Some("Œ")
    0x8E => Some("Ž")
    0x91 => Some("‘")
    0x92 => Some("’")
    0x93 => Some("“")
    0x94 => Some("”")
    0x95 => Some("•")
    0x96 => Some("–")
    0x97 => Some("—")
    0x98 => Some("˜")
    0x99 => Some("™")
    0x9A => Some("š")
    0x9B => Some("›")
    0x9C => Some("œ")
    0x9E => Some("ž")
    0x9F => Some("Ÿ")
    _ => None
  }
}

///|
fn unicode_scalar_to_string(value : Int) -> String {
  match Int::to_char(value) {
    Some(c) => {
      let out = StringBuilder::new()
      out.write_char(c)
      out.to_string()
    }
    None => "�"
  }
}

///|
fn decimal_digit_value(c : Int) -> Int {
  if c >= 48 && c <= 57 {
    c - 48
  } else {
    -1
  }
}

///|
fn hex_digit_value(c : Int) -> Int {
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 65 && c <= 70 {
    c - 55
  } else if c >= 97 && c <= 102 {
    c - 87
  } else {
    -1
  }
}
