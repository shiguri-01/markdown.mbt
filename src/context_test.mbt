///|
test "inline scanner handles offsets and invalid ranges" {
  assert_true(@markdown.InlineScanner::new("abc", -1) is None)
  assert_true(@markdown.InlineScanner::new("abc", 4) is None)
  let scanner = match @markdown.InlineScanner::new("alpha@beta", 5) {
    Some(scanner) => scanner
    None => abort("expected scanner")
  }
  assert_true(scanner.has_prefix("@b"))
  assert_true(scanner.char() is Some(64))
  assert_true(scanner.char_at_offset(-1) is Some(97))
  assert_true(scanner.char_at_offset(100) is None)
  assert_true(scanner.slice(1, 5) is Some("beta"))
  assert_true(scanner.slice(5, 1) is None)
  assert_true(scanner.slice(-10, 1) is None)
  assert_true(scanner.find_char(98) is Some(1))
  assert_true(scanner.find_char(35) is None)
  let end = match @markdown.InlineScanner::new("abc", 3) {
    Some(scanner) => scanner
    None => abort("expected end scanner")
  }
  assert_true(end.char() is None)
}

///|
test "block context exposes line positions to extension rules" {
  let probe = @markdown.Rule::block(
    @markdown.RuleName::raw("x:block:probe"),
    priority=100,
    fn(ctx) {
      if ctx.current_line() == "first" {
        let next = match ctx.line_at(1) {
          Some(line) => line
          None => "missing"
        }
        let before = match ctx.line_at(-1) {
          Some(line) => line
          None => "none"
        }
        Match(
          @markdown.ConsumedLines(1),
          @markdown.EventFragment::text(
            ctx.line_index().to_string() +
            "|" +
            ctx.current_line_start().to_string() +
            "|" +
            ctx.current_line() +
            "|" +
            next +
            "|" +
            before,
          ),
        )
      } else {
        NoMatch
      }
    },
  )
  assert_eq(
    render_html(@markdown.commonmark().extend(probe), "first\nsecond\n"),
    "0|0|first|second|none<p>second</p>\n",
  )
}
