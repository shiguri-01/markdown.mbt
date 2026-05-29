///|
fn char_at(text : String, index : Int) -> Int {
  text[index].to_int()
}

///|
fn is_space(c : Int) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn is_blank(input : String) -> Bool {
  for i in 0..<input.length() {
    if !is_space(char_at(input, i)) {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn trim(input : String) -> String {
  let start = for start in 0..<input.length() {
    if !is_space(char_at(input, start)) {
      break start
    }
  } nobreak {
    input.length()
  }
  let end = for end in input.length()>=..(start + 1) {
    if !is_space(char_at(input, end - 1)) {
      break end
    }
  } nobreak {
    start
  }
  if start == 0 && end == input.length() {
    input
  } else {
    input[start:end].to_owned()
  }
}

///|
fn count_leading_spaces(input : String) -> Int {
  for count in 0..<input.length() {
    if char_at(input, count) != ' ' {
      break count
    }
  } nobreak {
    input.length()
  }
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

///|
fn contains_char(text : String, needle : Int) -> Bool {
  find_char(text, needle, 0) >= 0
}

///|
fn is_ascii_alpha(c : Int) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn is_ascii_alnum(c : Int) -> Bool {
  is_ascii_alpha(c) || (c >= '0' && c <= '9')
}

///|
fn to_lower_ascii(c : Int) -> Int {
  if c >= 'A' && c <= 'Z' {
    c + 32
  } else {
    c
  }
}

///|
fn ascii_char(code : Int) -> String {
  match code {
    32 => " "
    33 => "!"
    34 => "\""
    35 => "#"
    36 => "$"
    37 => "%"
    38 => "&"
    39 => "'"
    40 => "("
    41 => ")"
    42 => "*"
    43 => "+"
    44 => ","
    45 => "-"
    46 => "."
    47 => "/"
    48 => "0"
    49 => "1"
    50 => "2"
    51 => "3"
    52 => "4"
    53 => "5"
    54 => "6"
    55 => "7"
    56 => "8"
    57 => "9"
    58 => ":"
    59 => ";"
    60 => "<"
    61 => "="
    62 => ">"
    63 => "?"
    64 => "@"
    65 => "A"
    66 => "B"
    67 => "C"
    68 => "D"
    69 => "E"
    70 => "F"
    71 => "G"
    72 => "H"
    73 => "I"
    74 => "J"
    75 => "K"
    76 => "L"
    77 => "M"
    78 => "N"
    79 => "O"
    80 => "P"
    81 => "Q"
    82 => "R"
    83 => "S"
    84 => "T"
    85 => "U"
    86 => "V"
    87 => "W"
    88 => "X"
    89 => "Y"
    90 => "Z"
    91 => "["
    92 => "\\"
    93 => "]"
    94 => "^"
    95 => "_"
    96 => "`"
    97 => "a"
    98 => "b"
    99 => "c"
    100 => "d"
    101 => "e"
    102 => "f"
    103 => "g"
    104 => "h"
    105 => "i"
    106 => "j"
    107 => "k"
    108 => "l"
    109 => "m"
    110 => "n"
    111 => "o"
    112 => "p"
    113 => "q"
    114 => "r"
    115 => "s"
    116 => "t"
    117 => "u"
    118 => "v"
    119 => "w"
    120 => "x"
    121 => "y"
    122 => "z"
    123 => "{"
    124 => "|"
    125 => "}"
    126 => "~"
    _ => ""
  }
}

///|
fn is_escaped_char(text : String, index : Int) -> Bool {
  let mut slash_count = 0
  let mut i = index - 1
  while i >= 0 && char_at(text, i) == '\\' {
    slash_count = slash_count + 1
    i = i - 1
  }
  slash_count % 2 == 1
}

///|
fn attrs_with(attrs : Array[Attr], added : Attr) -> Array[Attr] {
  let out : Array[Attr] = []
  for old in attrs {
    out.push(old)
  }
  out.push(added)
  out
}
