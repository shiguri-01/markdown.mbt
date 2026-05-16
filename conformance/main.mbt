///|
struct CommonMarkExample {
  markdown : String
  html : String
  example : Int
  start_line : Int
  end_line : Int
  section : String
} derive(FromJson)

///|
struct ConformanceOptions {
  section : String?
  example : Int?
  failed_only : Bool
  format_json : Bool
  show_help : Bool
}

///|
struct ConformanceResult {
  example : CommonMarkExample
  actual : String
}

///|
struct SectionReport {
  section : String
  total : Int
  passed : Int
  failed_examples : Array[Int]
}

///|
fn main {
  let options = parse_args(@env.args())
  if options.show_help {
    print_help()
    return
  }
  let examples = load_examples()
  let results = run_examples(examples, options)
  if options.format_json {
    print_json_report(results)
  } else {
    print_text_report(results, options)
  }
}

///|
fn parse_args(args : Array[String]) -> ConformanceOptions {
  let mut section : String? = None
  let mut example : Int? = None
  let mut failed_only = false
  let mut format_json = false
  let mut show_help = false
  let mut i = 1
  while i < args.length() {
    match args[i] {
      "--section" => {
        if i + 1 >= args.length() {
          abort("--section requires a section name")
        }
        section = Some(args[i + 1])
        i = i + 2
      }
      "--example" => {
        if i + 1 >= args.length() {
          abort("--example requires an example number")
        }
        example = Some(parse_positive_int(args[i + 1], "--example"))
        i = i + 2
      }
      "--failed" => {
        failed_only = true
        i = i + 1
      }
      "--format" => {
        if i + 1 >= args.length() {
          abort("--format requires text or json")
        }
        if args[i + 1] == "json" {
          format_json = true
        } else if args[i + 1] == "text" {
          format_json = false
        } else {
          abort("--format must be text or json")
        }
        i = i + 2
      }
      "--help" | "-h" => {
        show_help = true
        i = i + 1
      }
      other => abort("unknown option: " + other)
    }
  }
  { section, example, failed_only, format_json, show_help }
}

///|
fn parse_positive_int(value : String, option : String) -> Int {
  let mut n = 0
  if value.length() == 0 {
    abort(option + " requires a positive integer")
  }
  for i in 0..<value.length() {
    let digit = value[i].to_int() - 48
    if digit < 0 || digit > 9 {
      abort(option + " requires a positive integer")
    }
    n = n * 10 + digit
  }
  n
}

///|
fn print_help() -> Unit {
  println("CommonMark 0.31.2 conformance report")
  println("")
  println("Usage:")
  println("  moon -C conformance run . [options]")
  println("")
  println("Options:")
  println("  --section NAME     Run only examples from a section")
  println("  --example N        Run only one example")
  println("  --failed           Print failed examples")
  println("  --format json      Emit machine-readable JSON")
  println("  -h, --help         Show this help")
}

///|
fn load_examples() -> Array[CommonMarkExample] {
  let parsed = try @json.parse(commonmark_spec_json) catch {
    _ => abort("failed to parse CommonMark spec JSON")
  } noraise {
    value => value
  }
  try @json.from_json(parsed) catch {
    _ => abort("failed to decode CommonMark spec JSON")
  } noraise {
    examples => examples
  }
}

///|
fn run_examples(
  examples : Array[CommonMarkExample],
  options : ConformanceOptions,
) -> Array[ConformanceResult] {
  let results : Array[ConformanceResult] = []
  for example in examples {
    if should_run_example(example, options) {
      let html = @markdown.HtmlBuffer::new()
      @markdown.parse_into(example.markdown, html.sink())
      let actual = html.to_string()
      results.push({ example, actual })
    }
  }
  results
}

///|
fn should_run_example(
  example : CommonMarkExample,
  options : ConformanceOptions,
) -> Bool {
  match options.section {
    Some(section) => if example.section != section { return false }
    None => ()
  }
  match options.example {
    Some(number) => example.example == number
    None => true
  }
}

///|
fn print_text_report(
  results : Array[ConformanceResult],
  options : ConformanceOptions,
) -> Unit {
  let reports = section_reports(results)
  let mut total = 0
  let mut passed = 0
  for report in reports {
    total = total + report.total
    passed = passed + report.passed
  }
  println(
    "CommonMark 0.31.2: " +
    passed.to_string() +
    "/" +
    total.to_string() +
    " passed",
  )
  println("")
  for report in reports {
    println(
      report.section +
      ": " +
      report.passed.to_string() +
      "/" +
      report.total.to_string(),
    )
    if options.failed_only && report.failed_examples.length() > 0 {
      println("  failed: " + join_ints(report.failed_examples))
    }
  }
  if options.failed_only || options.example is Some(_) {
    print_failures(results)
  }
}

