///|
test "lists preserve tight loose and normalized child blocks" {
  assert_eq(
    render_html(@markdown.commonmark(), "- tight\n  continuation\n- next\n"),
    "<ul>\n<li>tight\ncontinuation</li>\n<li>next</li>\n</ul>\n",
  )
  assert_eq(
    render_html(@markdown.commonmark(), "- loose\n\n  continuation\n"),
    "<ul>\n<li>\n<p>loose</p>\n<p>continuation</p>\n</li>\n</ul>\n",
  )
  assert_eq(
    render_html(
      @markdown.commonmark(),
      "- > quoted\n- ```\n  [x]: /code\n  ```\n- [x]: /real\n- [x]\n",
    ),
    "<ul>\n<li>\n<blockquote>\n<p>quoted</p>\n</blockquote>\n</li>\n<li>\n<pre><code>[x]: /code\n</code></pre>\n</li>\n<li></li>\n<li><a href=\"/real\">x</a></li>\n</ul>\n",
  )
}
