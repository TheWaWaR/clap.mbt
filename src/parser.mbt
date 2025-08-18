// TODO: 
//  * support Arg::conflicts_with(name) (implement use user provider parser closure)
//  * support Arg::required_if/required_unless (implement use user provider parser closure)
//  * add more error tests
//  * add more docs

///|
pub(all) struct Parser {
  /// The program name
  prog : String
  args : Map[String, Arg]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  description : String
}

///| Create the argument parser specification
pub fn Parser::new(
  prog~ : String = "PROG",
  args~ : Map[String, Arg] = {},
  subcmds~ : Map[String, SubCommand] = {},
  description~ : String = "",
) -> Parser {
  { prog, args, subcmds, description }
}

///|
pub(all) suberror ParserError {
  InvalidArgumentName(String)
  InvalidSubCommandName(String)
  InvalidPositionalAsNamed(String)
  InvalidArgumentValue(String)
  InvalidArgumentValueLength(String)
  TooManyArgs(String)
  InvalidSpec(String)
} derive(Show)

///| Parse the command line arguments
pub fn[V : Value] Parser::parse(
  self : Parser,
  value : V,
  cli_args : ArrayView[String],
  env_vars~ : Map[String, String] = {},
) -> String? raise ParserError {
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
  if analysis_and_check_spec(cmd_name, args, global_args, subcmds, env_vars)
    is Some(rv) {
    positional_arg = Some(rv)
  }
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
        if new_arg.is_empty() && positional_arg is Some(arg) {
          current_value.add_value(arg.0, cli_arg, true)
          update_args_length(args_length, arg.0)
        } else {
          current_arg = handle_current_arg(
            current_value, cli_arg, new_arg, cmd_name, args_length,
          )
        }
      }
      [.. "-", .. rest] =>
        if rest.char_length() != 1 {
          if positional_arg is Some(arg) {
            current_value.add_value(arg.0, cli_arg, true)
            update_args_length(args_length, arg.0)
          } else {
            raise InvalidArgumentName(
              "Invalid short argument name \{cli_arg} for \{cmd_name}",
            )
          }
        } else {
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
          if new_arg.is_empty() && positional_arg is Some(arg) {
            current_value.add_value(arg.0, cli_arg, true)
            update_args_length(args_length, arg.0)
          } else {
            current_arg = handle_current_arg(
              current_value, cli_arg, new_arg, cmd_name, args_length,
            )
          }
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
        current_value.add_value(name, value_string, false)
        update_args_length(args_length, name)
        let new_length = args_length.get_or_default(name, 0)
        let nargs = arg.nargs().unwrap()
        if nargs.is_exceeded(new_length) {
          raise TooManyArgs(
            "Argument length limit: \{nargs}, current length: \{new_length}",
          )
        }
        if (not(positional_arg.is_empty()) || not(subcmds.is_empty())) &&
          nargs.is_exceeded(new_length + 1) {
          // Stop accepting more named arguments if nargs is full filled
          current_arg = None
        }
      }
      // == SubCommand ==
      value if subcmds.get(value) is Some(subcmd) => {
        if complete_level(
            args, global_args, args_length, current_value, env_vars, false,
          )
          is Some(err) {
          nargs_error = Some(err)
        }
        // switch to selected sub-command
        cmd_name = value.to_string()
        subcmd_chains.push(cmd_name)
        args = subcmd.args
        subcmds = subcmd.subcmds
        args_length.clear()
        current_value = current_value.select_subcmd(cmd_name)
        current_arg = None
        if analysis_and_check_spec(
            cmd_name, args, global_args, subcmds, env_vars,
          )
          is Some(rv) {
          positional_arg = Some(rv)
        }
      }
      // == Positional argument ==
      value_string if positional_arg is Some(arg) => {
        let name = arg.0
        current_value.add_value(name, value_string, true)
        update_args_length(args_length, name)
      }
      value =>
        raise InvalidSubCommandName(
          "Invalid sub-command name \{value} for \{cmd_name}",
        )
    }
  }
  if complete_level(
      args, global_args, args_length, current_value, env_vars, true,
    )
    is Some(err) {
    nargs_error = Some(err)
  }
  if nargs_error is Some(err) {
    raise err
  }
  None
}

