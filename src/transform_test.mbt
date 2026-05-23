///|
test "sink transforms compose and finish in order" {
  let events = @markdown.Events()
  let from = @markdown.Tag::raw("x:old")
  let to = @markdown.Tag::raw("x:new")
  let sink = events
    .sink()
    .text_merge()
    .softbreak_to_hardbreak()
    .inject_attr(to, @markdown.Attr(@markdown.AttrName::raw("kind"), "demo"))
    .rename_tag(from, to)
  sink.emit(Enter(@markdown.Element(from)))
  sink.emit(Text("a"))
  sink.emit(Text("b"))
  sink.emit(SoftBreak)
  sink.emit(Exit(from))
  sink.finish()
  let collected = events.collect()
  assert_eq(collected.length(), 4)
  match collected[0] {
    Enter(el) => {
      assert_eq(el.tag().to_string(), "x:new")
      assert_true(el.attr(@markdown.AttrName::raw("kind")) is Some("demo"))
    }
    _ => abort("expected transformed enter")
  }
  match collected[1] {
    Text(text) => assert_eq(text, "ab")
    _ => abort("expected merged text")
  }
  assert_true(collected[2] is HardBreak)
  match collected[3] {
    Exit(tag) => assert_eq(tag.to_string(), "x:new")
    _ => abort("expected transformed exit")
  }
}

///|
test "sink on_finish flushes before downstream finish" {
  let seen : Array[String] = []
  let sink = @markdown.Sink(
    fn(event) {
      match event {
        Text(text) => seen.push(text)
        _ => ()
      }
    },
    finish=fn() { seen.push("finished") },
  ).on_finish(fn(downstream) { downstream.emit(Text("flushed")) })
  sink.emit(Text("body"))
  sink.finish()
  assert_eq(seen.length(), 3)
  assert_eq(seen[0], "body")
  assert_eq(seen[1], "flushed")
  assert_eq(seen[2], "finished")
}
