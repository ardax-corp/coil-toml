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

const KIND_IMPLICIT: int = 0;
const KIND_EXPLICIT: int = 1;
const KIND_INLINE: int = 2;

const ARR_VAL: int = 0;
const ARR_AOT: int = 1;

const FLT_FINITE: int = 0;
const FLT_INF: int = 1;
const FLT_NAN: int = 2;

class Store {
    pub tags: Vec<int>,
    pub flags: Vec<bool>,
    pub ints: Vec<int>,
    pub floats: Vec<float>,
    pub strs: Vec<string>,
    pub keys: Vec<string>,
    pub first: Vec<int>,
    pub last: Vec<int>,
    pub next: Vec<int>,
}
