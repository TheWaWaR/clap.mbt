///|
test "parse" {
  let parser = Parser::{
    prog: "PROG",
    args: {
      "arg1": Argument::{
        short: Some('a'),
        nargs: Fixed(1),
        positional: false,
        choices: [],
        default: [],
        help: "Argument 1",
      },
    },
    subcmds: {},
    description: "Test program",
  }
  let value = parser.parse!(["--arg1", "abc"])
  assert_eq!(value.args.size(), 1)
  assert_eq!(value.args.get("arg1").unwrap(), ["abc"])
  assert_eq!(value.flags.is_empty(), true)
  assert_eq!(value.positional_args.is_empty(), true)
  assert_eq!(value.subcmd.is_empty(), true)
  assert_eq!(value.help_message.is_empty(), true)
}
