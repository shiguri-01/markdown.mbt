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
