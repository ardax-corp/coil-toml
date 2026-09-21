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

impl Store {
    pub static fn new() -> Store {
        return new Store(
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
        );
    }

    pub fn add(int tag, bool flag, int n, float x, string s, string key) -> int {
        let idx = len(self.tags);
        self.tags.push(tag);
        self.flags.push(flag);
        self.ints.push(n);
        self.floats.push(x);
        self.strs.push(s);
        self.keys.push(key);
        self.first.push(-1);
        self.last.push(-1);
        self.next.push(-1);
        return idx;
    }

    pub fn attach(int parent, int child) {
        if self.first[parent] < 0 {
            self.first[parent] = child;
            self.last[parent] = child;
        } else {
            self.next[self.last[parent]] = child;
            self.last[parent] = child;
        }
    }

    pub fn count_children(int idx) -> int {
        let n = 0;
        let c = self.first[idx];
        while c >= 0 {
            n = n + 1;
            c = self.next[c];
        }
        return n;
    }

    pub fn find_child(int parent, string key) -> int {
        let c = self.first[parent];
        while c >= 0 {
            if self.keys[c] == key {
                return c;
            }
            c = self.next[c];
        }
        return -1;
    }

    pub fn nth_child(int parent, int n) -> int {
        let c = self.first[parent];
        let i = 0;
        while c >= 0 {
            if i == n {
                return c;
            }
            i = i + 1;
            c = self.next[c];
        }
        return -1;
    }
}

/// Decode/encode failure. `line` and `column` are 1-based (column counts bytes in the line).
enum TomlError {
    Invalid { line: int, column: int },
    Io { line: int, column: int },
    Utf8 { line: int, column: int },
    Number { line: int, column: int },
}

/// Strict TOML value. Tables/arrays are ordered children (`keys[child]` / child nodes).
class TomlValue {
    store: Store,
    idx: int,
    tag: int,
    pub flag: bool,
    pub i: int,
    pub f: float,
    pub s: string,
}

class Parser {
    bytes: Vec<byte>,
    i: int,
    line: int,
    col: int,
    pub store: Store,
    root: int,
    current: int,
}

impl TomlValue {
    pub static fn wrap(Store store, int idx) -> TomlValue {
        return new TomlValue(
            store,
            idx,
            store.tags[idx],
            store.flags[idx],
            store.ints[idx],
            store.floats[idx],
            store.strs[idx],
        );
    }

    pub static fn from_string(string s) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_STR, false, 0, 0.0, s, "");
        return TomlValue::wrap(st, idx);
    }

    pub static fn from_int(int n) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_INT, false, n, 0.0, "", "");
        return TomlValue::wrap(st, idx);
    }

    pub static fn from_bool(bool flag) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_BOOL, flag, 0, 0.0, "", "");
        return TomlValue::wrap(st, idx);
    }

    pub static fn from_datetime(string s) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_DT, false, 0, 0.0, s, "");
        return TomlValue::wrap(st, idx);
    }

    pub static fn from_float(float x) -> TomlValue {
        let st = Store::new();
        let kind = FLT_FINITE;
        let neg = false;
        if x != x {
            kind = FLT_NAN;
        } else {
            if x != 0.0 {
                if x * 2.0 == x {
                    kind = FLT_INF;
                    if x < 0.0 {
                        neg = true;
                    }
                }
            }
        }
        let idx = st.add(TAG_FLOAT, neg, kind, x, "", "");
        return TomlValue::wrap(st, idx);
    }

    pub static fn empty_table() -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_TAB, false, KIND_EXPLICIT, 0.0, "", "");
        return TomlValue::wrap(st, idx);
    }

    pub fn is_string() -> bool {
        return self.tag == TAG_STR;
    }

    pub fn is_int() -> bool {
        return self.tag == TAG_INT;
    }

    pub fn is_float() -> bool {
        return self.tag == TAG_FLOAT;
    }

    pub fn is_bool() -> bool {
        return self.tag == TAG_BOOL;
    }

    pub fn is_datetime() -> bool {
        return self.tag == TAG_DT;
    }

    pub fn is_array() -> bool {
        return self.tag == TAG_ARR;
    }

    pub fn is_table() -> bool {
        return self.tag == TAG_TAB;
    }

    pub fn array_len() -> int {
        return self.store.count_children(self.idx);
    }

    pub fn table_len() -> int {
        return self.store.count_children(self.idx);
    }

    pub fn child(int n) -> TomlValue {
        let c = self.store.nth_child(self.idx, n);
        if c < 0 {
            return self;
        }
        return TomlValue::wrap(self.store, c);
    }

    pub fn key_at(int n) -> string {
        let c = self.store.nth_child(self.idx, n);
        if c < 0 {
            return "";
        }
        return self.store.keys[c];
    }

    pub fn has(string key) -> bool {
        return self.store.find_child(self.idx, key) >= 0;
    }

    pub fn get(string key) -> TomlValue {
        let c = self.store.find_child(self.idx, key);
        if c < 0 {
            return self;
        }
        return TomlValue::wrap(self.store, c);
    }
