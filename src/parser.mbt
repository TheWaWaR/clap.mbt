// TODO: 
//  * support Arg::get_one/get_array/get_option/get_flag (user provider parser)
//  * support Arg::conflicts_with(name) (implement use user provider parser closure)
//  * support Arg::required_if/required_unless (implement use user provider parser closure)
//  * support value delimiter
//  * support env variables as default value
//  * add more error tests
//  * add more docs
///|
pub(all) struct SubCommand {
  args : Map[String, Arg]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  help : String
}

///|
pub fn SubCommand::new(
  args~ : Map[String, Arg] = {},
  subcmds~ : Map[String, SubCommand] = {},
  help~ : String = ""
) -> SubCommand {
  { args, subcmds, help }
}

///|
pub(all) struct Parser {
  /// The program name
  prog : String
  args : Map[String, Arg]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  description : String
}

///|
pub fn Parser::new(
  prog~ : String = "PROG",
  args~ : Map[String, Arg] = {},
  subcmds~ : Map[String, SubCommand] = {},
  description~ : String = ""
) -> Parser {
  { prog, args, subcmds, description }
}

///|
pub(all) type! ParserError {
  InvalidArgumentName(String)
  InvalidSubCommandName(String)
  InvalidPositionalAsNamed(String)
  InvalidArgumentValue(String)
  InvalidArgumentValueLength(String)
  TooManyArgs(String)
  InvalidSpec(String)
} derive(Show)

