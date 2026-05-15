///|
fn repeat_text(text : String, count : Int) -> String {
  let mut out = ""
  for _ in 0..<count {
    out = out + text
  }
  out
}

///|
fn large_paragraph_input() -> String {
  repeat_text("MoonBit markdown parser benchmark text. ", 200)
}

///|
fn deep_list_input() -> String {
  repeat_text("- item\n", 200)
}

///|
fn long_delimiter_input() -> String {
  repeat_text("*", 500) + "text" + repeat_text("*", 500)
}

///|
fn many_links_input() -> String {
  repeat_text("[link](/url) ", 200)
}

///|
fn no_op_inline_rule(
  _ctx : @markdown.InlineContext,
  _sink : @markdown.EventSink,
) -> Int {
  0
}

///|
fn many_extension_rules_plugin(count : Int) -> @markdown.Plugin {
  let plugin = @markdown.Plugin::new("many-extension-rules")
  for i in 0..<count {
    ignore(
      plugin.add(
        @markdown.Rule::inline(
          "x:inline:no_op:" + i.to_string(),
          priority=-i,
          no_op_inline_rule,
        ),
      ),
    )
  }
  plugin
}

///|
test "benchmark parser scenarios produce events" {
  assert_true(
    @markdown.ParserBuilder::commonmark()
    .parse(large_paragraph_input())
    .collect()
    .length() >
    0,
  )
  assert_true(
    @markdown.ParserBuilder::commonmark()
    .parse(deep_list_input())
    .collect()
    .length() >
    0,
  )
  assert_true(
    @markdown.ParserBuilder::commonmark()
    .parse(long_delimiter_input())
    .collect()
    .length() >
    0,
  )
  assert_true(
    @markdown.ParserBuilder::commonmark()
    .parse(many_links_input())
    .collect()
    .length() >
    0,
  )
  assert_true(
    @markdown.ParserBuilder::commonmark()
    .use(many_extension_rules_plugin(50))
    .parse(large_paragraph_input())
    .collect()
    .length() >
    0,
  )
}

///|
test "benchmark markdown parser scenarios" {
  let bencher = @bench.new()
  bencher.bench(
    name="large_paragraph",
    fn() {
      bencher.keep(
        @markdown.ParserBuilder::commonmark()
        .parse(large_paragraph_input())
        .collect()
        .length(),
      )
    },
    count=2,
  )
  bencher.bench(
    name="deep_list",
    fn() {
      bencher.keep(
        @markdown.ParserBuilder::commonmark()
        .parse(deep_list_input())
        .collect()
        .length(),
      )
    },
    count=2,
  )
  bencher.bench(
    name="long_delimiter_run",
    fn() {
      bencher.keep(
        @markdown.ParserBuilder::commonmark()
        .parse(long_delimiter_input())
        .collect()
        .length(),
      )
    },
    count=2,
  )
  bencher.bench(
    name="many_links",
    fn() {
      bencher.keep(
        @markdown.ParserBuilder::commonmark()
        .parse(many_links_input())
        .collect()
        .length(),
      )
    },
    count=2,
  )
  bencher.bench(
    name="many_extension_rules",
    fn() {
      bencher.keep(
        @markdown.ParserBuilder::commonmark()
        .use(many_extension_rules_plugin(50))
        .parse(large_paragraph_input())
        .collect()
        .length(),
      )
    },
    count=2,
  )
  assert_true(bencher.dump_summaries().length() > 0)
}
