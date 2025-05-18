///|
test "parse simple" {
  let parser = Parser::{
    prog: "PROG",
    args: {
      "arg1": Argument::new(short=Some('a'), nargs=Fixed(1), help="Argument 1"),
    },
    subcmds: {},
    description: "Test program",
  }
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["--arg1", "abc"])
  assert_eq!(help_message, None)
  assert_eq!(value.name, "PROG")
  assert_eq!(value.args.size(), 1)
  assert_eq!(value.args.get("arg1").unwrap(), ["abc"])
  assert_eq!(value.flags.is_empty(), true)
  assert_eq!(value.positional_args.is_empty(), true)
  assert_eq!(value.subcmd.is_empty(), true)
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG [OPTIONS]
    #|
    #|Options:
    #|  -a, --arg1 <ARG1>  Argument 1
    #|  -h, --help         Print help
    #|
  assert_eq!(help_message, expected_help_message)
}