///|
pub fn[V : Value] Parser::parse(
  self : Parser,
  value : V,
  cli_args : ArrayView[String]
) -> String?!ParserError {
  let mut cmd_name = self.prog
  let subcmd_chains = [cmd_name]
  let global_args : Map[String, Arg] = {}
  let mut args = self.args
  let mut positional_arg : (String, Arg)? = None
  let mut subcmds = self.subcmds
  let args_length : @hashmap.T[String, UInt] = @hashmap.new()
  let mut current_value = value
  let mut current_arg : (String, Arg)? = None
  let mut nargs_error : ParserError? = None
  fn analysis_and_check_spec() -> Unit!ParserError {
    let mut has_positional = false
    for name, arg in args.iter2() {
      let positional = arg is Positional(_)
      if positional {
        if not(subcmds.is_empty()) {
          raise InvalidSpec(
            "Invalid argument specification: sub-commands(parent=\{cmd_name}) and positional argument(\{name}) are not allowed at the same time",
          )
        } else {
          positional_arg = Some((name, arg))
        }
      }
      if positional && has_positional {
        raise InvalidSpec(
          "Invalid argument, only one positional argument is allowed, second=\{name}",
        )
      }
      has_positional = has_positional || positional
      if arg.is_global() {
        global_args[name] = arg
      }
      if arg.choices() is Some(choices) {
        if not(choices.is_empty()) {
          for value in arg.defaults() {
            if not(choices.contains(value)) {
              raise InvalidSpec(
                "Invalid argument, name=\{name}, default value=\{value} not in choices=\{choices}",
              )
            }
          }
        }
      }
    }
  }

  fn update_args_length(name : String) -> Unit {
    args_length.set(name, args_length.get_or_default(name, 0) + 1)
  }

  fn handle_current_arg(
    cli_arg : String,
    new_arg : (String, Arg)?
  ) -> (String, Arg)?!ParserError {
    guard new_arg is Some((name, arg)) else {
      raise InvalidArgumentName(
        "Invalid argument name \{cli_arg} for \{cmd_name}",
      )
    }
    if arg is Positional(..) {
      raise InvalidPositionalAsNamed(
        "Invalid use positional argument as name argument: \{cli_arg} for \{cmd_name} ",
      )
    }
    if arg is Flag(store~, ..) {
      current_value.set_flag!(name, store)
      update_args_length(name)
      None
    } else {
      Some((name, arg))
    }
  }

  // * set default value if missing
  // * check argument value length is valid
  fn complete_level(final_subcmd : Bool) -> Unit!ParserError {
    let all_args = if final_subcmd {
      [(args, false), (global_args, true)]
    } else {
      [(args, false)]
    }
    for item in all_args {
      let (the_args, is_global) = item
      for name, arg in the_args.iter2() {
        if is_global && args.contains(name) {
          continue
        }
        let positional = arg is Positional(..)
        let length = args_length.get_or_default(name, 0)
        if arg is Flag(store~, ..) {
          if length == 0 {
            current_value.set_flag!(name, not(store))
            update_args_length(name)
          } else if length > 1 {
            // TODO: support multiple flag in the future?
            raise InvalidArgumentValueLength(
              "Invalid flag argument length=\{length} > 1",
            )
          }
        } else {
          if length == 0 && not(positional && not(final_subcmd)) {
            for default_value in arg.defaults() {
              current_value.add_value!(name, default_value, positional)
              update_args_length(name)
            }
          }
          let nargs = arg.nargs().unwrap()
          if not(nargs.is_valid_length(length)) {
            if positional {
              if not(final_subcmd) {
                if length != 0 {
                  raise InvalidArgumentValueLength(
                    "Invalid positional argument length=\{length}, expected: 0 (has subcommand)",
                  )
                }
              } else {
                nargs_error = Some(
                  InvalidArgumentValueLength(
                    "Invalid positional argument length=\{length}, limit: \{nargs}",
                  ),
                )
              }
            } else {
              nargs_error = Some(
                InvalidArgumentValueLength(
                  "Invalid name argument length=\{length}, limit: \{nargs}",
                ),
              )
            }
          }
        }
      }
    }
  }

  analysis_and_check_spec!()
  for cli_arg in cli_args {
    match cli_arg {
      [.. "--", .. name] => {
        if name == "help" {
          return Some(self.gen_help_message(subcmd_chains, global_args))
        }
        let name = name.to_string()
        let new_arg = args
          .get(name)
          .map_or_else(fn() { global_args.get(name) }, fn(x) { Some(x) })
          .map(fn(arg) { (name, arg) })
        current_arg = handle_current_arg!(cli_arg, new_arg)
      }
      [.. "-", .. rest] => {
        guard rest.char_length() == 1 else {
          raise InvalidArgumentName(
            "Invalid short argument name \{cli_arg} for \{cmd_name}",
          )
        }
        let short_char = rest.char_at(0)
        if short_char == 'h' {
          return Some(self.gen_help_message(subcmd_chains, global_args))
        }
        let new_arg = args
          .iter()
          .find_first(fn(pair) { pair.1.short() == Some(short_char) })
          .map_or_else(
            fn() {
              global_args
              .iter()
              .find_first(fn(pair) { pair.1.short() == Some(short_char) })
            },
            fn(x) { Some(x) },
          )
        current_arg = handle_current_arg!(cli_arg, new_arg)
      }
      // == Normal argument ==
      value_string if current_arg is Some((name, arg)) => {
        if arg.choices() is Some(choices) {
          if choices.size() > 0 && not(choices.contains(value_string)) {
            raise InvalidArgumentValue(
              "Invalid argument value for \{cmd_name} => \{name}, value=\{value_string}, choices=\{choices}",
            )
          }
        }
        current_value.add_value!(name, value_string, false)
        update_args_length(name)
        let new_length = args_length.get_or_default(name, 0)
        let nargs = arg.nargs().unwrap()
        if nargs.is_exceeded(new_length) {
          raise TooManyArgs(
            "Argument length limit: \{nargs}, current length: \{new_length}",
          )
        }
        if (not(positional_arg.is_empty()) || not(subcmds.is_empty())) &&
          nargs.is_exceeded(new_length + 1) {
          current_arg = None
        }
      }
      // == SubCommand ==
      value if subcmds.get(value) is Some(subcmd) => {
        complete_level!(false)
        // switch to selected sub-command
        cmd_name = value.to_string()
        subcmd_chains.push(cmd_name)
        args = subcmd.args
        positional_arg = args
          .iter()
          .find_first(fn(pair) { pair.1 is Positional(..) })
        subcmds = subcmd.subcmds
        args_length.clear()
        current_value = current_value.select_subcmd!(cmd_name)
        current_arg = None
        analysis_and_check_spec!()
      }
      // == Positional argument ==
      value_string if positional_arg is Some(arg) => {
        let name = arg.0
        current_value.add_value!(name, value_string, true)
        update_args_length(name)
      }
      value =>
        raise InvalidSubCommandName(
          "Invalid sub-command name \{value} for \{cmd_name}",
        )
    }
  }
  complete_level!(true)
  if nargs_error is Some(err) {
    raise err
  }
  None
}

