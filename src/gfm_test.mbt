///|
test "gfm strikethrough renders del" {
  assert_eq(
    render_gfm_html(@gfm.rule(), "before ~~gone~~ after"),
    "<p>before <del>gone</del> after</p>\n",
  )
}

///|
test "gfm task list items render disabled checkboxes" {
  assert_eq(
    render_gfm_html(@gfm.rule(), "- [x] done\n- [ ] todo\n"),
    "<ul>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> done</li>\n<li><input disabled=\"\" type=\"checkbox\"> todo</li>\n</ul>\n",
  )
}

///|
test "gfm tables render alignments and body rows" {
  assert_eq(
    render_gfm_html(
      @gfm.rule(),
      "| left | center | right |\n| :--- | :---: | ---: |\n| a | b | c |\n",
    ),
    "<table>\n<thead>\n<tr>\n<th align=\"left\">left</th>\n<th align=\"center\">center</th>\n<th align=\"right\">right</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td align=\"left\">a</td>\n<td align=\"center\">b</td>\n<td align=\"right\">c</td>\n</tr>\n</tbody>\n</table>\n",
  )
}

///|
test "gfm tables pad missing cells and ignore excess cells" {
  assert_eq(
    render_gfm_html(
      @gfm.rule(),
      "| a | b |\n| --- | --- |\n| one |\n| x | y | z |\n",
    ),
    "<table>\n<thead>\n<tr>\n<th>a</th>\n<th>b</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>one</td>\n<td></td>\n</tr>\n<tr>\n<td>x</td>\n<td>y</td>\n</tr>\n</tbody>\n</table>\n",
  )
}

///|
test "gfm extended autolinks render urls and emails" {
  assert_eq(
    render_gfm_html(
      @gfm.rule(),
      "Visit www.commonmark.org/help and contact foo@example.com.",
    ),
    "<p>Visit <a href=\"http://www.commonmark.org/help\">www.commonmark.org/help</a> and contact <a href=\"mailto:foo@example.com\">foo@example.com</a>.</p>\n",
  )
}

///|
test "gfm extended autolinks trim trailing punctuation" {
  assert_eq(
    render_gfm_html(@gfm.rule(), "Visit www.commonmark.org."),
    "<p>Visit <a href=\"http://www.commonmark.org\">www.commonmark.org</a>.</p>\n",
  )
}

///|
test "gfm tagfilter escapes disallowed raw html tags" {
  assert_eq(
    render_gfm_html(@gfm.rule(), "<strong> <title> <style> <em>\n"),
    "<p><strong> &lt;title> &lt;style> <em></p>\n",
  )
}

///|
test "gfm extensions can be enabled individually" {
  let table_only = @commonmark.rule().extend(@gfm.tables())
  assert_eq(
    render_gfm_html(
      table_only, "| a |\n| - |\n| b |\n\n~~x~~ www.example.com\n",
    ),
    "<table>\n<thead>\n<tr>\n<th>a</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>b</td>\n</tr>\n</tbody>\n</table>\n<p>~~x~~ www.example.com</p>\n",
  )
  let strike_and_link = @commonmark.rule()
    .extend(@gfm.strikethrough())
    .extend(@gfm.autolinks())
  assert_eq(
    render_gfm_html(strike_and_link, "~~x~~ www.example.com"),
    "<p><del>x</del> <a href=\"http://www.example.com\">www.example.com</a></p>\n",
  )
}

///|
test "gfm task list and tagfilter extensions can be enabled individually" {
  assert_eq(
    render_gfm_html(
      @commonmark.rule().extend(@gfm.task_list_items()),
      "- [x] done\n",
    ),
    "<ul>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> done</li>\n</ul>\n",
  )
  assert_eq(
    render_gfm_html(
      @commonmark.rule().extend(@gfm.tagfilter()),
      "<script>x</script>\n",
    ),
    "&lt;script>x&lt;/script>\n",
  )
}

///|
test "gfm task list checkbox html belongs to gfm renderers" {
  assert_eq(
    render_html(
      @commonmark.rule().extend(@gfm.task_list_items()),
      "- [x] done\n",
    ),
    "<ul>\n<li>done</li>\n</ul>\n",
  )
  assert_eq(
    render_gfm_html(
      @commonmark.rule().extend(@gfm.task_list_items()),
      "- [x] done\n",
    ),
    "<ul>\n<li><input checked=\"\" disabled=\"\" type=\"checkbox\"> done</li>\n</ul>\n",
  )
}
