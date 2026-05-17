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
test "character references use generated HTML5 and Unicode data" {
  assert_true(decode_entity("CounterClockwiseContourIntegral") is Some("∳"))
  assert_true(decode_entity("NotNestedGreaterGreater") is Some("⪢̸"))
  assert_true(decode_entity("#x1F600") is Some("😀"))
  assert_true(decode_entity("#xD800") is Some("�"))
  assert_eq(commonmark_case_fold("ẞΑΩİ"), "ssαωi̇")
  assert_true(is_unicode_whitespace(0x205F))
  assert_true(is_unicode_punctuation_or_symbol(0x1F600))
}
