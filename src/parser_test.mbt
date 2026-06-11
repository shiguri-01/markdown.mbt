///|
fn repeated_paragraphs(count : Int) -> String {
  let out = StringBuilder::new()
  for i in 0..<count {
    out <+ "padding line "
    out <+ "\{i}"
    out <+ "\n\n"
  }
  out.to_string()
}

///|
test "canonical parser path is independent of input size" {
  let sample =
    #|# Title
    #|
    #|> quote with [ref]
    #|
    #|- item
    #|- second
    #|
    #|```txt
    #|[ref]: /not-a-definition
    #|```
    #|
    #|[ref]: /url "title"
    #|
  let small = sample + "[ref]\n"
  let large = sample + repeated_paragraphs(900) + "[ref]\n"
  let small_html = render_html(@commonmark.rule(), small)
  let large_html = render_html(@commonmark.rule(), large)
  assert_true(
    small_html.has_suffix("<p><a href=\"/url\" title=\"title\">ref</a></p>\n"),
  )
  assert_true(
    large_html.has_suffix("<p><a href=\"/url\" title=\"title\">ref</a></p>\n"),
  )
}
