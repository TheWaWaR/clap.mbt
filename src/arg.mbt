///|
let null_short : Char = '\u0000'

///|
pub(all) enum Arg {
  Flag(short~ : Char, store~ : Bool, global~ : Bool, common~ : CommonFields)
  Named(
    short~ : Char,
    nargs~ : Nargs,
    choices~ : @hashset.HashSet[String],
    defaults~ : ArrayView[String],
    global~ : Bool,
    value_delimiter~ : String,
    common~ : CommonFields
  )
  Positional(
    nargs~ : Nargs,
    choices~ : @hashset.HashSet[String],
    defaults~ : ArrayView[String],
    value_delimiter~ : String,
    common~ : CommonFields
  )
}

///|
pub struct CommonFields {
  env_var : String
  help : String
}

///|
/// Create a flag argument
pub fn Arg::flag(
  short? : Char = null_short,
  store? : Bool = true,
  global? : Bool = false,
  env_var? : String = "",
  help? : String = "",
) -> Arg {
  let common = { help, env_var }
  Flag(short~, store~, global~, common~)
}

///|
/// Create a named argument
pub fn Arg::named(
  short? : Char = null_short,
  nargs? : Nargs = Any,
  choices? : @hashset.HashSet[String] = @hashset.new(),
  defaults? : ArrayView[String] = [],
  global? : Bool = false,
  value_delimiter? : String = ",",
  env_var? : String = "",
  help? : String = "",
) -> Arg {
  let common = { help, env_var }
  Named(short~, nargs~, choices~, defaults~, global~, value_delimiter~, common~)
}

///|
/// Create a positional argument
pub fn Arg::positional(
  nargs? : Nargs = Any,
  choices? : @hashset.HashSet[String] = @hashset.new(),
  defaults? : ArrayView[String] = [],
  value_delimiter? : String = ",",
  env_var? : String = "",
  help? : String = "",
) -> Arg {
  let common = { help, env_var }
  Positional(nargs~, choices~, defaults~, value_delimiter~, common~)
}

///|
pub fn Arg::short(self : Arg) -> Char? {
  match self {
    Flag(short~, ..) => Some(short)
    Named(short~, ..) => Some(short)
    Positional(_) => None
  }
}

///|
pub fn Arg::nargs(self : Arg) -> Nargs? {
  match self {
    Flag(_) => None
    Named(nargs~, ..) => Some(nargs)
    Positional(nargs~, ..) => Some(nargs)
  }
}

///|
pub fn Arg::choices(self : Arg) -> @hashset.HashSet[String]? {
  match self {
    Flag(_) => None
    Named(choices~, ..) => Some(choices)
    Positional(choices~, ..) => Some(choices)
  }
}

///|
pub fn Arg::value_delimiter(self : Arg) -> String? {
  match self {
    Flag(_) => None
    Named(value_delimiter~, ..) => Some(value_delimiter)
    Positional(value_delimiter~, ..) => Some(value_delimiter)
  }
}

///|
pub fn Arg::defaults(self : Arg) -> ArrayView[String] {
  match self {
    Flag(_) => []
    Named(defaults~, ..) => defaults
    Positional(defaults~, ..) => defaults
  }
}

///|
pub fn Arg::common(self : Arg) -> CommonFields {
  match self {
    Flag(common~, ..) => common
    Named(common~, ..) => common
    Positional(common~, ..) => common
  }
}

///|
pub fn Arg::is_global(self : Arg) -> Bool {
  match self {
    Named(global~, ..) => global
    Flag(global~, ..) => global
    Positional(_) => false
  }
}

///|
pub(all) enum Nargs {
  Any
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
} derive(Show, Eq)

///|
/// Check if the length is constrained by Nargs
pub fn Nargs::is_valid_length(self : Nargs, length : UInt) -> Bool {
  match self {
    Any => true
    One => length == 1
    Fixed(value) => length == value
    AtLeast(value) => length >= value
    AtMost(value) => length <= value
    Range(low, high) => low <= length && length < high
  }
}

///|
/// Check if the length exceeded the max length
pub fn Nargs::is_exceeded(self : Nargs, length : UInt) -> Bool {
  match self {
    Any => false
    One => length > 1
    Fixed(value) => length > value
    AtLeast(_) => false
    AtMost(value) => length > value
    Range(_, high) => length >= high
  }
}
