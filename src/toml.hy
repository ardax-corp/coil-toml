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
