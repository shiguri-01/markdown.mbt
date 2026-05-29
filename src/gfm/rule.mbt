///|
/// Returns the GitHub Flavored Markdown rule.
///
/// The rule starts from CommonMark and adds GFM tables, task list items,
/// strikethrough, extended autolinks, and tag filtering.
pub fn rule() -> @markdown.Rule {
  @commonmark.rule().extend(extension())
}

///|
/// Returns only the GFM extension rules.
pub fn extension() -> @markdown.Rule {
  @markdown.Rule("gfm")
  .extend(
    @markdown.Rule::block(
      @markdown.RuleName::raw("gfm:block:table"),
      priority=67,
      table_block,
    ),
  )
  .extend(
    @markdown.Rule::delimiter(
      @markdown.RuleName::raw("gfm:delimiter:strikethrough"),
      priority=61,
      triggers="~",
      strikethrough_delimiter,
    ),
  )
  .extend(
    @markdown.Rule::core(
      @markdown.RuleName::raw("gfm:core:task_list"),
      priority=20,
      task_list_core,
    ),
  )
  .extend(
    @markdown.Rule::core(
      @markdown.RuleName::raw("gfm:core:extended_autolink"),
      priority=10,
      extended_autolink_core,
    ),
  )
  .extend(
    @markdown.Rule::core(
      @markdown.RuleName::raw("gfm:core:tagfilter"),
      priority=0,
      tagfilter_core,
    ),
  )
}
