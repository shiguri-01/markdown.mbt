///|
pub struct StateKey {
  priv value : String
}

///|
pub fn StateKey::StateKey(scope : String, name : String) -> StateKey {
  { value: scope + ":" + name }
}

///|
priv struct ParseState {
  strings : @hashmap.HashMap[String, @hashmap.HashMap[String, String]]
}

///|
fn ParseState::ParseState() -> ParseState {
  { strings: @hashmap.HashMap([]) }
}

///|
fn ParseState::string_get(
  self : ParseState,
  key : StateKey,
  item : String,
) -> String? {
  match self.strings.get(key.value) {
    Some(items) => items.get(item)
    None => None
  }
}

///|
fn ParseState::string_set(
  self : ParseState,
  key : StateKey,
  item : String,
  value : String,
) -> Unit {
  let items = match self.strings.get(key.value) {
    Some(items) => items
    None => {
      let items = @hashmap.HashMap([])
      self.strings.set(key.value, items)
      items
    }
  }
  items.set(item, value)
}
