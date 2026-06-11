#!/usr/bin/env bun
import { mkdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import MarkdownIt from "markdown-it";

type Args = {
  repeats: number;
  warmups: number;
};

type WrittenFixture = {
  name: string;
  input: string;
  file: string;
  bytes: number;
};

type ResultRow = {
  parser: string;
  fixture: string;
  bytes: number;
  times: number[];
};

const root = process.cwd();
const markdownHtmlPackage = path.join(
  root,
  "src",
  "tools",
  "benchmarks",
  "compare",
  "markdown_html",
);
const outDir = path.join(
  root,
  "src",
  "tools",
  "benchmarks",
  "compare",
  ".generated",
);
const fixtureDir = path.join(outDir, "fixtures");
const moonNativeRunner = path.join(
  root,
  "_build",
  "native",
  "release",
  "build",
  "tools",
  "benchmarks",
  "compare",
  "markdown_html",
  "markdown_html.exe",
);
const moonWasmRunner = path.join(
  root,
  "_build",
  "wasm-gc",
  "release",
  "build",
  "tools",
  "benchmarks",
  "compare",
  "markdown_html",
  "markdown_html.wasm",
);

function readmeLikeDocumentSections(count: number): string {
  const out: string[] = [];
  out.push("# markdown.mbt\n\n");
  out.push(
    "A MoonBit Markdown parser with CommonMark-compatible block and inline handling, " +
      "rule hooks, and HTML rendering.\n\n",
  );
  out.push("## Installation\n\n");
  out.push("```moonbit\n");
  out.push("let html = @markdown.Html(@commonmark.html_renderers())\n");
  out.push("@markdown.Processor(@commonmark.rule()).parse(source, html.sink())\n");
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
    out.push("> Note: rules can add new rules without changing the default rule.\n\n");
  }
  return out.join("");
}

