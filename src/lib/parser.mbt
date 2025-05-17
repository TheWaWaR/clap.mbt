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
pub fn Argument::new(
  short~ : Char? = None,
  nargs~ : Nargs = None(true),
  positional~ : Bool = false,
  choices~ : ArrayView[String] = [],
  default~ : ArrayView[String] = [],
  help~ : String = ""
) -> Argument {
  { short, nargs, positional, choices, default, help }
}

///|
pub fn Argument::is_flag(self : Argument) -> Bool {
  not(self.nargs.flag_value().is_empty())
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
pub fn Parser::parse[V : Value](
  self : Parser,
  cli_args : ArrayView[String]
) -> V!ParserError {
  let mut cmd_name = self.prog
  let mut args = self.args
  let mut subcmds = self.subcmds
  let value = V::new(cmd_name)
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
      value.set_flag!(name, flag_value)
      None
    } else {
      Some((name, arg))
    }
  }

  // * set default value if missing
  // * check argument value length is valid
  fn complete_level() -> Unit!ParserError {
    for name, define_args in args.iter2() {
      let positional = define_args.positional
      let length = current_value
        .get_arg_value_length(name, positional)
        .reinterpret_as_uint()
      if define_args.nargs.flag_value() is Some(store_value) {
        if length == 0 {
          current_value.set_flag!(name, not(store_value))
        }
      } else {
        if current_value.get_arg_value_length(name, positional) == 0 {
          for default_value in define_args.default {
            current_value.add_value!(name, default_value, positional)
          }
        }
        if not(define_args.nargs.is_valid_length(length)) {
          if define_args.positional {
            raise InvalidArgumentValueLength(
              "Invalid positional argument length=\{length}, limit: \{define_args.nargs}",
            )
          } else {
            raise InvalidArgumentValueLength(
              "Invalid name argument length=\{length}, limit: \{define_args.nargs}",
            )
          }
        }
      }
    }
  }

  for cli_arg in cli_args {
    match cli_arg {
      [.. "--", .. name] => {
        if name == "help" {
          value.set_help_message(self.gen_help_message(value))
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
          value.set_help_message(self.gen_help_message(value))
          return value
        }
        let new_arg = args
          .iter()
          .find_first(fn(pair) { pair.1.short == Some(short_char) })
        current_arg = handle_current_arg!(cli_arg, new_arg)
      }
      // == Normal argument ==
      value_string if current_arg is Some((name, arg)) => {
        if arg.choices.length() > 0 && not(arg.choices.contains(value_string)) {
          raise InvalidArgumentValue(
            "Invalid argument value for \{cmd_name} => \{name}, value=\{value_string}, choices=\{arg.choices}",
          )
        }
        current_value.add_value!(name, value_string, false)
        let new_length = current_value.get_arg_value_length(name, false)
        if arg.nargs.is_exceeded(new_length.reinterpret_as_uint()) {
          raise TooManyArgs(
            "Argument length limit: \{arg.nargs}, current length: \{new_length}",
          )
        }
      }
      // == SubCommand ==
      value if subcmds.get(value) is Some(subcmd) => {
        complete_level!()
        // switch to selected sub-command
        cmd_name = value.to_string()
        args = subcmd.args
        subcmds = subcmd.subcmds
        current_value = current_value.select_subcmd!(cmd_name)
      }
      // == Positional argument ==
      value_string if args.iter().find_first(fn(pair) { pair.1.positional })
        is Some(arg) => current_value.add_value!(arg.0, value_string, true)
      value =>
        raise InvalidSubCommandName(
          "Invalid sub-command name \{value} for \{cmd_name}",
        )
    }
  }
  complete_level!()
  value
}

