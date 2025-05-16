///|
pub(all) struct Argument {
  short : Char?
  nargs : Nargs
  positional : Bool
  /// If this value is empty means not limit to those value
  choices : ArrayView[String]
  default : ArrayView[String]
  help : String
}

///|
pub(all) enum Nargs {
  Any
  /// n == 0 (flag argument, store: true/false, default: not(store))
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
} derive(Show)

///|
pub fn Nargs::flag_value(self : Nargs) -> Bool? {
  match self {
    Nargs::None(v) => Some(v)
    Nargs::Fixed(0) => Some(true)
    _ => None
  }
}

///| The length must greater than 0
pub fn Nargs::is_valid_length(self : Nargs, length : UInt) -> Bool {
  match self {
    Any => true
    None(_) => false
    One => length == 1
    Fixed(value) => length == value
    AtLeast(value) => length >= value
    AtMost(value) => length <= value
    Range(low, high) => low <= length && length < high
  }
}

///| The length must greater than 0
pub fn Nargs::is_exceeded(self : Nargs, length : UInt) -> Bool {
  match self {
    Any => false
    None(_) => true
    One => length > 1
    Fixed(value) => length > value
    AtLeast(_) => false
    AtMost(value) => length > value
    Range(_, high) => length >= high
  }
}

///|
pub(all) struct SubCommand {
  args : Map[String, Argument]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  help : String
}

///|
pub(all) struct Parser {
  /// The program name
  prog : String
  args : Map[String, Argument]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  description : String
}

///|
pub type! ParserError {
  InvalidArgumentName(String)
  InvalidSubCommandName(String)
  InvalidPositionalAsName(String)
  InvalidArgumentValue(String)
  InvalidArgumentValueLength(String)
  TooManyArgs(String)
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
    if arg.positional {
      raise InvalidPositionalAsName(
        "Invalid use positional argument as name argument: \{cli_arg} for \{cmd_name} ",
      )
    }
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
        if name == "help" {
          value.help_message = Some(self.gen_help_message(value))
          return value
        }
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
        if short_char == 'h' {
          value.help_message = Some(self.gen_help_message(value))
          return value
        }
        let new_arg = args
          .iter()
          .find_first(fn(pair) { pair.1.short == Some(short_char) })
        current_arg = handle_current_arg!(cli_arg, new_arg)
      }
      // == Normal argument ==
      value if current_arg is Some((name, arg)) => {
        if arg.choices.length() > 0 && not(arg.choices.contains(value)) {
          raise InvalidArgumentValue(
            "Invalid argument value for \{cmd_name} => \{name}, value=\{value}, choices=\{arg.choices}",
          )
        }
        let mut new_length : Int = 1
        if current_value.args.get(name) is Some(args) {
          new_length = args.length() + 1
          args.push(value)
        } else {
          current_value.args.set(name, [value])
        }
        if arg.nargs.is_exceeded(new_length.reinterpret_as_uint()) {
          raise TooManyArgs(
            "Argument length limit: \{arg.nargs}, current length: \{new_length}",
          )
        }
      }
      // == SubCommand ==
      value if subcmds.get(value) is Some(subcmd) => {
        // * set default value if missing
        // * check argument value length is valid
        for name, define_args in args.iter2() {
          if define_args.positional {
            if current_value.positional_args.is_empty() {
              current_value.positional_args.append(
                define_args.default.to_array(),
              )
            }
            let length = current_value.positional_args
              .length()
              .reinterpret_as_uint()
            if not(define_args.nargs.is_valid_length(length)) {
              raise InvalidArgumentValueLength(
                "Invalid positional argument length=\{length}, limit: \{define_args.nargs}",
              )
            }
          } else if define_args.nargs.flag_value() is Some(store_value) {
            if not(current_value.flags.contains(name)) {
              current_value.flags.set(name, not(store_value))
            }
          } else {
            if current_value.args.get_or_default(name, []).is_empty() {
              current_value.args.set(name, define_args.default.to_array())
            }
            let length = current_value.args
              .get(name)
              .unwrap()
              .length()
              .reinterpret_as_uint()
            if not(define_args.nargs.is_valid_length(length)) {
              raise InvalidArgumentValueLength(
                "Invalid name argument length=\{length}, limit: \{define_args.nargs}",
              )
            }
          }
        }
        // switch to selected sub-command
        cmd_name = value.to_string()
        args = subcmd.args
        subcmds = subcmd.subcmds
        let subcmd_value = SubCommandValue::{
          name: cmd_name,
          val: Value::default(),
        }
        current_value.subcmd = Some(subcmd_value)
        current_value = subcmd_value.val
      }
      // == Positional argument ==
      value if args.iter().any(fn(pair) { pair.1.positional }) =>
        current_value.positional_args.push(value)
      value =>
        raise InvalidSubCommandName(
          "Invalid sub-command name \{value} for \{cmd_name}",
        )
    }
  }
  value
}

///|
pub fn Parser::gen_help_message(self : Parser, value : Value) -> String {
  "TODO"
}

///|
pub(all) struct Value {
  args : @hashmap.T[String, Array[String]]
  flags : @hashmap.T[String, Bool]
  positional_args : Array[String]
  mut subcmd : SubCommandValue?
  mut help_message : String?
}

///|
pub fn Value::default() -> Value {
  Value::{
    args: @hashmap.new(),
    flags: @hashmap.new(),
    positional_args: [],
    subcmd: None,
    help_message: None,
  }
}

///|
pub(all) struct SubCommandValue {
  name : String
  val : Value
}
