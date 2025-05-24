///| Generate the help message
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
    Some((label, arg.common().help))
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
    options.push((short_string, long_string, length, arg.common().help))
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