///|
pub fn Parser::gen_help_message[V : Value](self : Parser, value : V) -> String {
  let builder = StringBuilder::new(size_hint=32)
  builder.write_string("Usage: ")
  let mut args = self.args
  let mut subcmds = self.subcmds
  let mut current_value = value
  while true {
    builder.write_string(current_value.get_name())
    guard current_value.get_subcmd() is Some(next_value) else { break }
    builder.write_char(' ')
    let subcmd = subcmds.get(next_value.get_name()).unwrap()
    args = subcmd.args
    subcmds = subcmd.subcmds
    current_value = next_value
  }
  builder.write_char(' ')
  builder.write_string("[OPTIONS]")
  if not(subcmds.is_empty()) {
    builder.write_char(' ')
    builder.write_string("<COMMAND>")
  }
  builder.write_char('\n')
  builder.write_char('\n')
  if not(subcmds.is_empty()) {
    builder.write_string("Commands:\n")
    for name in subcmds.keys() {
      builder.write_string("  \{name}\n")
    }
    builder.write_char('\n')
  }
  builder.write_string("Options:\n")
  let options = []
  for name, arg in args.iter2() {
    let short_string = match arg.short {
      Some(short) => "-\{short},"
      None => "   "
    }
    let long_string = if arg.is_flag() {
      "--\{name}"
    } else {
      "--\{name} <\{name.to_upper()}>"
    }
    let length = short_string.char_length() + long_string.char_length()
    options.push((short_string, long_string, length, arg.help))
  }
  options.push(("-h,", "--help", 9, "Print help"))
  let max_length = options.iter().map(fn(item) { item.2 }).maximum().unwrap()
  for item in options {
    let (short_string, long_string, length, help) = item
    builder.write_string("  \{short_string} \{long_string}  ")
    for _ in 0..<(max_length - length) {
      builder.write_char(' ')
    }
    builder.write_string(help)
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
pub(all) struct SimpleValue {
  name : String
  args : @hashmap.T[String, Array[String]]
  flags : @hashmap.T[String, Bool]
  positional_args : Array[String]
  mut subcmd : SimpleValue?
  mut help_message : String?
}

///|
pub fn SimpleValue::new(name : String) -> SimpleValue {
  SimpleValue::{
    name,
    args: @hashmap.new(),
    flags: @hashmap.new(),
    positional_args: [],
    subcmd: None,
    help_message: None,
  }
}

///|
pub(open) trait Value {
  new(name : String) -> Self
  set_flag(Self, name : String, value : Bool) -> Unit!ParserError
  set_help_message(Self, message : String) -> Unit
  add_value(Self, name : String, value : String, positional : Bool) ->
       Unit!ParserError
  get_name(Self) -> String
  get_subcmd(Self) -> Self?
  get_arg_value_length(Self, name : String, positional : Bool) -> Int
  select_subcmd(Self, subcmd : String) -> Self!ParserError
}

///|
pub impl Value for SimpleValue with new(name : String) -> SimpleValue {
  SimpleValue::new(name)
}

///|
pub impl Value for SimpleValue with set_flag(self, name : String, value : Bool) -> Unit!ParserError {
  self.flags.set(name, value)
}

///|
pub impl Value for SimpleValue with set_help_message(
  self,
  help_message : String
) -> Unit {
  self.help_message = Some(help_message)
}

///|
pub impl Value for SimpleValue with add_value(
  self,
  name : String,
  value : String,
  positional : Bool
) -> Unit!ParserError {
  if positional {
    self.positional_args.push(value)
  } else if self.args.get(name) is Some(values) {
    values.push(value)
  } else {
    self.args.set(name, [value])
  }
}

///|
pub impl Value for SimpleValue with get_name(self) -> String {
  self.name
}

///|
pub impl Value for SimpleValue with get_subcmd(self) -> SimpleValue? {
  self.subcmd
}

///|
pub impl Value for SimpleValue with get_arg_value_length(
  self,
  name : String,
  positional : Bool
) -> Int {
  if positional {
    self.positional_args.length()
  } else if self.args.get(name) is Some(values) {
    values.length()
  } else if self.flags.contains(name) {
    1
  } else {
    0
  }
}

///|
pub impl Value for SimpleValue with select_subcmd(self, subcmd : String) -> SimpleValue!ParserError {
  match self.subcmd {
    Some(subcmd_value) => subcmd_value
    None => {
      let subcmd_value = SimpleValue::new(subcmd)
      self.subcmd = Some(subcmd_value)
      subcmd_value
    }
  }
}
