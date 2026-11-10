///|
test "named argument length exceeded" {
  let parser = Parser::new(args={
    "arg1": Arg::named(short='a', nargs=Fixed(2), help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let result = try {
    ignore(parser.parse(value, ["--arg1", "v1", "v2", "v3"]))
    None
  } catch {
    error => Some(error)
  }
  assert_eq(result.unwrap().to_string().contains("TooManyArgs"), true)
}

///|
test "flag argument duplicated" {
  let parser = Parser::new(args={
    "arg1": Arg::flag(short='a', help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let result = try {
    ignore(parser.parse(value, ["--arg1", "--arg1"]))
    None
  } catch {
    error => Some(error)
  }
  assert_eq(
    result.unwrap().to_string().contains("Invalid flag argument length: 2 > 1"),
    true,
  )
}

///|
test "missing required argument includes generated usage" {
  let parser = Parser::new(args={
    "text": Arg::positional(nargs=One, help="Prompt text"),
  })
  let value = SimpleValue::new(parser.prog)
  let result = try {
    ignore(parser.parse(value, []))
    None
  } catch {
    error => Some(error)
  }
  assert_eq(
    result.unwrap().to_string(),
    "error: missing required argument <TEXT>\n\nUsage: PROG <TEXT>",
  )
}

///|
test "missing subcommand includes available commands" {
  let parser = Parser::new(subcmds={
    "case01": SubCommand::new(help="First case"),
  })
  let value = SimpleValue::new(parser.prog)
  let result = try {
    ignore(parser.parse(value, []))
    None
  } catch {
    error => Some(error)
  }
  assert_eq(
    result.unwrap().to_string(),
    "error: a subcommand is required\n\nUsage: PROG <COMMAND>\n\nAvailable commands: case01",
  )
}
