// Whitebox tests for CommonMark helper internals.

///|
test "commonmark inline plain text scan stops only at meaningful specials" {
  let normal_spaces = "alpha    beta"
  assert_eq(
    plain_text_end_loop(normal_spaces, 0, normal_spaces.length(), fn(_) {
      false
    }),
    normal_spaces.length(),
  )
  let hard_break_spaces = "alpha  \nbeta"
  assert_eq(
    plain_text_end_loop(hard_break_spaces, 0, hard_break_spaces.length(), fn(
      _,
    ) {
      false
    }),
    5,
  )
  let link = "alpha [beta]"
  assert_eq(plain_text_end_loop(link, 0, link.length(), fn(_) { false }), 6)
}

///|
test "character references use generated HTML5 and Unicode data" {
  assert_true(decode_entity("CounterClockwiseContourIntegral") is Some("∳"))
  assert_true(decode_entity("NotNestedGreaterGreater") is Some("⪢̸"))
  assert_true(decode_entity("#x1F600") is Some("😀"))
  assert_true(decode_entity("#xD800") is Some("�"))
  assert_eq(case_fold("ẞΑΩİ"), "ssαωi̇")
  assert_true(is_unicode_whitespace(0x205F))
  assert_true(is_unicode_punctuation_or_symbol(0x1F600))
}