///|
fn section_reports(results : Array[ConformanceResult]) -> Array[SectionReport] {
  let reports : Array[SectionReport] = []
  for result in results {
    let mut index = find_report(reports, result.example.section)
    if index < 0 {
      reports.push({
        section: result.example.section,
        total: 0,
        passed: 0,
        failed_examples: [],
      })
      index = reports.length() - 1
    }
    let report = reports[index]
    let passed_delta = if result.actual == result.example.html { 1 } else { 0 }
    let failed_examples = report.failed_examples
    if passed_delta == 0 {
      failed_examples.push(result.example.example)
    }
    reports[index] = {
      section: report.section,
      total: report.total + 1,
      passed: report.passed + passed_delta,
      failed_examples,
    }
  }
  reports
}

///|
fn find_report(reports : Array[SectionReport], section : String) -> Int {
  for i in 0..<reports.length() {
    if reports[i].section == section {
      return i
    }
  }
  -1
}

///|
fn print_failures(results : Array[ConformanceResult]) -> Unit {
  for result in results {
    if result.actual != result.example.html {
      println("")
      println(
        "Example " +
        result.example.example.to_string() +
        " [" +
        result.example.section +
        "] lines " +
        result.example.start_line.to_string() +
        "-" +
        result.example.end_line.to_string(),
      )
      println(
        "first difference: " +
        first_difference(result.example.html, result.actual),
      )
      println("markdown:")
      println(result.example.markdown)
      println("expected:")
      println(result.example.html)
      println("actual:")
      println(result.actual)
    }
  }
}

///|
fn first_difference(expected : String, actual : String) -> String {
  let limit = if expected.length() < actual.length() {
    expected.length()
  } else {
    actual.length()
  }
  let mut i = 0
  while i < limit && expected[i] == actual[i] {
    i = i + 1
  }
  if i == limit && expected.length() == actual.length() {
    "none"
  } else {
    "offset " +
    i.to_string() +
    ", expected " +
    inspect_char_at(expected, i) +
    ", actual " +
    inspect_char_at(actual, i)
  }
}

///|
fn inspect_char_at(text : String, index : Int) -> String {
  if index >= text.length() {
    "EOF"
  } else {
    char_name(text, index)
  }
}

///|
fn char_name(text : String, index : Int) -> String {
  let code = text[index].to_int()
  if code == 10 {
    "\\n"
  } else if code == 9 {
    "\\t"
  } else if code == 34 {
    "\\\""
  } else if code == 92 {
    "\\\\"
  } else {
    text[index:index + 1].to_owned()
  }
}

///|
fn print_json_report(results : Array[ConformanceResult]) -> Unit {
  let reports = section_reports(results)
  let mut total = 0
  let mut passed = 0
  for report in reports {
    total = total + report.total
    passed = passed + report.passed
  }
  println("{")
  println("  \"version\": \"0.31.2\",")
  println("  \"total\": " + total.to_string() + ",")
  println("  \"passed\": " + passed.to_string() + ",")
  println("  \"sections\": [")
  for i in 0..<reports.length() {
    let report = reports[i]
    let comma = if i + 1 == reports.length() { "" } else { "," }
    println("    {")
    println("      \"section\": " + json_string(report.section) + ",")
    println("      \"total\": " + report.total.to_string() + ",")
    println("      \"passed\": " + report.passed.to_string() + ",")
    println("      \"failed\": [" + join_ints(report.failed_examples) + "]")
    println("    }" + comma)
  }
  println("  ],")
  println("  \"failures\": [")
  let mut emitted = 0
  for result in results {
    if result.actual != result.example.html {
      if emitted > 0 {
        println("    ,")
      }
      println("    {")
      println("      \"example\": " + result.example.example.to_string() + ",")
      println("      \"section\": " + json_string(result.example.section) + ",")
      println(
        "      \"start_line\": " + result.example.start_line.to_string() + ",",
      )
      println(
        "      \"end_line\": " + result.example.end_line.to_string() + ",",
      )
      println(
        "      \"markdown\": " + json_string(result.example.markdown) + ",",
      )
      println("      \"expected\": " + json_string(result.example.html) + ",")
      println("      \"actual\": " + json_string(result.actual))
      println("    }")
      emitted = emitted + 1
    }
  }
  println("  ]")
  println("}")
}

///|
fn join_ints(items : Array[Int]) -> String {
  let mut output = ""
  for i in 0..<items.length() {
    if i > 0 {
      output = output + ", "
    }
    output = output + items[i].to_string()
  }
  output
}

///|
fn json_string(value : String) -> String {
  let mut output = "\""
  for i in 0..<value.length() {
    let code = value[i].to_int()
    if code == 34 {
      output = output + "\\\""
    } else if code == 92 {
      output = output + "\\\\"
    } else if code == 10 {
      output = output + "\\n"
    } else if code == 9 {
      output = output + "\\t"
    } else if code == 13 {
      output = output + "\\r"
    } else {
      output = output + value[i:i + 1].to_owned()
    }
  }
  output + "\""
}
