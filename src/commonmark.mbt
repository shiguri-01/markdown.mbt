///|
pub fn commonmark_plugin() -> Plugin {
  Plugin::new("commonmark")
  .add(
    Rule::source_core(
      "cm:core:reference_definitions",
      priority=100,
      resolve_reference_definitions,
    ),
  )
  .add(Rule::block("cm:block:blank", priority=100, cm_blank_block))
  .add(Rule::block("cm:block:fenced_code", priority=90, cm_fenced_code_block))
  .add(
    Rule::block("cm:block:indented_code", priority=80, cm_indented_code_block),
  )
  .add(
    Rule::block("cm:block:thematic_break", priority=70, cm_thematic_break_block),
  )
  .add(
    Rule::block("cm:block:setext_heading", priority=68, cm_setext_heading_block),
  )
  .add(Rule::block("cm:block:html", priority=65, cm_html_block))
  .add(Rule::block("cm:block:atx_heading", priority=60, cm_atx_heading_block))
  .add(Rule::block("cm:block:block_quote", priority=50, cm_blockquote_block))
  .add(Rule::block("cm:block:list", priority=40, cm_list_block))
  .add(Rule::block("cm:block:paragraph", priority=0, cm_paragraph_block))
  .add(Rule::inline("cm:inline:image", priority=90, cm_image_inline))
  .add(Rule::inline("cm:inline:link", priority=80, cm_link_inline))
  .add(Rule::inline("cm:inline:autolink", priority=75, cm_autolink_inline))
  .add(Rule::inline("cm:inline:raw_html", priority=74, cm_raw_html_inline))
  .add(Rule::inline("cm:inline:entity", priority=73, cm_entity_inline))
  .add(Rule::inline("cm:inline:code_span", priority=70, cm_code_span_inline))
  .add(
    Rule::delimiter("cm:delimiter:emphasis", priority=60, cm_emphasis_delimiter),
  )
  .add(Rule::inline("cm:inline:hard_break", priority=45, cm_hard_break_inline))
  .add(Rule::inline("cm:inline:escape", priority=40, cm_escape_inline))
  .add(Rule::inline("cm:inline:soft_break", priority=20, cm_soft_break_inline))
  .add(Rule::inline("cm:inline:text", priority=-1000, cm_text_inline))
}
