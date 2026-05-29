///|
test "block quotes preserve lazy nested and reference content" {
  assert_eq(
    render_html(
      @commonmark.rule(),
      "> lazy\ncontinuation\n\n> > nested\n\n> [q]: /q\n> [q]\n",
    ),
    "<blockquote>\n<p>lazy\ncontinuation</p>\n</blockquote>\n<blockquote>\n<blockquote>\n<p>nested</p>\n</blockquote>\n</blockquote>\n<blockquote>\n<p><a href=\"/q\">q</a></p>\n</blockquote>\n",
  )
}
