///|
/// Returns the GitHub Flavored Markdown rule.
///
/// The rule starts from CommonMark and adds GFM tables, task list items,
/// strikethrough, extended autolinks, and tag filtering.
pub fn rule() -> @markdown.Rule {
  @commonmark.rule().extend(extensions())
}

///|
/// Returns only the GFM extension rules.
pub fn extensions() -> @markdown.Rule {
  @markdown.Rule("gfm")
  .extend(tables())
  .extend(strikethrough())
  .extend(task_list_items())
  .extend(autolinks())
  .extend(tagfilter())
}

///|
/// Returns only the GFM tables extension rule.
pub fn tables() -> @markdown.Rule {
  @markdown.Rule::block(
    @markdown.RuleName::raw("gfm:block:table"),
    priority=67,
    table_block,
  )
}

///|
/// Returns only the GFM strikethrough extension rule.
pub fn strikethrough() -> @markdown.Rule {
  @markdown.Rule::delimiter(
    @markdown.RuleName::raw("gfm:delimiter:strikethrough"),
    priority=61,
    triggers="~",
    strikethrough_delimiter,
  )
}

///|
/// Returns only the GFM task list items extension rule.
pub fn task_list_items() -> @markdown.Rule {
  @markdown.Rule::core(
    @markdown.RuleName::raw("gfm:core:task_list"),
    priority=20,
    task_list_core,
  )
}

///|
/// Returns only the GFM extended autolinks extension rule.
pub fn autolinks() -> @markdown.Rule {
  @markdown.Rule::core(
    @markdown.RuleName::raw("gfm:core:extended_autolink"),
    priority=10,
    extended_autolink_core,
  )
}

///|
/// Returns only the GFM disallowed raw HTML tag filter extension rule.
pub fn tagfilter() -> @markdown.Rule {
  @markdown.Rule::core(
    @markdown.RuleName::raw("gfm:core:tagfilter"),
    priority=0,
    tagfilter_core,
  )
}
