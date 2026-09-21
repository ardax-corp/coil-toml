// Package root. Coil-side TOML 1.0 encode/decode.
// Named-module recursive `Vec<TomlValue>` does not unify (`TomlValue` vs `toml::TomlValue`).
// The tree is an arena of primitive vecs; TomlValue is a (store, idx) handle.
use string::{from_bytes, to_bytes, format};

const TAG_STR: int = 0;
const TAG_INT: int = 1;
const TAG_FLOAT: int = 2;
const TAG_BOOL: int = 3;
const TAG_DT: int = 4;
const TAG_ARR: int = 5;
const TAG_TAB: int = 6;
