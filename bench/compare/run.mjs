#!/usr/bin/env bun
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import MarkdownIt from "markdown-it";

const root = process.cwd();
const outDir = path.join(root, "bench", "compare", ".generated");
const fixtureDir = path.join(outDir, "fixtures");
const moonRunner = path.join(
  root,
  "bench",
  "compare",
  "markdown_html",
  "_build",
  "native",
  "release",
  "build",
  "markdown-html.exe",
);

function readmeLikeDocumentSections(count) {
  const out = [];
  out.push("# markdown.mbt\n\n");
  out.push(
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling, " +
      "rule hooks, and HTML rendering.\n\n",
  );
  out.push("## Installation\n\n");
  out.push("```moonbit\n");
  out.push("let html = @markdown.Html::new()\n");
  out.push("@markdown.Processor::new().parse(source, html.sink())\n");
  out.push("```\n\n");
  out.push("## Features\n\n");
  for (let i = 0; i < count; i += 1) {
    out.push(`### Feature area ${i}\n\n`);
    out.push(
      "This section documents parser behavior for paragraphs, lists, links, code spans, " +
        "and extension rules. ",
    );
    out.push(
      "It includes `inline code`, *emphasis*, **strong text**, and " +
        `[cross references](#feature-area-${i}).\n\n`,
    );
    out.push("- Parse source into a stable event stream.\n");
    out.push("- Render known CommonMark nodes to HTML.\n");
    out.push("- Preserve extension elements for downstream tools.\n\n");
    out.push("> Note: rules can add new rules without changing the default preset.\n\n");
  }
  return out.join("");
}

function issueThreadDocumentComments(count) {
  const out = ["# Parser regression discussion\n\n"];
  for (let i = 0; i < count; i += 1) {
    out.push(`## Comment ${i}\n\n`);
    out.push(
      "The failing input combines blockquotes, list items, escaped punctuation, " +
        "and reference links in one report.\n\n",
    );
    out.push(
      "> Expected output should keep `code` intact and avoid merging unrelated paragraphs.\n\n",
    );
    out.push("- [ ] reproduce with native backend\n");
    out.push("- [x] add a focused regression test\n");
    out.push("- [ ] compare against the rendered HTML output\n\n");
    out.push("```text\n");
    out.push(`line ${i}: *literal* [label][ref] <span>html</span>\n`);
    out.push("```\n\n");
  }
  out.push('[ref]: /issues/parser-regression "parser regression"\n');
  return out.join("");
}

function fixtures() {
  return new Map([
    ["readme_like_16kb", readmeLikeDocumentSections(36)],
    ["readme_like_200kb", readmeLikeDocumentSections(460)],
    ["issue_thread_25kb", issueThreadDocumentComments(64)],
    ["issue_thread_200kb", issueThreadDocumentComments(509)],
  ]);
}

function parseArgs(argv) {
  let repeats = 10;
  let warmups = 3;
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === "--repeats") {
      if (i + 1 >= argv.length) {
        throw new Error("--repeats requires a value");
      }
      repeats = Number.parseInt(argv[i + 1], 10);
      i += 1;
    } else if (argv[i] === "--warmups") {
      if (i + 1 >= argv.length) {
        throw new Error("--warmups requires a value");
      }
      warmups = Number.parseInt(argv[i + 1], 10);
      i += 1;
    } else if (argv[i] === "-h" || argv[i] === "--help") {
      console.log("usage: markdown-compare [--repeats N] [--warmups N]");
      process.exit(0);
    } else {
      throw new Error(`unknown argument: ${argv[i]}`);
    }
  }
  if (!Number.isInteger(repeats) || repeats < 1) {
    throw new Error("--repeats must be at least 1");
  }
  if (!Number.isInteger(warmups) || warmups < 0) {
    throw new Error("--warmups must be at least 0");
  }
  return { repeats, warmups };
}

function run(command, args) {
  const result = Bun.spawnSync([command, ...args], {
    cwd: root,
    stdout: "ignore",
    stderr: "pipe",
    env: { ...process.env, LC_ALL: "C" },
  });
  if (!result.success) {
    const stderr = new TextDecoder().decode(result.stderr);
    throw new Error(`${command} failed with exit code ${result.exitCode}\n${stderr}`);
  }
}

function buildMoonRunner() {
  run("moon", [
    "-C",
    path.join(root, "bench", "compare", "markdown_html"),
    "build",
    "--target",
    "native",
    "--release",
  ]);
  if (!fs.existsSync(moonRunner)) {
    throw new Error(`MoonBit runner was not built at ${moonRunner}`);
  }
}

function timedExternal(command, args, repeats, warmups) {
  for (let i = 0; i < warmups; i += 1) {
    run(command, args);
  }
  const times = [];
  for (let i = 0; i < repeats; i += 1) {
    const start = Bun.nanoseconds();
    run(command, args);
    times.push(Number(Bun.nanoseconds() - start) / 1_000_000);
  }
  return times;
}

function timedMarkdownIt(md, input, repeats, warmups) {
  for (let i = 0; i < warmups; i += 1) {
    const html = md.render(input);
    if (html.length === 0) {
      throw new Error("markdown-it produced empty output");
    }
  }
  const times = [];
  for (let i = 0; i < repeats; i += 1) {
    const start = Bun.nanoseconds();
    const html = md.render(input);
    if (html.length === 0) {
      throw new Error("markdown-it produced empty output");
    }
    times.push(Number(Bun.nanoseconds() - start) / 1_000_000);
  }
  return times;
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function printTable(rows) {
  console.log("| parser | fixture | bytes | mean ms | min ms | max ms |");
  console.log("| --- | --- | ---: | ---: | ---: | ---: |");
  for (const row of rows) {
    console.log(
      `| ${row.parser} | ${row.fixture} | ${row.bytes} | ${mean(row.times).toFixed(2)} | ` +
        `${Math.min(...row.times).toFixed(2)} | ${Math.max(...row.times).toFixed(2)} |`,
    );
  }
}

function writeFixtures(sourceFixtures) {
  fs.mkdirSync(fixtureDir, { recursive: true });
  const written = [];
  for (const [name, input] of sourceFixtures) {
    const file = path.join(fixtureDir, `${name}.md`);
    fs.writeFileSync(file, input, "utf8");
    written.push({ name, input, file, bytes: Buffer.byteLength(input) });
  }
  return written;
}

function main() {
  const { repeats, warmups } = parseArgs(process.argv);
  buildMoonRunner();
  const sourceFixtures = writeFixtures(fixtures());
  const md = new MarkdownIt("commonmark", {
    html: true,
    linkify: false,
    typographer: false,
  });

  const rows = [];
  for (const fixture of sourceFixtures) {
    rows.push({
      parser: "markdown.mbt",
      fixture: fixture.name,
      bytes: fixture.bytes,
      times: timedExternal(moonRunner, [fixture.name], repeats, warmups),
    });
    rows.push({
      parser: "cmark",
      fixture: fixture.name,
      bytes: fixture.bytes,
      times: timedExternal("cmark", [fixture.file], repeats, warmups),
    });
    rows.push({
      parser: "markdown-it/bun",
      fixture: fixture.name,
      bytes: fixture.bytes,
      times: timedMarkdownIt(md, fixture.input, repeats, warmups),
    });
  }
  printTable(rows);
}

main();
