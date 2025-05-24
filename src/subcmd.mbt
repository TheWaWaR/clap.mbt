///|
pub(all) struct SubCommand {
  args : Map[String, Arg]
  /// If there is sub-commands position, positional arguments in currently level is forbiden.
  subcmds : Map[String, SubCommand]
  help : String
}

///| Create a subcommand specification
pub fn SubCommand::new(
  args~ : Map[String, Arg] = {},
  subcmds~ : Map[String, SubCommand] = {},
  help~ : String = ""
) -> SubCommand {
  { args, subcmds, help }
}