///|
fn get_defaults(
  arg : Arg,
  env_vars : Map[String, String],
) -> Iter[@string.View] {
  let common = arg.common()
  if not(common.env_var.is_empty()) &&
    env_vars.get(common.env_var) is Some(env_value) {
    let value_delimiter = arg.value_delimiter().unwrap()
    env_value.split(value_delimiter)
  } else {
    arg.defaults().iter().map(fn(s) { s.view() })
  }
}

///|
fn update_args_length(
  args_length : @hashmap.T[String, UInt],
  name : String,
) -> Unit {
  args_length.set(name, args_length.get_or_default(name, 0) + 1)
}

///|
fn[V : Value] handle_current_arg(
  current_value : V,
  cli_arg : String,
  new_arg : (String, Arg)?,
  cmd_name : String,
  args_length : @hashmap.T[String, UInt],
) -> (String, Arg)? raise ParserError {
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
    current_value.set_flag(name, store)
    update_args_length(args_length, name)
    // Only one flag can be in a single level, so reset current_arg
    None
  } else {
    Some((name, arg))
  }
}

///|
fn analysis_and_check_spec(
  cmd_name : String,
  args : Map[String, Arg],
  global_args : Map[String, Arg],
  subcmds : Map[String, SubCommand],
  env_vars : Map[String, String],
) -> (String, Arg)? raise ParserError {
  let mut has_positional = false
  let mut positional_arg = None
  for name, arg in args.iter2() {
    let positional = arg is Positional(_)
    if positional {
      if not(subcmds.is_empty()) {
        raise InvalidSpec(
          "Invalid argument spec: sub-commands(parent=\{cmd_name}) and positional argument(\{name}) are not allowed at the same time",
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
    if arg.short() is Some(short_char) {
      if short_char != null_short &&
        not(short_char.is_ascii_alphabetic()) &&
        not(short_char.is_ascii_digit()) {
        raise InvalidSpec(
          "Invalid argument spec: parent-cmd=\{cmd_name}, name=\{name}, short=\{short_char}, only 0-9,a-z,A-Z is allowed",
        )
      }
    }
    if arg.choices() is Some(choices) && not(choices.is_empty()) {
      for value in get_defaults(arg, env_vars) {
        if not(choices.contains(value.to_string())) {
          raise InvalidSpec(
            "Invalid argument, name=\{name}, default value=\{value} not in choices=\{choices}",
          )
        }
      }
    }
  }
  positional_arg
}

// * set default value if missing
// * check argument value length is valid

///|
fn[V : Value] complete_level(
  args : Map[String, Arg],
  global_args : Map[String, Arg],
  args_length : @hashmap.T[String, UInt],
  current_value : V,
  env_vars : Map[String, String],
  final_subcmd : Bool,
) -> ParserError? raise ParserError {
  let mut nargs_error : ParserError? = None
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
      let mut length = args_length.get_or_default(name, 0)
      // flag and named argument can only presented in final subcommand
      if (arg is Flag(_) || arg is Named(_)) && length > 0 && not(final_subcmd) {
        raise InvalidArgumentValueLength(
          "Invalid argument: \{name}, flag/named argument can only presented in final level",
        )
      }
      if arg is Flag(store~, ..) {
        if length == 0 {
          let common = arg.common()
          let value = if not(common.env_var.is_empty()) &&
            env_vars.get(common.env_var) is Some(env_value) {
            match env_value {
              "true" => true
              "false" => false
              _ =>
                raise InvalidArgumentValue(
                  "Invalid flag environment variable: \{common.env_var}=\{env_value}",
                )
            }
          } else {
            not(store)
          }
          current_value.set_flag(name, value)
          update_args_length(args_length, name)
        } else if length > 1 {
          // TODO: support multiple flag in the future?
          raise InvalidArgumentValueLength(
            "Invalid flag argument length: \{length} > 1",
          )
        }
      } else {
        // Set defaults for:
        //   * final level positional argument
        //   * non-final level named argument
        if length == 0 && not(positional && not(final_subcmd)) {
          for default_value in get_defaults(arg, env_vars) {
            current_value.add_value(name, default_value.to_string(), positional)
            update_args_length(args_length, name)
            length += 1
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
          } else if final_subcmd {
            nargs_error = Some(
              InvalidArgumentValueLength(
                "Invalid name argument length=\{length}, limit: \{nargs}, final: \{final_subcmd}",
              ),
            )
          }
        }
      }
    }
  }
  nargs_error
}
