///|
test "parse simple named argument" {
  let parser = Parser::{
    prog: "PROG",
    args: {
      "arg1": Argument::new_named(
        short=Some('a'),
        nargs=Fixed(1),
        help="Argument 1",
      ),
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

///|
test "parse simple positional argument" {
  let parser = Parser::{
    prog: "PROG",
    args: {
      "arg1": Argument::new_positional(nargs=Fixed(1), help="Argument 1"),
    },
    subcmds: {},
    description: "Test program",
  }
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["abc"])
  assert_eq!(help_message, None)
  assert_eq!(value.name, "PROG")
  assert_eq!(value.args.size(), 0)
  assert_eq!(value.flags.is_empty(), true)
  assert_eq!(value.positional_args, ["abc"])
  assert_eq!(value.subcmd.is_empty(), true)
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG [OPTIONS] <ARG1>
    #|
    #|Arguments:
    #|  <ARG1>  Argument 1
    #|
    #|Options:
    #|  -h, --help  Print help
    #|
  assert_eq!(help_message, expected_help_message)
}

///|
test "parse simple flag argument" {
  let parser = Parser::{
    prog: "PROG",
    args: { "arg1": Argument::new_flag(short=Some('a'), help="Argument 1") },
    subcmds: {},
    description: "Test program",
  }
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["--arg1"])
  assert_eq!(help_message, None)
  assert_eq!(value.name, "PROG")
  assert_eq!(value.args.size(), 0)
  assert_eq!(value.flags.get("arg1").unwrap(), true)
  assert_eq!(value.positional_args.is_empty(), true)
  assert_eq!(value.subcmd.is_empty(), true)
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG [OPTIONS]
    #|
    #|Options:
    #|  -a, --arg1  Argument 1
    #|  -h, --help  Print help
    #|
  assert_eq!(help_message, expected_help_message)
}

///|
test "parse simple subcmd" {
  let parser = Parser::{
    prog: "PROG",
    args: {},
    subcmds: {
      "subcmd1": SubCommand::{
        args: { "arg1": Argument::new_flag(short=Some('a'), help="Argument 1") },
        subcmds: {},
        help: "Test subcommand",
      },
    },
    description: "Test program",
  }
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["subcmd1", "--arg1"])
  assert_eq!(help_message, None)
  assert_eq!(value.name, "PROG")
  assert_eq!(value.args.size(), 0)
  assert_eq!(value.flags.is_empty(), true)
  assert_eq!(value.positional_args.is_empty(), true)
  assert_eq!(value.subcmd.unwrap().flags.get("arg1").unwrap(), true)
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG [OPTIONS] <COMMAND>
    #|
    #|Commands:
    #|  subcmd1  Test subcommand
    #|
    #|Options:
    #|  -h, --help  Print help
    #|
  assert_eq!(help_message, expected_help_message)
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["subcmd1", "--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG subcmd1 [OPTIONS]
    #|
    #|Options:
    #|  -a, --arg1  Argument 1
    #|  -h, --help  Print help
    #|
  assert_eq!(help_message, expected_help_message)
}
