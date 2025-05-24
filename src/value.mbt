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
