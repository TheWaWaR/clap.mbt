///|
test "parse simple named argument" {
  let parser = Parser::new(args={
    "arg1": Arg::named(short='a', nargs=Fixed(1), help="Argument 1"),
  })
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
  let parser = Parser::new(args={
    "arg1": Arg::positional(nargs=Fixed(1), help="Argument 1"),
  })
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
  let parser = Parser::new(args={
    "arg1": Arg::flag(short='a', help="Argument 1"),
  })
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
  let parser = Parser::new(subcmds={
    "subcmd1": SubCommand::new(
      args={ "arg1": Arg::flag(short='a', help="Argument 1") },
      help="Test subcommand",
    ),
  })
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

///|
test "parser short named argument" {
  let parser = Parser::new(args={
    "arg1": Arg::named(short='a', nargs=Fixed(1), help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["-a", "abc"])
  assert_eq!(help_message, None)
  assert_eq!(value.name, "PROG")
  assert_eq!(value.args.size(), 1)
  assert_eq!(value.args.get("arg1").unwrap(), ["abc"])
  assert_eq!(value.flags.is_empty(), true)
  assert_eq!(value.positional_args.is_empty(), true)
  assert_eq!(value.subcmd.is_empty(), true)
}

///|
test "parse short flag argument" {
  let parser = Parser::new(args={
    "arg1": Arg::flag(short='a', help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["-a"])
  assert_eq!(help_message, None)
  assert_eq!(value.name, "PROG")
  assert_eq!(value.args.size(), 0)
  assert_eq!(value.flags.get("arg1").unwrap(), true)
  assert_eq!(value.positional_args.is_empty(), true)
  assert_eq!(value.subcmd.is_empty(), true)
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["-h"]).unwrap()
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
struct CustomValue {
  mut debug : Bool
  mut arg1 : String
  mut subcmd : CustomCommands?
}

///|
enum CustomCommands {
  SubCommand1(verbose~ : Bool, positional_args~ : Array[UInt])
} derive(Show, Eq)

///|
impl Value for CustomValue with set_flag(self, name : String, value : Bool) -> Unit!ParserError {
  match self.subcmd {
    None => {
      guard name == "debug" else {
        raise ParserError::InvalidArgumentName("Invalid flag \{name}=\{value}")
      }
      self.debug = value
    }
    Some(SubCommand1(positional_args~, ..)) => {
      guard name == "verbose" else {
        raise ParserError::InvalidArgumentName(
          "Invalid subcmd1 flag \{name}=\{value}",
        )
      }
      self.subcmd = Some(SubCommand1(verbose=value, positional_args~))
    }
  }
}

///|
impl Value for CustomValue with add_value(
  self,
  name : String,
  value : String,
  _positional : Bool
) -> Unit!ParserError {
  match self.subcmd {
    None =>
      match name {
        "arg1" => self.arg1 = value
        _ =>
          raise ParserError::InvalidArgumentName(
            "Invalid argument name \{name}",
          )
      }
    Some(SubCommand1(positional_args~, ..)) =>
      match name {
        "arg2" => {
          guard @strconv.parse_uint?(value) is Ok(value) else {
            raise ParserError::InvalidArgumentValue(
              "Invalid value \{value} for argument \{name}",
            )
          }
          positional_args.push(value)
        }
        _ =>
          raise ParserError::InvalidArgumentName(
            "Invalid argument name \{name}",
          )
      }
  }
}

///|
impl Value for CustomValue with select_subcmd(self, name : String) -> CustomValue!ParserError {
  match name {
    "subcmd1" =>
      self.subcmd = Some(SubCommand1(verbose=false, positional_args=[]))
    _ =>
      raise ParserError::InvalidSubCommandName(
        "Invalid subcommand name \{name}",
      )
  }
  self
}

///|
test "parse custom value" {
  let parser = Parser::new(
    args={
      "debug": Arg::flag(short='d', help="Debug"),
      "arg1": Arg::named(short='a', nargs=Fixed(1), help="Argument 1"),
    },
    subcmds={
      "subcmd1": SubCommand::new(
        args={
          "verbose": Arg::flag(short='v', help="Verbose"),
          "arg2": Arg::positional(nargs=Fixed(3), help="Argument 2"),
        },
        help="Test subcommand",
      ),
    },
  )
  let value = CustomValue::{ debug: false, arg1: "", subcmd: None }
  let help_message = parser.parse!(value, ["--debug", "--arg1", "value1"])
  assert_eq!(help_message, None)
  assert_eq!(value.debug, true)
  assert_eq!(value.arg1, "value1")
  assert_eq!(value.subcmd.is_empty(), true)
  let value = CustomValue::{ debug: false, arg1: "", subcmd: None }
  let help_message = parser.parse!(value, ["--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG [OPTIONS] <COMMAND>
    #|
    #|Commands:
    #|  subcmd1  Test subcommand
    #|
    #|Options:
    #|  -d, --debug        Debug
    #|  -a, --arg1 <ARG1>  Argument 1
    #|  -h, --help         Print help
    #|
  assert_eq!(help_message, expected_help_message)
  let value = CustomValue::{ debug: false, arg1: "", subcmd: None }
  let help_message = parser.parse!(value, [
    "subcmd1", "--verbose", "33", "44", "55",
  ])
  assert_eq!(help_message, None)
  assert_eq!(value.debug, false)
  assert_eq!(value.arg1, "")
  assert_eq!(
    value.subcmd.unwrap(),
    SubCommand1(verbose=true, positional_args=[33, 44, 55]),
  )
  let value = CustomValue::{ debug: false, arg1: "", subcmd: None }
  let help_message = parser.parse!(value, ["subcmd1", "--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG subcmd1 [OPTIONS] [ARG2]...
    #|
    #|Arguments:
    #|  [ARG2]...  Argument 2
    #|
    #|Options:
    #|  -v, --verbose  Verbose
    #|  -h, --help     Print help
    #|
  assert_eq!(help_message, expected_help_message)
}

///|
test "simple global argument" {
  let parser = Parser::new(
    args={
      "debug": Arg::flag(short='d', global=true, help="Debug"),
      "arg1": Arg::named(
        short='a',
        nargs=Fixed(1),
        global=true,
        help="Argument 1",
      ),
    },
    subcmds={
      "subcmd1": SubCommand::new(
        args={
          "verbose": Arg::flag(short='v', help="Verbose"),
          "arg2": Arg::positional(nargs=Fixed(3), help="Argument 2"),
        },
        help="Test subcommand",
      ),
    },
  )
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, [
    "subcmd1", "--debug", "--arg1", "value1", "33", "44", "55",
  ])
  assert_eq!(help_message, None)
  let subcmd1 = value.subcmd.unwrap()
  assert_eq!(subcmd1.flags.get("debug").unwrap(), true)
  assert_eq!(subcmd1.args.get("arg1").unwrap(), ["value1"])
  assert_eq!(subcmd1.positional_args, ["33", "44", "55"])
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, ["subcmd1", "--help"]).unwrap()
  let expected_help_message =
    #|Usage: PROG subcmd1 [OPTIONS] [ARG2]...
    #|
    #|Arguments:
    #|  [ARG2]...  Argument 2
    #|
    #|Options:
    #|  -v, --verbose  Verbose
    #|  -h, --help     Print help
    #|
    #|Common Options:
    #|  -d, --debug        Debug
    #|  -a, --arg1 <ARG1>  Argument 1
    #|
  assert_eq!(help_message, expected_help_message)
}

///|
test "simple env vars" {
  let parser = Parser::new(args={
    "arg1": Arg::named(
      short='a',
      nargs=AtMost(2),
      env_var="ENV_ARG1",
      help="Argument 1",
    ),
  })
  let value = SimpleValue::new(parser.prog)
  let help_message = parser.parse!(value, [], env_vars={ "ENV_ARG1": "ijk,xyz" })
  assert_eq!(help_message, None)
  assert_eq!(value.name, "PROG")
  assert_eq!(value.args.size(), 1)
  assert_eq!(value.args.get("arg1").unwrap(), ["ijk", "xyz"])
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
