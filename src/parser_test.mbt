///|
fn repeated_paragraphs(count : Int) -> String {
  let out = StringBuilder::new()
  for i in 0..<count {
    out.write_string("padding line ")
    out.write_string(i.to_string())
    out.write_string("\n\n")
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
  let small_html = render_html(@markdown.commonmark(), small)
  let large_html = render_html(@markdown.commonmark(), large)
  assert_true(
    small_html.has_suffix("<p><a href=\"/url\" title=\"title\">ref</a></p>\n"),
  )
  assert_true(
    large_html.has_suffix("<p><a href=\"/url\" title=\"title\">ref</a></p>\n"),
  )
}
