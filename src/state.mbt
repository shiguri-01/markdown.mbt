///|
pub struct StateKey {
  priv value : String
}

///|
pub fn StateKey::StateKey(scope : String, name : String) -> StateKey {
  { value: scope + ":" + name }
}

///|
priv struct StateStringEntry {
  key : String
  item : String
  value : String
}

///|
priv struct ParseState {
  strings : Array[StateStringEntry]
}

///|
fn ParseState::ParseState() -> ParseState {
  { strings: [] }
}

///|
fn ParseState::string_get(
  self : ParseState,
  key : StateKey,
  item : String,
) -> String? {
  for entry in self.strings {
    if entry.key == key.value && entry.item == item {
      return Some(entry.value)
    }
  }
  None
}

///|
fn ParseState::string_set(
  self : ParseState,
  key : StateKey,
  item : String,
  value : String,
) -> Unit {
  for i in 0..<self.strings.length() {
    let entry = self.strings[i]
    if entry.key == key.value && entry.item == item {
      self.strings[i] = { key: key.value, item, value }
      return
    }
  }
  self.strings.push({ key: key.value, item, value })
}
