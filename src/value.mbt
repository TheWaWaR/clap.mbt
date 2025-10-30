///|
pub(all) struct SimpleValue {
  name : String
  args : @hashmap.HashMap[String, Array[String]]
  flags : @hashmap.HashMap[String, Bool]
  positional_args : Array[String]
  mut subcmd : SimpleValue?
} derive(Show, Eq)

///|
/// Create a simple value to hold the parsed result
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
pub fn SimpleValue::get_flag(self : SimpleValue, name : String) -> Bool? {
  self.flags.get(name)
}

///|
/// Get the positional argument values
pub fn[T : BasicValue] SimpleValue::get_positional(
  self : SimpleValue,
) -> Array[T] raise ParserError {
  let out = []
  for value in self.positional_args {
    out.push(T::parse(value)) catch {
      err => raise InvalidArgumentValue(err.to_string())
    }
  }
  out
}

///|
/// Get exactly one value by the argument name
pub fn[T : BasicValue] SimpleValue::get_one(
  self : SimpleValue,
  name : String,
) -> T raise ParserError {
  guard self.args.get(name) is Some(values) else {
    raise InvalidArgumentValue("Value not found for: \{name}")
  }
  guard values.length() == 1 else {
    raise InvalidArgumentValueLength(
      "Invalid argument length: \{values.length()}, expected=1, name=\{name}",
    )
  }
  T::parse(values[0]) catch {
    err => raise InvalidArgumentValue(err.to_string())
  }
}

///|
/// Get one/zero value by the argument name
pub fn[T : BasicValue] SimpleValue::get_option(
  self : SimpleValue,
  name : String,
) -> T? raise ParserError {
  guard self.args.get(name) is Some(values) else { return None }
  let length = values.length()
  guard length <= 1 else {
    raise InvalidArgumentValueLength(
      "Invalid argument length: \{length}, expected<=1, name=\{name}",
    )
  }
  guard values.get(0) is Some(value) else { return None }
  Some(T::parse(value)) catch {
    err => raise InvalidArgumentValue(err.to_string())
  }
}

///|
/// Get multiple values by the argument name
pub fn[T : BasicValue] SimpleValue::get_array(
  self : SimpleValue,
  name : String,
) -> Array[T] raise ParserError {
  guard self.args.get(name) is Some(values) else { return [] }
  let out = []
  for value in values {
    out.push(T::parse(value)) catch {
      err => raise InvalidArgumentValue(err.to_string())
    }
  }
  out
}

///|
pub(open) trait BasicValue {
  parse(input : String) -> Self raise @strconv.StrConvError
}

///|
pub impl BasicValue for String with parse(input : String) -> String raise @strconv.StrConvError {
  input
}

///|
pub impl BasicValue for Double with parse(input : String) -> Double raise @strconv.StrConvError {
  @strconv.parse_double(input)
}

///|
pub impl BasicValue for Int with parse(input : String) -> Int raise @strconv.StrConvError {
  @strconv.parse_int(input)
}

///|
pub impl BasicValue for Int64 with parse(input : String) -> Int64 raise @strconv.StrConvError {
  @strconv.parse_int64(input)
}

///|
pub impl BasicValue for UInt with parse(input : String) -> UInt raise @strconv.StrConvError {
  @strconv.parse_uint(input)
}

///|
pub impl BasicValue for UInt64 with parse(input : String) -> UInt64 raise @strconv.StrConvError {
  @strconv.parse_uint64(input)
}

///|
pub(open) trait Value {
  set_flag(Self, name : String, value : Bool) -> Unit raise ParserError = _
  add_value(Self, name : String, value : String, positional : Bool) -> Unit raise ParserError = _
  select_subcmd(Self, subcmd : String) -> Self raise ParserError = _
}

///|
impl Value with set_flag(_self, name : String, _value : Bool) -> Unit raise ParserError {
  raise ParserError::InvalidArgumentName(
    "Invalid argument name \{name}, unimplemented",
  )
}

///|
impl Value with add_value(
  _self,
  name : String,
  value : String,
  _positional : Bool,
) -> Unit raise ParserError {
  raise ParserError::InvalidArgumentValue(
    "Invalid argument name=\{name}, value=\{value}, unimplemented",
  )
}

///|
impl Value with select_subcmd(_self, subcmd : String) -> Self raise ParserError {
  raise ParserError::InvalidSubCommandName(
    "Invalid sub-command \{subcmd}, unimplemented",
  )
}

///|
pub impl Value for SimpleValue with set_flag(self, name : String, value : Bool) -> Unit raise ParserError {
  self.flags.set(name, value)
}

///|
pub impl Value for SimpleValue with add_value(
  self,
  name : String,
  value : String,
  positional : Bool,
) -> Unit raise ParserError {
  if positional {
    self.positional_args.push(value)
  } else if self.args.get(name) is Some(values) {
    values.push(value)
  } else {
    self.args.set(name, [value])
  }
}

///|
pub impl Value for SimpleValue with select_subcmd(self, subcmd : String) -> SimpleValue raise ParserError {
  match self.subcmd {
    Some(subcmd_value) => subcmd_value
    None => {
      let subcmd_value = SimpleValue::new(subcmd)
      self.subcmd = Some(subcmd_value)
      subcmd_value
    }
  }
}
