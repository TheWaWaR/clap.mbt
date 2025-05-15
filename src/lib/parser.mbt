struct Argument {
  name: String
  short: Option[Char]
  nargs: Nargs
  positional: Bool
  /// If this value is empty means not limit to those value
  choices: ArrayView[String]
  default: ArrayView[String]
  help: String
}

enum Nargs {
  Any
  /// n == 0 (flag argument)
  None
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

struct SubCommand {
  name: String
  args: Array[Argument]
  subcmds: Array[SubCommand]
  help: String
}
struct Parser {
  /// The program name
  prog: String
  args: Array[Argument]
  subcmds: Array[SubCommand]
  description: String
}
pub fn Parser::parse(args: ArrayView[String]) -> Value {
  Value::{ 
    args: @hashmap.new(), 
    flags: @hashmap.new(), 
    positional_args: [], 
    subcmd: None 
  }
}

struct Value {
  args: @hashmap.T[String, String]
  flags: @hashmap.T[String, Bool]
  positional_args: Array[String]
  subcmd: Option[Value]
}
struct SubCommandValue {
  name: String
  v: Value
}