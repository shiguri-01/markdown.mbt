///|
struct CommonMarkSpecExample {
  number : Int
  category : String
  markdown : String
  html : String
}

///|
struct CommonMarkCategoryReport {
  category : String
  total : Int
  passed : Int
}

///|
fn commonmark_subset_examples() -> Array[CommonMarkSpecExample] {
  let examples = [
    {
      number: 1,
      category: "ATX headings",
      markdown: "# foo\n",
      html: "<h1>foo</h1>\n",
    },
    {
      number: 2,
      category: "ATX headings",
      markdown: "## foo ##\n",
      html: "<h2>foo</h2>\n",
    },
    {
      number: 46,
      category: "ATX headings",
      markdown: "# foo#\n",
      html: "<h1>foo#</h1>\n",
    },
    {
      number: 47,
      category: "ATX headings",
      markdown: "# foo ###   \n",
      html: "<h1>foo</h1>\n",
    },
    {
      number: 62,
      category: "ATX headings",
      markdown: "# foo ###\t\n",
      html: "<h1>foo</h1>\n",
    },
    {
      number: 55,
      category: "ATX headings",
      markdown: "#\n",
      html: "<h1></h1>\n",
    },
    {
      number: 56,
      category: "ATX headings",
      markdown: "#\tfoo\n",
      html: "<h1>foo</h1>\n",
    },
    {
      number: 114,
      category: "ATX headings",
      markdown: "   # foo\n",
      html: "<h1>foo</h1>\n",
    },
    {
      number: 115,
      category: "Indented code blocks",
      markdown: "    # foo\n",
      html: "<pre><code># foo\n</code></pre>\n",
    },
    {
      number: 3,
      category: "Setext headings",
      markdown: "Foo\n===\n",
      html: "<h1>Foo</h1>\n",
    },
    {
      number: 4,
      category: "Setext headings",
      markdown: "Foo\n---\n",
      html: "<h2>Foo</h2>\n",
    },
    {
      number: 57,
      category: "Setext headings",
      markdown: "Foo\n- - -\n",
      html: "<h2>Foo</h2>\n",
    },
    {
      number: 118,
      category: "Setext headings",
      markdown: "Foo\n   ---\n",
      html: "<h2>Foo</h2>\n",
    },
    {
      number: 5,
      category: "Paragraphs",
      markdown: "foo\nbar\n",
      html: "<p>foo\nbar</p>\n",
    },
    {
      number: 6,
      category: "Thematic breaks",
      markdown: "***\n",
      html: "<hr />\n",
    },
    {
      number: 60,
      category: "Thematic breaks",
      markdown: "-\t-\t-\n",
      html: "<hr />\n",
    },
    {
      number: 116,
      category: "Thematic breaks",
      markdown: "   ***\n",
      html: "<hr />\n",
    },
    {
      number: 117,
      category: "Indented code blocks",
      markdown: "    ***\n",
      html: "<pre><code>***\n</code></pre>\n",
    },
    {
      number: 61,
      category: "List items",
      markdown: "- -\n",
      html: "<ul>\n<li><ul>\n<li></li>\n</ul>\n</li>\n</ul>\n",
    },
    {
      number: 7,
      category: "Fenced code blocks",
      markdown: "``` moonbit\nprintln(1)\n```\n",
      html: "<pre><code class=\"language-moonbit\">println(1)\n</code></pre>\n",
    },
    {
      number: 8,
      category: "Fenced code blocks",
      markdown: "```\n<\n >\n```\n",
      html: "<pre><code>&lt;\n &gt;\n</code></pre>\n",
    },
    {
      number: 44,
      category: "Fenced code blocks",
      markdown: "````\n```\ncode\n````\n",
      html: "<pre><code>```\ncode\n</code></pre>\n",
    },
    {
      number: 45,
      category: "Fenced code blocks",
      markdown: "~~~\ncode\n~~~   \n",
      html: "<pre><code>code\n</code></pre>\n",
    },
    {
      number: 63,
      category: "Fenced code blocks",
      markdown: "```\ncode\n```\t\n",
      html: "<pre><code>code\n</code></pre>\n",
    },
    {
      number: 102,
      category: "Fenced code blocks",
      markdown: "```\ncode\n    ```\nmore\n```\n",
      html: "<pre><code>code\n    ```\nmore\n</code></pre>\n",
    },
    {
      number: 74,
      category: "Fenced code blocks",
      markdown: "  ```\n  code\n    indented\n  ```\n",
      html: "<pre><code>code\n  indented\n</code></pre>\n",
    },
    {
      number: 119,
      category: "Fenced code blocks",
      markdown: "   ```\ncode\n   ```\n",
      html: "<pre><code>code\n</code></pre>\n",
    },
    {
      number: 132,
      category: "Fenced code blocks",
      markdown: "```\ncode",
      html: "<pre><code>code\n</code></pre>\n",
    },
    {
      number: 71,
      category: "Indented code blocks",
      markdown: "    ```\n    code\n    ```\n",
      html: "<pre><code>```\ncode\n```\n</code></pre>\n",
    },
    {
      number: 72,
      category: "Fenced code blocks",
      markdown: "``` `\ncode\n```\n",
      html: "<p>``<code> </code>\ncode</p>\n<pre><code>\n</code></pre>\n",
    },
    {
      number: 9,
      category: "Indented code blocks",
      markdown: "    a\n    b\n",
      html: "<pre><code>a\nb\n</code></pre>\n",
    },
    {
      number: 43,
      category: "Indented code blocks",
      markdown: "    a\n\n    b\n",
      html: "<pre><code>a\n\nb\n</code></pre>\n",
    },
    {
      number: 79,
      category: "Indented code blocks",
      markdown: "    - item\n",
      html: "<pre><code>- item\n</code></pre>\n",
    },
    {
      number: 10,
      category: "Block quotes",
      markdown: "> # Foo\n> bar\n",
      html: "<blockquote>\n<h1>Foo</h1>\n<p>bar</p>\n</blockquote>\n",
    },
    {
      number: 11,
      category: "Block quotes",
      markdown: "> foo\nbar\n",
      html: "<blockquote>\n<p>foo\nbar</p>\n</blockquote>\n",
    },
    {
      number: 69,
      category: "Block quotes",
      markdown: ">\tfoo\n",
      html: "<blockquote>\n<p>foo</p>\n</blockquote>\n",
    },
    {
      number: 70,
      category: "Block quotes",
      markdown: ">\n",
      html: "<blockquote>\n</blockquote>\n",
    },
    {
      number: 112,
      category: "Block quotes",
      markdown: "   > quote\n",
      html: "<blockquote>\n<p>quote</p>\n</blockquote>\n",
    },
    {
      number: 113,
      category: "Indented code blocks",
      markdown: "    > quote\n",
      html: "<pre><code>&gt; quote\n</code></pre>\n",
    },
    {
      number: 12,
      category: "List items",
      markdown: "- one\n- two\n",
      html: "<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n",
    },
    {
      number: 13,
      category: "List items",
      markdown: "1. one\n2. two\n",
      html: "<ol>\n<li>one</li>\n<li>two</li>\n</ol>\n",
    },
    {
      number: 14,
      category: "List items",
      markdown: "3. three\n4. four\n",
      html: "<ol start=\"3\">\n<li>three</li>\n<li>four</li>\n</ol>\n",
    },
    {
      number: 15,
      category: "List items",
      markdown: "1) one\n2) two\n",
      html: "<ol>\n<li>one</li>\n<li>two</li>\n</ol>\n",
    },
    {
      number: 58,
      category: "List items",
      markdown: "-\n-\titem\n",
      html: "<ul>\n<li></li>\n<li>item</li>\n</ul>\n",
    },
    {
      number: 59,
      category: "List items",
      markdown: "1.\n2.\titem\n",
      html: "<ol>\n<li></li>\n<li>item</li>\n</ol>\n",
    },
    {
      number: 98,
      category: "List items",
      markdown: "1. one\n2) two\n",
      html: "<ol>\n<li>one</li>\n</ol>\n<ol start=\"2\">\n<li>two</li>\n</ol>\n",
    },
    {
      number: 99,
      category: "List items",
      markdown: "- one\n+ two\n",
      html: "<ul>\n<li>one</li>\n</ul>\n<ul>\n<li>two</li>\n</ul>\n",
    },
    {
      number: 108,
      category: "List items",
      markdown: "- one\n\n- two\n",
      html: "<ul>\n<li><p>one</p>\n</li>\n<li><p>two</p>\n</li>\n</ul>\n",
    },
    {
      number: 109,
      category: "List items",
      markdown: "1. one\n\n2. two\n",
      html: "<ol>\n<li><p>one</p>\n</li>\n<li><p>two</p>\n</li>\n</ol>\n",
    },
    {
      number: 110,
      category: "List items",
      markdown: "- one\n\n  two\n- three\n",
      html: "<ul>\n<li><p>one</p>\n<p>two</p>\n</li>\n<li><p>three</p>\n</li>\n</ul>\n",
    },
    {
      number: 111,
      category: "List items",
      markdown: "1. one\n\n   two\n2. three\n",
      html: "<ol>\n<li><p>one</p>\n<p>two</p>\n</li>\n<li><p>three</p>\n</li>\n</ol>\n",
    },
    {
      number: 16,
      category: "List items",
      markdown: "- one\n  continued\n- two\n",
      html: "<ul>\n<li>one\ncontinued</li>\n<li>two</li>\n</ul>\n",
    },
    {
      number: 42,
      category: "List items",
      markdown: "- one\nlazy continuation\n- two\n",
      html: "<ul>\n<li>one\nlazy continuation</li>\n<li>two</li>\n</ul>\n",
    },
    {
      number: 17,
      category: "List items",
      markdown: "- # heading\n",
      html: "<ul>\n<li><h1>heading</h1>\n</li>\n</ul>\n",
    },
    {
      number: 18,
      category: "List items",
      markdown: "- > quote\n",
      html: "<ul>\n<li><blockquote>\n<p>quote</p>\n</blockquote>\n</li>\n</ul>\n",
    },
    {
      number: 85,
      category: "List items",
      markdown: "paragraph\n1. item\n",
      html: "<p>paragraph</p>\n<ol>\n<li>item</li>\n</ol>\n",
    },
    {
      number: 86,
      category: "List items",
      markdown: "paragraph\n2. item\n",
      html: "<p>paragraph\n2. item</p>\n",
    },
    {
      number: 122,
      category: "List items",
      markdown: "paragraph\n    - item\n",
      html: "<p>paragraph\n    - item</p>\n",
    },
    {
      number: 123,
      category: "List items",
      markdown: "paragraph\n    1. item\n",
      html: "<p>paragraph\n    1. item</p>\n",
    },
    {
      number: 19,
      category: "Emphasis and strong emphasis",
      markdown: "This is *em* and **strong**.\n",
      html: "<p>This is <em>em</em> and <strong>strong</strong>.</p>\n",
    },
    {
      number: 20,
      category: "Emphasis and strong emphasis",
      markdown: "This is _em_ and __strong__.\n",
      html: "<p>This is <em>em</em> and <strong>strong</strong>.</p>\n",
    },
    {
      number: 21,
      category: "Emphasis and strong emphasis",
      markdown: "*a **b** c* and **a *b* c**\n",
      html: "<p><em>a <strong>b</strong> c</em> and <strong>a <em>b</em> c</strong></p>\n",
    },
    {
      number: 129,
      category: "Emphasis and strong emphasis",
      markdown: "foo_bar_baz\n",
      html: "<p>foo_bar_baz</p>\n",
    },
    {
      number: 130,
      category: "Emphasis and strong emphasis",
      markdown: "foo__bar__baz\n",
      html: "<p>foo__bar__baz</p>\n",
    },
    {
      number: 131,
      category: "Emphasis and strong emphasis",
      markdown: "*a\\*b* and _a\\_b_\n",
      html: "<p><em>a*b</em> and <em>a_b</em></p>\n",
    },
    {
      number: 133,
      category: "Emphasis and strong emphasis",
      markdown: "***strong emph*** and ___strong emph___\n",
      html: "<p><em><strong>strong emph</strong></em> and <em><strong>strong emph</strong></em></p>\n",
    },
    {
      number: 22,
      category: "Code spans",
      markdown: "` hi\nthere `\n",
      html: "<p><code>hi there</code></p>\n",
    },
    {
      number: 48,
      category: "Code spans",
      markdown: "`` foo ` bar ``\n",
      html: "<p><code>foo ` bar</code></p>\n",
    },
    {
      number: 49,
      category: "Code spans",
      markdown: "`` ` ``\n",
      html: "<p><code>`</code></p>\n",
    },
    {
      number: 50,
      category: "Code spans",
      markdown: "`a\tb`\n",
      html: "<p><code>a b</code></p>\n",
    },
    {
      number: 23,
      category: "Autolinks",
      markdown: "<https://example.com>\n",
      html: "<p><a href=\"https://example.com\">https://example.com</a></p>\n",
    },
    {
      number: 24,
      category: "Autolinks",
      markdown: "<foo@example.com>\n",
      html: "<p><a href=\"mailto:foo@example.com\">foo@example.com</a></p>\n",
    },
    {
      number: 104,
      category: "Autolinks",
      markdown: "<foo@bar/baz.com>\n",
      html: "<p>&lt;foo@bar/baz.com&gt;</p>\n",
    },
    {
      number: 105,
      category: "Autolinks",
      markdown: "<foo@-bar.com>\n",
      html: "<p>&lt;foo@-bar.com&gt;</p>\n",
    },
    {
      number: 77,
      category: "Autolinks",
      markdown: "<HTTP://EXAMPLE.COM>\n",
      html: "<p><a href=\"HTTP://EXAMPLE.COM\">HTTP://EXAMPLE.COM</a></p>\n",
    },
    {
      number: 78,
      category: "Autolinks",
      markdown: "<http://example.com/a b>\n",
      html: "<p>&lt;http://example.com/a b&gt;</p>\n",
    },
    {
      number: 103,
      category: "Autolinks",
      markdown: "<http://example.com/<x>>\n",
      html: "<p>&lt;http://example.com/<x>&gt;</p>\n",
    },
    {
      number: 25,
      category: "Raw HTML",
      markdown: "This is <span>raw</span>.\n",
      html: "<p>This is <span>raw</span>.</p>\n",
    },
    {
      number: 39,
      category: "Raw HTML",
      markdown: "a <!-- raw --> b\n",
      html: "<p>a <!-- raw --> b</p>\n",
    },
    {
      number: 64,
      category: "Raw HTML",
      markdown: "This is <span\tclass=\"x\">raw</span>.\n",
      html: "<p>This is <span\tclass=\"x\">raw</span>.</p>\n",
    },
    {
      number: 65,
      category: "Raw HTML",
      markdown: "This is <span raw\n",
      html: "<p>This is &lt;span raw</p>\n",
    },
    {
      number: 106,
      category: "Raw HTML",
      markdown: "</span class=\"x\">\n",
      html: "<p>&lt;/span class=&quot;x&quot;&gt;</p>\n",
    },
    {
      number: 26,
      category: "HTML blocks",
      markdown: "<div>\nraw\n</div>\n",
      html: "<div>\nraw\n</div>\n",
    },
    {
      number: 66,
      category: "HTML blocks",
      markdown: "<div\tclass=\"x\">\nraw\n",
      html: "<div\tclass=\"x\">\nraw\n",
    },
    {
      number: 100,
      category: "HTML blocks",
      markdown: "<DIV>\nraw\n</DIV>\n",
      html: "<DIV>\nraw\n</DIV>\n",
    },
    {
      number: 101,
      category: "HTML blocks",
      markdown: "<H1>\nraw\n</H1>\n",
      html: "<H1>\nraw\n</H1>\n",
    },
    {
      number: 120,
      category: "HTML blocks",
      markdown: "   <div>\nraw\n",
      html: "   <div>\nraw\n",
    },
    {
      number: 121,
      category: "Indented code blocks",
      markdown: "    <div>\n",
      html: "<pre><code>&lt;div&gt;\n</code></pre>\n",
    },
    {
      number: 40,
      category: "HTML blocks",
      markdown: "<!--\nraw\n-->\ntext\n",
      html: "<!--\nraw\n-->\n<p>text</p>\n",
    },
    {
      number: 41,
      category: "HTML blocks",
      markdown: "<!DOCTYPE html>\ntext\n",
      html: "<!DOCTYPE html>\n<p>text</p>\n",
    },
    {
      number: 27,
      category: "Links and images",
      markdown: "[link](/url) ![alt](/img.png)\n",
      html: "<p><a href=\"/url\">link</a> <img src=\"/img.png\" alt=\"alt\" /></p>\n",
    },
    {
      number: 28,
      category: "Links and images",
      markdown: "[link](/url \"title\") ![alt](/img.png \"title\")\n",
      html: "<p><a href=\"/url\" title=\"title\">link</a> <img src=\"/img.png\" alt=\"alt\" title=\"title\" /></p>\n",
    },
    {
      number: 51,
      category: "Links and images",
      markdown: "[link](/url(foo))\n",
      html: "<p><a href=\"/url(foo)\">link</a></p>\n",
    },
    {
      number: 52,
      category: "Links and images",
      markdown: "![alt](/img(foo).png)\n",
      html: "<p><img src=\"/img(foo).png\" alt=\"alt\" /></p>\n",
    },
    {
      number: 53,
      category: "Links and images",
      markdown: "[link](/url 'title')\n",
      html: "<p><a href=\"/url\" title=\"title\">link</a></p>\n",
    },
    {
      number: 54,
      category: "Links and images",
      markdown: "![alt](/img.png (title))\n",
      html: "<p><img src=\"/img.png\" alt=\"alt\" title=\"title\" /></p>\n",
    },
    {
      number: 75,
      category: "Links and images",
      markdown: "![a\\*b &amp; c](/img.png)\n",
      html: "<p><img src=\"/img.png\" alt=\"a*b &amp; c\" /></p>\n",
    },
    {
      number: 76,
      category: "Links and images",
      markdown: "[link](/a\\*b?x=&amp; \"a\\*b &amp; c\")\n",
      html: "<p><a href=\"/a*b?x=&amp;\" title=\"a*b &amp; c\">link</a></p>\n",
    },
    {
      number: 80,
      category: "Links and images",
      markdown: "[link](/url\t\"title\") ![alt](/img.png\t'title')\n",
      html: "<p><a href=\"/url\" title=\"title\">link</a> <img src=\"/img.png\" alt=\"alt\" title=\"title\" /></p>\n",
    },
    {
      number: 126,
      category: "Links and images",
      markdown: "[link](/url \"a\\\"b\")\n",
      html: "<p><a href=\"/url\" title=\"a&quot;b\">link</a></p>\n",
    },
    {
      number: 127,
      category: "Links and images",
      markdown: "[link](/url \"title\\\")\n",
      html: "<p>[link](/url &quot;title&quot;)</p>\n",
    },
    {
      number: 82,
      category: "Links and images",
      markdown: "[link]() ![alt]()\n",
      html: "<p><a href=\"\">link</a> <img src=\"\" alt=\"alt\" /></p>\n",
    },
    {
      number: 83,
      category: "Links and images",
      markdown: "[link](<foo bar>) ![alt](<img file.png> \"title\")\n",
      html: "<p><a href=\"foo bar\">link</a> <img src=\"img file.png\" alt=\"alt\" title=\"title\" /></p>\n",
    },
    {
      number: 87,
      category: "Links and images",
      markdown: "[link](foo bar) ![alt](img file.png)\n",
      html: "<p>[link](foo bar) ![alt](img file.png)</p>\n",
    },
    {
      number: 107,
      category: "Links and images",
      markdown: "[link](foo\\ bar) ![alt](img\\ file.png)\n",
      html: "<p>[link](foo\\ bar) ![alt](img\\ file.png)</p>\n",
    },
    {
      number: 124,
      category: "Links and images",
      markdown: "[link](<foo<bar>>) ![alt](<img>.png>)\n",
      html: "<p>[link](&lt;foo<bar>&gt;) ![alt](<img>.png&gt;)</p>\n",
    },
    {
      number: 89,
      category: "Links and images",
      markdown: "[a [b]](/url) ![a [b]](/img.png)\n",
      html: "<p><a href=\"/url\">a [b]</a> <img src=\"/img.png\" alt=\"a [b]\" /></p>\n",
    },
    {
      number: 96,
      category: "Links and images",
      markdown: "[a \\] b](/url) ![a \\] b](/img.png)\n",
      html: "<p><a href=\"/url\">a ] b</a> <img src=\"/img.png\" alt=\"a ] b\" /></p>\n",
    },
    {
      number: 134,
      category: "Links and images",
      markdown: "![*em* **strong** `code`](/img.png)\n",
      html: "<p><img src=\"/img.png\" alt=\"em strong code\" /></p>\n",
    },
    {
      number: 29,
      category: "Link reference definitions",
      markdown: "[foo]: /url \"title\"\n\n[foo]\n",
      html: "<p><a href=\"/url\" title=\"title\">foo</a></p>\n",
    },
    {
      number: 30,
      category: "Link reference definitions",
      markdown: "[Foo Bar]: /url\n\n[link][foo bar]\n",
      html: "<p><a href=\"/url\">link</a></p>\n",
    },
    {
      number: 36,
      category: "Link reference definitions",
      markdown: "[img]: /img.png \"title\"\n\n![alt][img]\n",
      html: "<p><img src=\"/img.png\" alt=\"alt\" title=\"title\" /></p>\n",
    },
    {
      number: 37,
      category: "Link reference definitions",
      markdown: "[alt]: /img.png\n\n![alt]\n",
      html: "<p><img src=\"/img.png\" alt=\"alt\" /></p>\n",
    },
    {
      number: 73,
      category: "Link reference definitions",
      markdown: "[foo]: /url\n  'title'\n\n[foo]\n",
      html: "<p><a href=\"/url\" title=\"title\">foo</a></p>\n",
    },
    {
      number: 81,
      category: "Link reference definitions",
      markdown: "[foo]: /url\t\"title\"\n\n[foo]\n",
      html: "<p><a href=\"/url\" title=\"title\">foo</a></p>\n",
    },
    {
      number: 84,
      category: "Link reference definitions",
      markdown: "[foo]: <foo bar> \"title\"\n\n[foo]\n",
      html: "<p><a href=\"foo bar\" title=\"title\">foo</a></p>\n",
    },
    {
      number: 88,
      category: "Link reference definitions",
      markdown: "[foo]: /url\n  \"a\\*b &amp; c\"\n\n[foo]\n",
      html: "<p><a href=\"/url\" title=\"a*b &amp; c\">foo</a></p>\n",
    },
    {
      number: 90,
      category: "Link reference definitions",
      markdown: "[id]: /url\n\n[a [b]][id]\n",
      html: "<p><a href=\"/url\">a [b]</a></p>\n",
    },
    {
      number: 91,
      category: "Link reference definitions",
      markdown: "[a [b]]: /url\n\n[a [b]]\n",
      html: "<p><a href=\"/url\">a [b]</a></p>\n",
    },
    {
      number: 92,
      category: "Link reference definitions",
      markdown: "[foo]: <> \"title\"\n\n[foo]\n",
      html: "<p><a href=\"\" title=\"title\">foo</a></p>\n",
    },
    {
      number: 93,
      category: "Link reference definitions",
      markdown: "[a\\*b &amp; c]: /url\n\n[a*b & c]\n",
      html: "<p><a href=\"/url\">a*b &amp; c</a></p>\n",
    },
    {
      number: 125,
      category: "Link reference definitions",
      markdown: "[foo]: <foo<bar>>\n\n[foo]\n",
      html: "<p>[foo]: &lt;foo<bar>&gt;</p>\n<p>[foo]</p>\n",
    },
    {
      number: 128,
      category: "Link reference definitions",
      markdown: "[foo]: /url \"title\\\"\n\n[foo]\n",
      html: "<p>[foo]: /url &quot;title&quot;</p>\n<p>[foo]</p>\n",
    },
    {
      number: 94,
      category: "Link reference definitions",
      markdown: "[id [x]]: /url\n\n[text][id [x]]\n",
      html: "<p><a href=\"/url\">text</a></p>\n",
    },
    {
      number: 95,
      category: "Link reference definitions",
      markdown: "[id [x]]: /img.png\n\n![alt][id [x]]\n",
      html: "<p><img src=\"/img.png\" alt=\"alt\" /></p>\n",
    },
    {
      number: 97,
      category: "Link reference definitions",
      markdown: "[id \\] x]: /url\n\n[text][id \\] x]\n",
      html: "<p><a href=\"/url\">text</a></p>\n",
    },
    {
      number: 31,
      category: "Backslash escapes",
      markdown: "\\*literal\\*\n",
      html: "<p>*literal*</p>\n",
    },
    {
      number: 32,
      category: "Backslash escapes",
      markdown: "\\a\n",
      html: "<p>\\a</p>\n",
    },
    {
      number: 33,
      category: "Backslash escapes",
      markdown: "\\! ok and \\a literal\n",
      html: "<p>! ok and \\a literal</p>\n",
    },
    {
      number: 34,
      category: "Hard line breaks",
      markdown: "a  \nb\n",
      html: "<p>a<br />\nb</p>\n",
    },
    {
      number: 35,
      category: "Hard line breaks",
      markdown: "a\\\nb\n",
      html: "<p>a<br />\nb</p>\n",
    },
    {
      number: 67,
      category: "Hard line breaks",
      markdown: "a   \nb\n",
      html: "<p>a<br />\nb</p>\n",
    },
    {
      number: 68,
      category: "Hard line breaks",
      markdown: "a \nb\n",
      html: "<p>a \nb</p>\n",
    },
    {
      number: 38,
      category: "Character references",
      markdown: "&amp; &lt; &#42; &#x2A; &unknown;\n",
      html: "<p>&amp; &lt; * * &amp;unknown;</p>\n",
    },
  ]
  examples
}

