# clap.mbt
Command Line Argument Parser for MoonBit

## Features
* Support flag/named/positional arguments
* Support limit arguments length
* Support argument choices/default values
* Support global argument
* Support env variables as default value
* Support infinite level of sub-command 
* Support custom value type
* Support generate [clap-rs](https://docs.rs/clap/latest/clap/_derive/_tutorial/index.html) style help output
* When named argument length full filled immediately finish current argument 

## Usage
Here is a simple example:
```moonbit
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
assert_eq!(value.args.length(), 0)
assert_eq!(value.flags.is_empty(), true)
assert_eq!(value.positional_args.is_empty(), true)
assert_eq!(value.subcmd.unwrap().flags.get("arg1").unwrap(), true)
```

Generate the help message:
```moonbit
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
```

See more examples: [parser tests](src/parser_test.mbt)