///|
test "named argument length exceeded" {
  let parser = Parser::new(args={
    "arg1": Arg::named(short='a', nargs=Fixed(2), help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let result = parser.parse?(value, ["--arg1", "v1", "v2", "v3"])
  assert_eq!(result.unwrap_err().to_string().contains("TooManyArgs"), true)
}

///|
test "flag argument duplicated" {
  let parser = Parser::new(args={
    "arg1": Arg::flag(short='a', help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let result = parser.parse?(value, ["--arg1", "--arg1"])
  assert_eq!(
    result.unwrap_err().to_string().contains("Invalid flag argument length: 2 > 1"),
    true,
  )
}