///|
pub fn Parser::gen_help_message(
  self : Parser,
  subcmd_chains : Array[String],
  global_args : Map[String, Arg]
) -> String {
  let builder = StringBuilder::new(size_hint=32)
  builder.write_string("Usage: ")
  let mut args = self.args
  let mut subcmds = self.subcmds
  builder.write_string(subcmd_chains[0])
  builder.write_char(' ')
  for subcmd_name in subcmd_chains[1:] {
    builder.write_string(subcmd_name)
    builder.write_char(' ')
    let subcmd = subcmds.get(subcmd_name).unwrap()
    args = subcmd.args
    subcmds = subcmd.subcmds
  }
  builder.write_string("[OPTIONS]")
  if not(subcmds.is_empty()) {
    builder.write_char(' ')
    builder.write_string("<COMMAND>")
  }
  let arg_pos_mark = if args
    .iter()
    .find_first(fn(pair) { pair.1 is Positional(..) })
    is Some((name, arg)) {
    let name_upper = name.to_upper()
    let nargs = arg.nargs().unwrap()
    let label = if nargs is Nargs::Fixed(1) {
      "<\{name_upper}>"
    } else if nargs.is_exceeded(2) {
      "[\{name_upper}]"
    } else {
      "[\{name_upper}]..."
    }
    builder.write_char(' ')
    builder.write_string(label)
    Some((label, arg.help()))
  } else {
    None
  }
  builder.write_char('\n')
  builder.write_char('\n')
  if not(subcmds.is_empty()) {
    builder.write_string("Commands:\n")
    let max_length = subcmds
      .iter()
      .map(fn(pair) { pair.0.char_length() })
      .maximum()
      .unwrap()
    for name, subcmd in subcmds.iter2() {
      builder.write_string("  \{name}  ")
      for _ in 0..<(max_length - name.char_length()) {
        builder.write_char(' ')
      }
      builder.write_string(subcmd.help)
      builder.write_char('\n')
    }
    builder.write_char('\n')
  }
  if arg_pos_mark is Some((label, help)) {
    builder.write_string("Arguments:\n")
    builder.write_string("  \{label}  \{help}\n\n")
  }
  write_args(builder, "Options", args, {}, true)
  if not(global_args.is_empty()) {
    builder.write_char('\n')
    write_args(builder, "Common Options", global_args, args, false)
  }
  builder.to_string()
}

///|
fn write_args(
  builder : StringBuilder,
  title : String,
  the_args : Map[String, Arg],
  cull_args : Map[String, Arg],
  include_help : Bool
) -> Unit {
  builder.write_string("\{title}:\n")
  let options = []
  for name, arg in the_args.iter2() {
    guard not(cull_args.contains(name)) else { continue }
    guard not(arg is Positional(..)) else { continue }
    let short_string = match arg.short() {
      Some(short) => "-\{short},"
      None => "   "
    }
    let long_string = if arg is Flag(_) {
      "--\{name}"
    } else {
      "--\{name} <\{name.to_upper()}>"
    }
    let length = short_string.char_length() + long_string.char_length()
    options.push((short_string, long_string, length, arg.help()))
  }
  if include_help {
    options.push(("-h,", "--help", 9, "Print help"))
  }
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
}

///|
pub(all) struct SimpleValue {
  name : String
  args : @hashmap.T[String, Array[String]]
  flags : @hashmap.T[String, Bool]
  positional_args : Array[String]
  mut subcmd : SimpleValue?
} derive(Show, Eq)

///|
pub fn SimpleValue::new(name : String) -> SimpleValue {
  SimpleValue::{
    name,
    args: @hashmap.new(),
    flags: @hashmap.new(),
    positional_args: [],
    subcmd: None,
  }
}

///|
pub(open) trait Value {
  set_flag(Self, name : String, value : Bool) -> Unit!ParserError = _
  add_value(Self, name : String, value : String, positional : Bool) ->
       Unit!ParserError = _
  select_subcmd(Self, subcmd : String) -> Self!ParserError = _
}

///|
impl Value with set_flag(_self, name : String, _value : Bool) -> Unit!ParserError {
  raise ParserError::InvalidArgumentName(
    "Invalid argument name \{name}, unimplemented",
  )
}

///|
impl Value with add_value(
  _self,
  name : String,
  value : String,
  _positional : Bool
) -> Unit!ParserError {
  raise ParserError::InvalidArgumentValue(
    "Invalid argument name=\{name}, value=\{value}, unimplemented",
  )
}

///|
impl Value with select_subcmd(_self, subcmd : String) -> Self!ParserError {
  raise ParserError::InvalidSubCommandName(
    "Invalid sub-command \{subcmd}, unimplemented",
  )
}

///|
pub impl Value for SimpleValue with set_flag(self, name : String, value : Bool) -> Unit!ParserError {
  self.flags.set(name, value)
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
