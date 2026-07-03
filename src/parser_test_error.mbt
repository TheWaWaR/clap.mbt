///|
using @test {assert_eq}

///|
test "named argument length exceeded" {
  let parser = Parser::new(args={
    "arg1": Arg::named(short='a', nargs=Fixed(2), help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let err_msg = try {
    ignore(parser.parse(value, ["--arg1", "v1", "v2", "v3"]))
    ""
  } catch {
    err => err.to_string()
  }
  assert_eq(err_msg.contains("TooManyArgs"), true)
}

///|
test "flag argument duplicated" {
  let parser = Parser::new(args={
    "arg1": Arg::flag(short='a', help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let err_msg = try {
    ignore(parser.parse(value, ["--arg1", "--arg1"]))
    ""
  } catch {
    err => err.to_string()
  }
  assert_eq(err_msg.contains("Invalid flag argument length: 2 > 1"), true)
}
