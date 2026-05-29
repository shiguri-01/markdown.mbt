///|
test "reference links resolve forward and ignore code definitions" {
  assert_eq(
    render_html(
      @commonmark.rule(),
      "[x]\n\n```md\n[x]: /code\n```\n\n[x]: /real\n",
    ),
    "<p><a href=\"/real\">x</a></p>\n<pre><code class=\"language-md\">[x]: /code\n</code></pre>\n",
  )
}

///|
test "deferred commonmark path resolves nested definitions after block parse" {
  assert_eq(
    render_html(
      @commonmark.rule(),
      "[t]\n\n[b]\n\n[l]\n\n[i]\n\n[h]\n\n[t]: /top\n\n    [i]: /code\n\n<div>\n[h]: /html\n</div>\n\n> [b]: /quote\n> [b]\n\n- [l]: /list\n- [l]\n",
    ),
    "<p><a href=\"/top\">t</a></p>\n<p><a href=\"/quote\">b</a></p>\n<p><a href=\"/list\">l</a></p>\n<p>[i]</p>\n<p>[h]</p>\n<pre><code>[i]: /code\n</code></pre>\n<div>\n[h]: /html\n</div>\n<blockquote>\n<p><a href=\"/quote\">b</a></p>\n</blockquote>\n<ul>\n<li></li>\n<li><a href=\"/list\">l</a></li>\n</ul>\n",
  )
}

///|
test "reference definitions in block quotes and lists do not emit" {
  assert_eq(
    render_html(
      @commonmark.rule(),
      "[l]\n\n> [b]: /b\n> [b]\n\n- [l]: /l\n- [l]\n",
    ),
    "<p><a href=\"/l\">l</a></p>\n<blockquote>\n<p><a href=\"/b\">b</a></p>\n</blockquote>\n<ul>\n<li></li>\n<li><a href=\"/l\">l</a></li>\n</ul>\n",
  )
}

///|
test "multiline reference labels resolve forward references" {
  assert_eq(
    render_html(@commonmark.rule(), "[foo bar]\n\n[foo\nbar]: /url\n"),
    "<p><a href=\"/url\">foo bar</a></p>\n",
  )
}

///|
test "collapsed full and image references resolve without source rewriting" {
  assert_eq(
    render_html(
      @commonmark.rule(),
      "[full][label] and [collapsed][] and ![img][label]\n\n[label]: /url\n[collapsed]: /collapsed\n",
    ),
    "<p><a href=\"/url\">full</a> and <a href=\"/collapsed\">collapsed</a> and <img src=\"/url\" alt=\"img\" /></p>\n",
  )
}

///|
test "reference definitions in code spans stay literal" {
  assert_eq(
    render_html(@commonmark.rule(), "`[x]: /code` and [x]\n\n[x]: /real\n"),
    "<p><code>[x]: /code</code> and <a href=\"/real\">x</a></p>\n",
  )
}

///|
test "duplicate reference labels keep first definition" {
  assert_eq(
    render_html(@commonmark.rule(), "[x]\n\n[x]: /first\n[x]: /second\n"),
    "<p><a href=\"/first\">x</a></p>\n",
  )
}

///|
test "normalized duplicate reference labels keep first definition" {
  assert_eq(
    render_html(
      @commonmark.rule(),
      "[foo bar]\n\n[Foo\tBar]: /first\n[foo bar]: /second\n",
    ),
    "<p><a href=\"/first\">foo bar</a></p>\n",
  )
}
