///|
test "commonmark inline text keeps ordinary spaces together" {
  let events = @markdown.Events()
  @markdown.Processor(@commonmark.rule()).parse(
    "hello world from moonbit",
    events.sink(),
  )
  let collected = events.collect()
  assert_eq(collected.length(), 3)
  match collected[1] {
    Text(text) => assert_eq(text, "hello world from moonbit")
    _ => abort("expected text")
  }
}

///|
test "commonmark inline text keeps long ordinary space runs together" {
  let spaces = StringBuilder::new(size_hint=128)
  for _ in 0..<128 {
    spaces <+ " "
  }
  let events = @markdown.Events()
  @markdown.Processor(@commonmark.rule()).parse(
    "hello" + spaces.to_string() + "*world*",
    events.sink(),
  )
  let collected = events.collect()
  assert_eq(collected.length(), 6)
  match collected[1] {
    Text(text) => assert_eq(text, "hello" + spaces.to_string())
    _ => abort("expected leading text")
  }
  match collected[3] {
    Text(text) => assert_eq(text, "world")
    _ => abort("expected emphasis text")
  }
}
