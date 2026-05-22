// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "source_range helper preserves validated offsets" {
  let empty = source_range(3, 3)
  assert_eq(empty.start(), 3)
  assert_eq(empty.end(), 3)
  let span = source_range(2, 8)
  assert_eq(span.start(), 2)
  assert_eq(span.end(), 8)
}

///|
test "split_lines preserves offsets and detects reference candidates" {
  let source = split_lines("one\n\t two\n")
  assert_eq(source.lines.length(), 2)
  assert_eq(source.lines[0], "one")
  assert_eq(source.lines[1], "     two")
  assert_eq(source.line_starts.length(), 2)
  assert_eq(source.line_starts[0], 0)
  assert_eq(source.line_starts[1], 4)
  assert_eq(source.may_contain_reference, false)

  let multiline = split_lines("[foo\nbar]: /url\n")
  assert_eq(multiline.lines.length(), 2)
  assert_eq(multiline.may_contain_reference, true)
}

///|
test "commonmark inline plain text scan stops only at meaningful specials" {
  let normal_spaces = "alpha    beta"
  assert_eq(
    commonmark_plain_text_end(normal_spaces, 0, normal_spaces.length()),
    normal_spaces.length(),
  )
  let hard_break_spaces = "alpha  \nbeta"
  assert_eq(
    commonmark_plain_text_end(hard_break_spaces, 0, hard_break_spaces.length()),
    5,
  )
  let link = "alpha [beta]"
  assert_eq(commonmark_plain_text_end(link, 0, link.length()), 6)
}

///|
test "character references use generated HTML5 and Unicode data" {
  assert_true(decode_entity("CounterClockwiseContourIntegral") is Some("∳"))
  assert_true(decode_entity("NotNestedGreaterGreater") is Some("⪢̸"))
  assert_true(decode_entity("#x1F600") is Some("😀"))
  assert_true(decode_entity("#xD800") is Some("�"))
  assert_eq(commonmark_case_fold("ẞΑΩİ"), "ssαωi̇")
  assert_true(is_unicode_whitespace(0x205F))
  assert_true(is_unicode_punctuation_or_symbol(0x1F600))
}
