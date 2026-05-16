///|
fn char_at(text : String, index : Int) -> Int {
  text[index].to_int()
}

///|
fn trim(input : String) -> String {
  let mut start = 0
  let mut end = input.length()
  while start < end && is_space(char_at(input, start)) {
    start = start + 1
  }
  while end > start && is_space(char_at(input, end - 1)) {
    end = end - 1
  }
  input[start:end].to_owned()
}

///|
fn is_blank(input : String) -> Bool {
  for i in 0..<input.length() {
    if !is_space(char_at(input, i)) {
      return false
    }
  }
  true
}

///|
fn first_non_space_index(input : String) -> Int {
  for i in 0..<input.length() {
    if !is_space(char_at(input, i)) {
      return i
    }
  }
  -1
}

///|
fn is_space(c : Int) -> Bool {
  c == 32 || c == 9 || c == 10 || c == 13
}

///|
fn count_leading_spaces(input : String) -> Int {
  let mut count = 0
  while count < input.length() && char_at(input, count) == 32 {
    count = count + 1
  }
  count
}

///|
fn find_char(text : String, needle : Int, start : Int) -> Int {
  for i in start..<text.length() {
    if char_at(text, i) == needle {
      return i
    }
  }
  -1
}

///|
fn find_substring(text : String, needle : String, start : Int) -> Int {
  if needle == "" {
    return start
  }
  if needle.length() > text.length() {
    return -1
  }
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