function issueThreadDocumentComments(count: number): string {
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

function fixtures(): Map<string, string> {
  return new Map([
    ["readme_like_16kb", readmeLikeDocumentSections(36)],
    ["readme_like_200kb", readmeLikeDocumentSections(460)],
    ["issue_thread_25kb", issueThreadDocumentComments(64)],
    ["issue_thread_200kb", issueThreadDocumentComments(509)],
  ]);
}

function parseArgs(argv: string[]): Args {
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

function decode(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}

function run(command: string, args: string[]): void {
  const result = Bun.spawnSync({
    cmd: [command, ...args],
    cwd: root,
    stdout: "ignore",
    stderr: "pipe",
    env: { ...Bun.env, LC_ALL: "C" },
  });
  if (!result.success) {
    throw new Error(`${command} failed with exit code ${result.exitCode}\n${decode(result.stderr)}`);
  }
}

function runCapture(command: string, args: string[]): string {
  const result = Bun.spawnSync({
    cmd: [command, ...args],
    cwd: root,
    stdout: "pipe",
    stderr: "pipe",
    env: { ...Bun.env, LC_ALL: "C" },
  });
  if (!result.success) {
    throw new Error(`${command} failed with exit code ${result.exitCode}\n${decode(result.stderr)}`);
  }
  return decode(result.stdout);
}

async function assertFileExists(file: string, label: string): Promise<void> {
  if (!(await Bun.file(file).exists())) {
    throw new Error(`${label} was not built at ${file}`);
  }
}

async function buildMoonRunners(): Promise<void> {
  run("moon", [
    "build",
    markdownHtmlPackage,
    "--target",
    "native",
    "--release",
  ]);
  run("moon", [
    "build",
    markdownHtmlPackage,
    "--target",
    "wasm-gc",
    "--release",
  ]);
  await assertFileExists(moonNativeRunner, "MoonBit native runner");
  await assertFileExists(moonWasmRunner, "MoonBit wasm-gc runner");
}

function timedExternal(
  command: string,
  args: string[],
  repeats: number,
  warmups: number,
): number[] {
  for (let i = 0; i < warmups; i += 1) {
    run(command, args);
  }
  const times: number[] = [];
  for (let i = 0; i < repeats; i += 1) {
    const start = Bun.nanoseconds();
    run(command, args);
    times.push(Number(Bun.nanoseconds() - start) / 1_000_000);
  }
  return times;
}

function timedMoonbitRunner(
  command: string,
  args: string[],
  fixture: string,
  repeats: number,
  warmups: number,
): number[] {
  const stdout = runCapture(command, [
    ...args,
    "--bench",
    fixture,
    String(repeats),
    String(warmups),
  ]);
  const times = JSON.parse(stdout);
  if (!Array.isArray(times) || times.length !== repeats) {
    throw new Error(`MoonBit runner returned invalid timings: ${stdout}`);
  }
  return times.map((value) => {
    if (typeof value !== "number" || !Number.isFinite(value)) {
      throw new Error(`MoonBit runner returned invalid timing: ${stdout}`);
    }
    return value;
  });
}

function timedBunMarkdown(input: string, repeats: number, warmups: number): number[] {
  for (let i = 0; i < warmups; i += 1) {
    const html = Bun.markdown.html(input);
    if (html.length === 0) {
      throw new Error("Bun.markdown produced empty output");
    }
  }
  const times: number[] = [];
  for (let i = 0; i < repeats; i += 1) {
    const start = Bun.nanoseconds();
    const html = Bun.markdown.html(input);
    if (html.length === 0) {
      throw new Error("Bun.markdown produced empty output");
    }
    times.push(Number(Bun.nanoseconds() - start) / 1_000_000);
  }
  return times;
}

function timedMarkdownIt(
  md: MarkdownIt,
  input: string,
  repeats: number,
  warmups: number,
): number[] {
  for (let i = 0; i < warmups; i += 1) {
    const html = md.render(input);
    if (html.length === 0) {
      throw new Error("markdown-it produced empty output");
    }
  }
  const times: number[] = [];
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

function mean(values: number[]): number {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function printTable(rows: ResultRow[]): void {
  console.log("| parser | fixture | bytes | mean ms | min ms | max ms |");
  console.log("| --- | --- | ---: | ---: | ---: | ---: |");
  for (const row of rows) {
    console.log(
      `| ${row.parser} | ${row.fixture} | ${row.bytes} | ${mean(row.times).toFixed(2)} | ` +
        `${Math.min(...row.times).toFixed(2)} | ${Math.max(...row.times).toFixed(2)} |`,
    );
  }
}

async function writeFixtures(sourceFixtures: Map<string, string>): Promise<WrittenFixture[]> {
  await mkdir(fixtureDir, { recursive: true });
  const written: WrittenFixture[] = [];
  for (const [name, input] of sourceFixtures) {
    const file = path.join(fixtureDir, `${name}.md`);
    await Bun.write(file, input);
    written.push({ name, input, file, bytes: new Blob([input]).size });
  }
  return written;
}

async function main(): Promise<void> {
  const { repeats, warmups } = parseArgs(process.argv);
  await buildMoonRunners();
  const sourceFixtures = await writeFixtures(fixtures());
  const md = new MarkdownIt("commonmark", {
    html: true,
    linkify: false,
    typographer: false,
  });

  const rows: ResultRow[] = [];
  for (const fixture of sourceFixtures) {
    rows.push({
      parser: "markdown.mbt/native",
      fixture: fixture.name,
      bytes: fixture.bytes,
      times: timedMoonbitRunner(moonNativeRunner, [], fixture.name, repeats, warmups),
    });
    rows.push({
      parser: "markdown.mbt/wasm-gc",
      fixture: fixture.name,
      bytes: fixture.bytes,
      times: timedMoonbitRunner(
        "moonrun",
        [moonWasmRunner],
        fixture.name,
        repeats,
        warmups,
      ),
    });
    rows.push({
      parser: "cmark",
      fixture: fixture.name,
      bytes: fixture.bytes,
      times: timedExternal("cmark", [fixture.file], repeats, warmups),
    });
    rows.push({
      parser: "Bun.markdown",
      fixture: fixture.name,
      bytes: fixture.bytes,
      times: timedBunMarkdown(fixture.input, repeats, warmups),
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

await main();
