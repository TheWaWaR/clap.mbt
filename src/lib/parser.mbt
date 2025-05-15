///|
struct Argument {
  short : Char?
  nargs : Nargs
  positional : Bool
  /// If this value is empty means not limit to those value
  choices : ArrayView[String]
  default : ArrayView[String]
  help : String
}

///|
enum Nargs {
  Any
  /// n == 0 (flag argument, store: true/false)
  None(Bool)
  /// n == 1
  One
  /// n == X
  Fixed(UInt)
  /// n >= X
  AtLeast(UInt)
  /// n <= X
  AtMost(UInt)
  /// X <= n < Y
  Range(UInt, UInt)
}

///|
pub fn Nargs::flag_value(self : Nargs) -> Bool? {
  match self {
    Nargs::None(v) => Some(v)
    Nargs::Fixed(0) => Some(true)
    _ => None
  }
}

///|
struct SubCommand {
  args : Map[String, Argument]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  help : String
}

///|
struct Parser {
  /// The program name
  prog : String
  args : Map[String, Argument]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  description : String
}

///|
type! ParserError {
  InvalidArgumentName(String)
  InvalidSubCommandName(String)
}

///|
pub fn Parser::parse(
  self : Parser,
  cli_args : ArrayView[String]
) -> Value!ParserError {
  let value = Value::default()
  let mut cmd_name = self.prog
  let mut args = self.args
  let mut subcmds = self.subcmds
  let mut current_value = value
  let mut current_arg : (String, Argument)? = None
  fn handle_current_arg(
    cli_arg : String,
    new_arg : (String, Argument)?
  ) -> (String, Argument)?!ParserError {
    guard new_arg is Some((name, arg)) else {
      raise InvalidArgumentName(
        "Invalid argument name \{cli_arg} for \{cmd_name}",
      )
    }
    // TODO: 
    //   * check arg.nargs
    //   * check arg.positional
    //   * check arg.choices
    if arg.nargs.flag_value() is Some(flag_value) {
      value.flags.set(name, flag_value)
      None
    } else {
      Some((name, arg))
    }
  }

  for cli_arg in cli_args {
    match cli_arg {
      [.. "--", .. name] => {
        let name = name.to_string()
        let new_arg = args.get(name).map(fn(arg) { (name, arg) })
        current_arg = handle_current_arg!(cli_arg, new_arg)
      }
      [.. "-", .. rest] => {
        guard rest.char_length() == 1 else {
          raise InvalidArgumentName(
            "Invalid argument name \{cli_arg} for \{cmd_name}",
          )
        }
        let short_char = rest.char_at(0)
        let new_arg = args
          .iter()
          .find_first(fn(pair) { pair.1.short == Some(short_char) })
        current_arg = handle_current_arg!(cli_arg, new_arg)
      }
      value =>
        if current_arg is Some((name, arg)) {
          // == Normal argument ==
          // TODO: 
          //   * check arg.nargs
          //   * check arg.positional
          //   * check arg.choices
          if current_value.args.get(name) is Some(args) {
            args.push(value)
          } else {
            current_value.args.set(name, [value])
          }
        } else if subcmds.get(value) is Some(subcmd) {
          // == SubCommand ==
          cmd_name = value.to_string()
          args = subcmd.args
          subcmds = subcmd.subcmds
          let subcmd_value = SubCommandValue::{
            name: cmd_name,
            val: Value::default(),
          }
          current_value.subcmd = Some(subcmd_value)
          current_value = subcmd_value.val
        } else if args.iter().any(fn(pair) { pair.1.positional }) {
          // == Positional argument ==
          current_value.positional_args.push(value)
        } else {
          raise InvalidSubCommandName(
            "Invalid sub-command name \{value} for \{cmd_name}",
          )
        }
    }
  }
  value
}

///|
pub(all) struct Value {
  args : @hashmap.T[String, Array[String]]
  flags : @hashmap.T[String, Bool]
  positional_args : Array[String]
  mut subcmd : SubCommandValue?
}

///|
fn Value::default() -> Value {
  Value::{
    args: @hashmap.new(),
    flags: @hashmap.new(),
    positional_args: [],
    subcmd: None,
  }
}

///|
pub(all) struct SubCommandValue {
  name : String
  val : Value
}