///|
fn render_commonmark(markdown : String) -> String {
  @markdown.to_html(@markdown.parse(markdown))
}

///|
fn commonmark_category_report(
  examples : Array[CommonMarkSpecExample],
) -> Array[CommonMarkCategoryReport] {
  let reports : Array[CommonMarkCategoryReport] = []
  for example in examples {
    let mut index = find_category_report(reports, example.category)
    if index < 0 {
      reports.push({ category: example.category, total: 0, passed: 0 })
      index = reports.length() - 1
    }
    let report = reports[index]
    let passed_delta = if render_commonmark(example.markdown) == example.html {
      1
    } else {
      0
    }
    reports[index] = {
      category: report.category,
      total: report.total + 1,
      passed: report.passed + passed_delta,
    }
  }
  reports
}

///|
fn find_category_report(
  reports : Array[CommonMarkCategoryReport],
  category : String,
) -> Int {
  for i in 0..<reports.length() {
    if reports[i].category == category {
      return i
    }
  }
  -1
}

///|
test "CommonMark subset examples render expected HTML" {
  let seen : Array[Int] = []
  for example in commonmark_subset_examples() {
    assert_true(example.number > 0)
    assert_true(!contains_int(seen, example.number))
    seen.push(example.number)
    assert_eq(render_commonmark(example.markdown), example.html)
  }
}

///|
fn contains_int(items : Array[Int], needle : Int) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}

///|
test "CommonMark subset pass rate is available by category" {
  let reports = commonmark_category_report(commonmark_subset_examples())
  assert_eq(reports.length(), 18)
  for report in reports {
    assert_eq(report.passed, report.total)
  }
}

///|
test "CommonMark subset parser events build AST" {
  for example in commonmark_subset_examples() {
    let events = @markdown.Processor::commonmark()
      .parse(example.markdown)
      .collect()
    match @markdown.AstBuilder::new().build(events) {
      Ok(_) => ()
      Err(_) => abort("parser-generated events should build AST")
    }
  }
}
