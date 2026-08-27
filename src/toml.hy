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
    tags: Vec<int>,
    flags: Vec<bool>,
    ints: Vec<int>,
    floats: Vec<float>,
    strs: Vec<string>,
    keys: Vec<string>,
    first: Vec<int>,
    last: Vec<int>,
    next: Vec<int>,
}

impl Store {
    static fn new() -> Store {
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

    fn add(int tag, bool flag, int n, float x, string s, string key) -> int {
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

    fn attach(int parent, int child) {
        if self.first[parent] < 0 {
            self.first[parent] = child;
            self.last[parent] = child;
        } else {
            self.next[self.last[parent]] = child;
            self.last[parent] = child;
        }
    }

    fn count_children(int idx) -> int {
        let n = 0;
        let c = self.first[idx];
        while c >= 0 {
            n = n + 1;
            c = self.next[c];
        }
        return n;
    }

    fn find_child(int parent, string key) -> int {
        let c = self.first[parent];
        while c >= 0 {
            if self.keys[c] == key {
                return c;
            }
            c = self.next[c];
        }
        return -1;
    }

    fn nth_child(int parent, int n) -> int {
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
    flag: bool,
    i: int,
    f: float,
    s: string,
}

class Parser {
    bytes: Vec<byte>,
    i: int,
    line: int,
    col: int,
    store: Store,
    root: int,
    current: int,
}

impl TomlValue {
    static fn wrap(Store store, int idx) -> TomlValue {
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

    static fn from_string(string s) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_STR, false, 0, 0.0, s, "");
        return TomlValue::wrap(st, idx);
    }

    static fn from_int(int n) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_INT, false, n, 0.0, "", "");
        return TomlValue::wrap(st, idx);
    }

    static fn from_bool(bool flag) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_BOOL, flag, 0, 0.0, "", "");
        return TomlValue::wrap(st, idx);
    }

    static fn from_datetime(string s) -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_DT, false, 0, 0.0, s, "");
        return TomlValue::wrap(st, idx);
    }

    static fn from_float(float x) -> TomlValue {
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

    static fn empty_table() -> TomlValue {
        let st = Store::new();
        let idx = st.add(TAG_TAB, false, KIND_EXPLICIT, 0.0, "", "");
        return TomlValue::wrap(st, idx);
    }

    fn is_string() -> bool {
        return self.tag == TAG_STR;
    }

    fn is_int() -> bool {
        return self.tag == TAG_INT;
    }

    fn is_float() -> bool {
        return self.tag == TAG_FLOAT;
    }

    fn is_bool() -> bool {
        return self.tag == TAG_BOOL;
    }

    fn is_datetime() -> bool {
        return self.tag == TAG_DT;
    }

    fn is_array() -> bool {
        return self.tag == TAG_ARR;
    }

    fn is_table() -> bool {
        return self.tag == TAG_TAB;
    }

    fn array_len() -> int {
        return self.store.count_children(self.idx);
    }

    fn table_len() -> int {
        return self.store.count_children(self.idx);
    }

    fn child(int n) -> TomlValue {
        let c = self.store.nth_child(self.idx, n);
        if c < 0 {
            return self;
        }
        return TomlValue::wrap(self.store, c);
    }

    fn key_at(int n) -> string {
        let c = self.store.nth_child(self.idx, n);
        if c < 0 {
            return "";
        }
        return self.store.keys[c];
    }

    fn has(string key) -> bool {
        return self.store.find_child(self.idx, key) >= 0;
    }

    fn get(string key) -> TomlValue {
        let c = self.store.find_child(self.idx, key);
        if c < 0 {
            return self;
        }
        return TomlValue::wrap(self.store, c);
    }

    fn append_str(Vec<byte> out, string s) {
        let b = to_bytes(s);
        let i = 0;
        while i < len(b) {
            out.push(b[i]);
            i = i + 1;
        }
    }

    fn is_bare_key(string k) -> bool {
        let b = to_bytes(k);
        if len(b) == 0 {
            return false;
        }
        let i = 0;
        while i < len(b) {
            let c = b[i];
            let ok = (c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "_" || c == "-";
            if !ok {
                return false;
            }
            i = i + 1;
        }
        return true;
    }

    fn append_basic_string(Vec<byte> out, string s) {
        out.push("\"" as byte);
        let b = to_bytes(s);
        let i = 0;
        let sixteen: int = 16;
        let ht: int = 9;
        let lf: int = 10;
        let ff: int = 12;
        let cr: int = 13;
        let bs: int = 8;
        let sp: int = 32;
        let ten: int = 10;
        while i < len(b) {
            let c: int = b[i] as int;
            if c == ("\"" as byte as int) {
                out.push("\\" as byte);
                out.push("\"" as byte);
            } else if c == ("\\" as byte as int) {
                out.push("\\" as byte);
                out.push("\\" as byte);
            } else if c == bs {
                out.push("\\" as byte);
                out.push("b" as byte);
            } else if c == ff {
                out.push("\\" as byte);
                out.push("f" as byte);
            } else if c == lf {
                out.push("\\" as byte);
                out.push("n" as byte);
            } else if c == cr {
                out.push("\\" as byte);
                out.push("r" as byte);
            } else if c == ht {
                out.push("\\" as byte);
                out.push("t" as byte);
            } else if c < sp {
                let hi = c / sixteen;
                let lo = c % sixteen;
                out.push("\\" as byte);
                out.push("u" as byte);
                out.push("0" as byte);
                out.push("0" as byte);
                if hi < ten {
                    out.push((("0" as byte as int) + hi) as byte);
                } else {
                    out.push((("a" as byte as int) + (hi - ten)) as byte);
                }
                if lo < ten {
                    out.push((("0" as byte as int) + lo) as byte);
                } else {
                    out.push((("a" as byte as int) + (lo - ten)) as byte);
                }
            } else {
                out.push(c as byte);
            }
            i = i + 1;
        }
        out.push("\"" as byte);
    }

    fn append_key(Vec<byte> out, string k) {
        if self.is_bare_key(k) {
            self.append_str(out, k);
        } else {
            self.append_basic_string(out, k);
        }
    }

    fn append_float(Vec<byte> out, int idx) -> Result<(), TomlError> {
        let kind = self.store.ints[idx];
        let neg = self.store.flags[idx];
        if kind == FLT_NAN {
            if neg {
                self.append_str(out, "-nan");
            } else {
                self.append_str(out, "nan");
            }
            return ();
        }
        if kind == FLT_INF {
            if neg {
                self.append_str(out, "-inf");
            } else {
                self.append_str(out, "inf");
            }
            return ();
        }
        let x = self.store.floats[idx];
        if x != x {
            raise TomlError::Number { line: 1, column: 1 };
        }
        if x != 0.0 {
            if x * 2.0 == x {
                raise TomlError::Number { line: 1, column: 1 };
            }
        }
        let s = format("%f", x);
        let b = to_bytes(s);
        let n = len(b);
        if n == 0 {
            raise TomlError::Number { line: 1, column: 1 };
        }
        let i = 0;
        let has_dot = false;
        let has_exp = false;
        while i < n {
            let c = b[i];
            if c == "." {
                has_dot = true;
            } else {
                if c == "e" || c == "E" {
                    has_exp = true;
                }
            }
            out.push(c);
            i = i + 1;
        }
        if !has_dot && !has_exp {
            out.push("." as byte);
            out.push("0" as byte);
        }
        return ();
    }

    #[max_depth(256)]
    fn emit_value(Vec<byte> out, int idx) -> Result<(), TomlError> {
        let tag = self.store.tags[idx];
        if tag == TAG_STR {
            self.append_basic_string(out, self.store.strs[idx]);
            return ();
        }
        if tag == TAG_INT {
            self.append_str(out, format("%i", self.store.ints[idx]));
            return ();
        }
        if tag == TAG_FLOAT {
            return self.append_float(out, idx)?;
        }
        if tag == TAG_BOOL {
            if self.store.flags[idx] {
                self.append_str(out, "true");
            } else {
                self.append_str(out, "false");
            }
            return ();
        }
        if tag == TAG_DT {
            self.append_str(out, self.store.strs[idx]);
            return ();
        }
        if tag == TAG_ARR {
            out.push("[" as byte);
            let c = self.store.first[idx];
            let first = true;
            while c >= 0 {
                if !first {
                    self.append_str(out, ", ");
                }
                first = false;
                self.emit_value(out, c)?;
                c = self.store.next[c];
            }
            out.push("]" as byte);
            return ();
        }
        if tag == TAG_TAB {
            self.append_str(out, "{ ");
            let c = self.store.first[idx];
            let first = true;
            while c >= 0 {
                if !first {
                    self.append_str(out, ", ");
                }
                first = false;
                self.append_key(out, self.store.keys[c]);
                self.append_str(out, " = ");
                self.emit_value(out, c)?;
                c = self.store.next[c];
            }
            if first {
                self.append_str(out, "}");
            } else {
                self.append_str(out, " }");
            }
            return ();
        }
        raise TomlError::Invalid { line: 1, column: 1 };
    }

    fn is_aot(int idx) -> bool {
        return self.store.tags[idx] == TAG_ARR && self.store.ints[idx] == ARR_AOT;
    }

    fn is_inline_table(int idx) -> bool {
        return self.store.tags[idx] == TAG_TAB && self.store.ints[idx] == KIND_INLINE;
    }

    fn is_nested_table(int idx) -> bool {
        if self.store.tags[idx] != TAG_TAB {
            return false;
        }
        return self.store.ints[idx] != KIND_INLINE;
    }

    fn emit_header(Vec<byte> out, string path, bool aot) {
        if aot {
            self.append_str(out, "[[");
            self.append_str(out, path);
            self.append_str(out, "]]\n");
        } else {
            out.push("[" as byte);
            self.append_str(out, path);
            self.append_str(out, "]\n");
        }
    }

    fn path_join(string parent, string key) -> string {
        let kb: Vec<byte> = Vec::new();
        self.append_key(kb, key);
        let ks = match from_bytes(kb) {
            Result::Ok(s) => s,
            Result::Err(_) => key,
        };
        if parent == "" {
            return ks;
        }
        return parent + "." + ks;
    }

    #[max_depth(256)]
    fn emit_table(Vec<byte> out, int idx, string path, bool emit_hdr, bool aot_elem) -> Result<(), TomlError> {
        if emit_hdr {
            if len(out) > 0 {
                let last = out[len(out) - 1];
                if last != "\n" {
                    out.push("\n" as byte);
                }
            }
            self.emit_header(out, path, aot_elem);
        }
        let c = self.store.first[idx];
        while c >= 0 {
            let nested = self.is_nested_table(c);
            let aot = self.is_aot(c);
            if !nested && !aot {
                self.append_key(out, self.store.keys[c]);
                self.append_str(out, " = ");
                self.emit_value(out, c)?;
                out.push("\n" as byte);
            }
            c = self.store.next[c];
        }
        c = self.store.first[idx];
        while c >= 0 {
            if self.is_nested_table(c) {
                let p = self.path_join(path, self.store.keys[c]);
                self.emit_table(out, c, p, true, false)?;
            } else {
                if self.is_aot(c) {
                    let p = self.path_join(path, self.store.keys[c]);
                    let e = self.store.first[c];
                    while e >= 0 {
                        self.emit_table(out, e, p, true, true)?;
                        e = self.store.next[e];
                    }
                }
            }
            c = self.store.next[c];
        }
        return ();
    }

    fn emit(Vec<byte> out) -> Result<(), TomlError> {
        if self.store.tags[self.idx] != TAG_TAB {
            return self.emit_value(out, self.idx)?;
        }
        return self.emit_table(out, self.idx, "", false, false)?;
    }
}

impl Parser {
    fn at_end() -> bool {
        return self.i >= len(self.bytes);
    }

    fn bump() {
        if self.i >= len(self.bytes) {
            return;
        }
        let c = self.bytes[self.i];
        self.i = self.i + 1;
        if c == "\r" {
            self.line = self.line + 1;
            self.col = 1;
            if self.i < len(self.bytes) {
                if self.bytes[self.i] == "\n" {
                    self.i = self.i + 1;
                }
            }
        } else {
            if c == "\n" {
                self.line = self.line + 1;
                self.col = 1;
            } else {
                self.col = self.col + 1;
            }
        }
    }

    fn cur() -> byte {
        return self.bytes[self.i];
    }

    fn invalid() -> TomlError {
        return TomlError::Invalid { line: self.line, column: self.col };
    }

    fn number_err() -> TomlError {
        return TomlError::Number { line: self.line, column: self.col };
    }

    fn utf8_err() -> TomlError {
        return TomlError::Utf8 { line: self.line, column: self.col };
    }

    fn skip_space() {
        while !self.at_end() {
            let c = self.cur();
            if c == " " || c == "\t" {
                self.bump();
            } else {
                break;
            }
        }
    }

    fn skip_comment() {
        if self.at_end() || self.cur() != "#" {
            return;
        }
        while !self.at_end() {
            let c = self.cur();
            if c == "\n" || c == "\r" {
                break;
            }
            self.bump();
        }
    }

    fn skip_trivia() {
        while !self.at_end() {
            let c = self.cur();
            if c == " " || c == "\t" {
                self.bump();
                continue;
            }
            if c == "#" {
                self.skip_comment();
                continue;
            }
            if c == "\n" || c == "\r" {
                self.bump();
                continue;
            }
            break;
        }
    }

    fn expect_stmt_end() -> Result<(), TomlError> {
        self.skip_space();
        self.skip_comment();
        if self.at_end() {
            return ();
        }
        let c = self.cur();
        if c == "\n" || c == "\r" {
            self.bump();
            return ();
        }
        raise self.invalid();
    }

    fn byte_digit(byte c) -> int {
        if c == "0" {
            return 0;
        }
        if c == "1" {
            return 1;
        }
        if c == "2" {
            return 2;
        }
        if c == "3" {
            return 3;
        }
        if c == "4" {
            return 4;
        }
        if c == "5" {
            return 5;
        }
        if c == "6" {
            return 6;
        }
        if c == "7" {
            return 7;
        }
        if c == "8" {
            return 8;
        }
        if c == "9" {
            return 9;
        }
        return -1;
    }

    fn hex_val(byte c) -> int {
        let d = self.byte_digit(c);
        if d >= 0 {
            return d;
        }
        if c == "a" {
            return 10;
        }
        if c == "b" {
            return 11;
        }
        if c == "c" {
            return 12;
        }
        if c == "d" {
            return 13;
        }
        if c == "e" {
            return 14;
        }
        if c == "f" {
            return 15;
        }
        if c == "A" {
            return 10;
        }
        if c == "B" {
            return 11;
        }
        if c == "C" {
            return 12;
        }
        if c == "D" {
            return 13;
        }
        if c == "E" {
            return 14;
        }
        if c == "F" {
            return 15;
        }
        return -1;
    }

    fn push_cp(Vec<byte> out, int cp) -> Result<(), TomlError> {
        let n64: int = 64;
        let n128: int = 128;
        let n192: int = 192;
        let n224: int = 224;
        let n240: int = 240;
        let n4096: int = 4096;
        let n262144: int = 262144;
        if cp < 0 || cp > 1114111 {
            raise self.utf8_err();
        }
        if cp >= 55296 && cp <= 57343 {
            raise self.utf8_err();
        }
        if cp <= 127 {
            out.push(cp as byte);
            return ();
        }
        if cp <= 2047 {
            out.push((n192 + (cp / n64)) as byte);
            out.push((n128 + (cp % n64)) as byte);
            return ();
        }
        if cp <= 65535 {
            out.push((n224 + (cp / n4096)) as byte);
            out.push((n128 + ((cp / n64) % n64)) as byte);
            out.push((n128 + (cp % n64)) as byte);
            return ();
        }
        out.push((n240 + (cp / n262144)) as byte);
        out.push((n128 + ((cp / n4096) % n64)) as byte);
        out.push((n128 + ((cp / n64) % n64)) as byte);
        out.push((n128 + (cp % n64)) as byte);
        return ();
    }

    fn parse_hex_n(int n) -> Result<int, TomlError> {
        let v = 0;
        let k = 0;
        while k < n {
            if self.at_end() {
                raise self.invalid();
            }
            let h = self.hex_val(self.cur());
            if h < 0 {
                raise self.invalid();
            }
            v = v * 16 + h;
            self.bump();
            k = k + 1;
        }
        return v;
    }

    fn parse_escape(Vec<byte> out) -> Result<(), TomlError> {
        if self.at_end() {
            raise self.invalid();
        }
        let c = self.cur();
        self.bump();
        if c == "\"" {
            out.push("\"" as byte);
            return ();
        }
        if c == "\\" {
            out.push("\\" as byte);
            return ();
        }
        if c == "b" {
            out.push(8 as byte);
            return ();
        }
        if c == "f" {
            out.push(12 as byte);
            return ();
        }
        if c == "n" {
            out.push(10 as byte);
            return ();
        }
        if c == "r" {
            out.push(13 as byte);
            return ();
        }
        if c == "t" {
            out.push(9 as byte);
            return ();
        }
        if c == "u" {
            let cp = self.parse_hex_n(4)?;
            return self.push_cp(out, cp)?;
        }
        if c == "U" {
            let cp = self.parse_hex_n(8)?;
            return self.push_cp(out, cp)?;
        }
        raise self.invalid();
    }

    fn bytes_to_str(Vec<byte> out) -> Result<string, TomlError> {
        return match from_bytes(out) {
            Result::Ok(s) => s,
            Result::Err(_) => raise self.utf8_err(),
        };
    }

    fn parse_basic_string() -> Result<string, TomlError> {
        self.bump();
        let out: Vec<byte> = Vec::new();
        while true {
            if self.at_end() {
                raise self.invalid();
            }
            let c = self.cur();
            if c == "\"" {
                self.bump();
                break;
            }
            if c == "\\" {
                self.bump();
                self.parse_escape(out)?;
                continue;
            }
            if c == "\n" || c == "\r" {
                raise self.invalid();
            }
            if c < " " && c != "\t" {
                raise self.invalid();
            }
            out.push(c);
            self.bump();
        }
        return self.bytes_to_str(out)?;
    }

    fn parse_literal_string() -> Result<string, TomlError> {
        self.bump();
        let out: Vec<byte> = Vec::new();
        while true {
            if self.at_end() {
                raise self.invalid();
            }
            let c = self.cur();
            if c == "'" {
                self.bump();
                break;
            }
            if c == "\n" || c == "\r" {
                raise self.invalid();
            }
            if c < " " && c != "\t" {
                raise self.invalid();
            }
            out.push(c);
            self.bump();
        }
        return self.bytes_to_str(out)?;
    }

    fn count_quote(byte q) -> int {
        let n = 0;
        let j = self.i;
        while j < len(self.bytes) {
            if self.bytes[j] != q {
                break;
            }
            n = n + 1;
            j = j + 1;
        }
        return n;
    }

    fn skip_opening_nl() {
        if self.at_end() {
            return;
        }
        let c = self.cur();
        if c == "\n" || c == "\r" {
            self.bump();
        }
    }

    fn parse_ml_literal() -> Result<string, TomlError> {
        self.bump();
        self.bump();
        self.bump();
        self.skip_opening_nl();
        let out: Vec<byte> = Vec::new();
        let q: byte = "'";
        while true {
            if self.at_end() {
                raise self.invalid();
            }
            let n = self.count_quote(q);
            if n >= 3 {
                if n > 5 {
                    raise self.invalid();
                }
                let extra = n - 3;
                let e = 0;
                while e < extra {
                    out.push(q);
                    e = e + 1;
                }
                let k = 0;
                while k < n {
                    self.bump();
                    k = k + 1;
                }
                break;
            }
            let c = self.cur();
            if c < " " && c != "\t" && c != "\n" && c != "\r" {
                raise self.invalid();
            }
            out.push(c);
            self.bump();
        }
        return self.bytes_to_str(out)?;
    }

    fn parse_ml_basic() -> Result<string, TomlError> {
        self.bump();
        self.bump();
        self.bump();
        self.skip_opening_nl();
        let out: Vec<byte> = Vec::new();
        let q: byte = "\"";
        while true {
            if self.at_end() {
                raise self.invalid();
            }
            let n = self.count_quote(q);
            if n >= 3 {
                if n > 5 {
                    raise self.invalid();
                }
                let extra = n - 3;
                let e = 0;
                while e < extra {
                    out.push(q);
                    e = e + 1;
                }
                let k = 0;
                while k < n {
                    self.bump();
                    k = k + 1;
                }
                break;
            }
            let c = self.cur();
            if c == "\\" {
                self.bump();
                if self.at_end() {
                    raise self.invalid();
                }
                let n2 = self.cur();
                if n2 == " " || n2 == "\t" || n2 == "\n" || n2 == "\r" {
                    while !self.at_end() {
                        let w = self.cur();
                        if w == " " || w == "\t" || w == "\n" || w == "\r" {
                            self.bump();
                        } else {
                            break;
                        }
                    }
                    continue;
                }
                self.parse_escape(out)?;
                continue;
            }
            if c < " " && c != "\t" && c != "\n" && c != "\r" {
                raise self.invalid();
            }
            out.push(c);
            self.bump();
        }
        return self.bytes_to_str(out)?;
    }

    fn parse_string() -> Result<string, TomlError> {
        if self.at_end() {
            raise self.invalid();
        }
        let c = self.cur();
        if c == "\"" {
            if self.count_quote("\"") >= 3 {
                return self.parse_ml_basic()?;
            }
            return self.parse_basic_string()?;
        }
        if c == "'" {
            if self.count_quote("'") >= 3 {
                return self.parse_ml_literal()?;
            }
            return self.parse_literal_string()?;
        }
        raise self.invalid();
    }

    fn is_bare_start(byte c) -> bool {
        if c >= "A" && c <= "Z" {
            return true;
        }
        if c >= "a" && c <= "z" {
            return true;
        }
        if c >= "0" && c <= "9" {
            return true;
        }
        return c == "_" || c == "-";
    }

    fn parse_bare_key() -> Result<string, TomlError> {
        let out: Vec<byte> = Vec::new();
        if self.at_end() || !self.is_bare_start(self.cur()) {
            raise self.invalid();
        }
        while !self.at_end() && self.is_bare_start(self.cur()) {
            out.push(self.cur());
            self.bump();
        }
        return self.bytes_to_str(out)?;
    }

    fn parse_key_part() -> Result<string, TomlError> {
        self.skip_space();
        if self.at_end() {
            raise self.invalid();
        }
        let c = self.cur();
        if c == "\"" {
            return self.parse_basic_string()?;
        }
        if c == "'" {
            return self.parse_literal_string()?;
        }
        return self.parse_bare_key()?;
    }

    fn parse_keys(Vec<string> keys) -> Result<(), TomlError> {
        keys.push(self.parse_key_part()?);
        while true {
            self.skip_space();
            if self.at_end() || self.cur() != "." {
                break;
            }
            self.bump();
            keys.push(self.parse_key_part()?);
        }
        return ();
    }

    fn starts_with(string lit) -> bool {
        let b = to_bytes(lit);
        let k = 0;
        while k < len(b) {
            if self.i + k >= len(self.bytes) {
                return false;
            }
            if self.bytes[self.i + k] != b[k] {
                return false;
            }
            k = k + 1;
        }
        return true;
    }

    fn eat(string lit) -> Result<(), TomlError> {
        let b = to_bytes(lit);
        let k = 0;
        while k < len(b) {
            if self.at_end() || self.cur() != b[k] {
                raise self.invalid();
            }
            self.bump();
            k = k + 1;
        }
        return ();
    }

    fn ident_cont() -> bool {
        if self.at_end() {
            return false;
        }
        return self.is_bare_start(self.cur());
    }

    fn parse_inf_nan(bool neg, bool signed) -> Result<int, TomlError> {
        let _ = signed;
        if self.starts_with("inf") {
            self.eat("inf")?;
            if self.ident_cont() {
                raise self.invalid();
            }
            let x = exp(1000.0);
            if neg {
                x = 0.0 - x;
            }
            return self.store.add(TAG_FLOAT, neg, FLT_INF, x, "", "");
        }
        if self.starts_with("nan") {
            self.eat("nan")?;
            if self.ident_cont() {
                raise self.invalid();
            }
            let x = sqrt(0.0 - 1.0);
            return self.store.add(TAG_FLOAT, neg, FLT_NAN, x, "", "");
        }
        raise self.invalid();
    }

    fn digit() -> bool {
        if self.at_end() {
            return false;
        }
        let c = self.cur();
        return c >= "0" && c <= "9";
    }

    fn take_digits(int n) -> Result<int, TomlError> {
        let v = 0;
        let k = 0;
        while k < n {
            if self.at_end() {
                raise self.invalid();
            }
            let c = self.bytes[self.i];
            if c < "0" {
                raise self.invalid();
            }
            if c > "9" {
                raise self.invalid();
            }
            let d: int = self.byte_digit(c);
            if d < 0 {
                raise self.invalid();
            }
            v = v * 10 + d;
            self.bump();
            k = k + 1;
        }
        return v;
    }

    fn is_leap(int year) -> bool {
        if year % 4 != 0 {
            return false;
        }
        if year % 100 != 0 {
            return true;
        }
        return year % 400 == 0;
    }

    fn month_days(int year, int month) -> int {
        if month == 4 {
            return 30;
        }
        if month == 6 {
            return 30;
        }
        if month == 9 {
            return 30;
        }
        if month == 11 {
            return 30;
        }
        if month == 2 {
            if self.is_leap(year) {
                return 29;
            }
            return 28;
        }
        if month < 1 {
            return 0;
        }
        if month > 12 {
            return 0;
        }
        return 31;
    }

    fn parse_frac() -> Result<(), TomlError> {
        if self.at_end() || self.cur() != "." {
            return ();
        }
        self.bump();
        if !self.digit() {
            raise self.invalid();
        }
        while self.digit() {
            self.bump();
        }
        return ();
    }

    fn parse_time_hms() -> Result<(), TomlError> {
        let h = self.take_digits(2)?;
        if self.at_end() {
            raise self.invalid();
        }
        if self.cur() != ":" {
            raise self.invalid();
        }
        self.bump();
        let m = self.take_digits(2)?;
        if self.at_end() {
            raise self.invalid();
        }
        if self.cur() != ":" {
            raise self.invalid();
        }
        self.bump();
        let s = self.take_digits(2)?;
        if h > 23 {
            raise self.invalid();
        }
        if m > 59 {
            raise self.invalid();
        }
        if s > 60 {
            raise self.invalid();
        }
        return self.parse_frac()?;
    }

    fn parse_offset() -> Result<(), TomlError> {
        if self.at_end() {
            return ();
        }
        let c = self.cur();
        if c == "Z" {
            self.bump();
            return ();
        }
        if c == "z" {
            self.bump();
            return ();
        }
        if c == "+" {
            self.bump();
            let h = self.take_digits(2)?;
            if self.at_end() {
                raise self.invalid();
            }
            if self.cur() != ":" {
                raise self.invalid();
            }
            self.bump();
            let m = self.take_digits(2)?;
            if h > 23 {
                raise self.invalid();
            }
            if m > 59 {
                raise self.invalid();
            }
            return ();
        }
        if c == "-" {
            self.bump();
            let h = self.take_digits(2)?;
            if self.at_end() {
                raise self.invalid();
            }
            if self.cur() != ":" {
                raise self.invalid();
            }
            self.bump();
            let m = self.take_digits(2)?;
            if h > 23 {
                raise self.invalid();
            }
            if m > 59 {
                raise self.invalid();
            }
            return ();
        }
        return ();
    }

    fn parse_datetime() -> Result<int, TomlError> {
        let start = self.i;
        let line = self.line;
        let col = self.col;
        let first = self.take_digits(2)?;
        let time_only = false;
        if !self.at_end() {
            if self.cur() == ":" {
                time_only = true;
            }
        }
        if time_only {
            let h = first;
            self.bump();
            let m = self.take_digits(2)?;
            if self.at_end() {
                raise self.invalid();
            }
            if self.cur() != ":" {
                raise self.invalid();
            }
            self.bump();
            let s = self.take_digits(2)?;
            if h > 23 {
                raise self.invalid();
            }
            if m > 59 {
                raise self.invalid();
            }
            if s > 60 {
                raise self.invalid();
            }
            self.parse_frac()?;
        } else {
            let y = first * 100 + self.take_digits(2)?;
            if self.at_end() {
                raise self.invalid();
            }
            if self.cur() != "-" {
                raise self.invalid();
            }
            self.bump();
            let mo = self.take_digits(2)?;
            if self.at_end() {
                raise self.invalid();
            }
            if self.cur() != "-" {
                raise self.invalid();
            }
            self.bump();
            let d = self.take_digits(2)?;
            let md = self.month_days(y, mo);
            if mo < 1 {
                raise self.invalid();
            }
            if md == 0 {
                raise self.invalid();
            }
            if d < 1 {
                raise self.invalid();
            }
            if d > md {
                raise self.invalid();
            }
            if !self.at_end() {
                let sep = self.cur();
                let is_sep = false;
                if sep == "T" {
                    is_sep = true;
                }
                if sep == "t" {
                    is_sep = true;
                }
                if sep == " " {
                    is_sep = true;
                }
                if is_sep {
                    self.bump();
                    self.parse_time_hms()?;
                    self.parse_offset()?;
                }
            }
        }
        let end = self.i;
        let slice: Vec<byte> = Vec::new();
        let j = start;
        while j < end {
            slice.push(self.bytes[j]);
            j = j + 1;
        }
        let s = match from_bytes(slice) {
            Result::Ok(t) => t,
            Result::Err(_) => raise TomlError::Utf8 { line: line, column: col },
        };
        return self.store.add(TAG_DT, false, 0, 0.0, s, "");
    }

    fn underscore_ok(byte prev, byte next) -> bool {
        let pd = prev >= "0" && prev <= "9" || (prev >= "a" && prev <= "f") || (prev >= "A" && prev <= "F");
        let nd = next >= "0" && next <= "9" || (next >= "a" && next <= "f") || (next >= "A" && next <= "F");
        return pd && nd;
    }

    fn parse_int_digits(int start, int end, int radix, int line, int column) -> Result<int, TomlError> {
        let value = 0;
        let j = start;
        let saw = false;
        while j < end {
            if self.bytes[j] == "_" {
                j = j + 1;
                continue;
            }
            let d = -1;
            if radix == 10 {
                d = self.byte_digit(self.bytes[j]);
            } else {
                if radix == 16 {
                    d = self.hex_val(self.bytes[j]);
                } else {
                    if radix == 8 {
                        d = self.byte_digit(self.bytes[j]);
                        if d > 7 {
                            d = -1;
                        }
                    } else {
                        d = self.byte_digit(self.bytes[j]);
                        if d > 1 {
                            d = -1;
                        }
                    }
                }
            }
            if d < 0 {
                raise TomlError::Number { line: line, column: column };
            }
            let next = value * radix + d;
            if value > 0 {
                if next < value {
                    raise TomlError::Number { line: line, column: column };
                }
            }
            value = next;
            saw = true;
            j = j + 1;
        }
        if !saw {
            raise TomlError::Number { line: line, column: column };
        }
        return value;
    }

    fn scan_underscored(int radix) -> Result<(), TomlError> {
        let start = self.i;
        if self.at_end() {
            raise self.number_err();
        }
        let prev: byte = "_";
        let saw = false;
        while !self.at_end() {
            let c = self.cur();
            let d = false;
            if radix == 10 {
                d = c >= "0" && c <= "9";
            } else {
                if radix == 16 {
                    d = self.hex_val(c) >= 0;
                } else {
                    if radix == 8 {
                        d = c >= "0" && c <= "7";
                    } else {
                        d = c == "0" || c == "1";
                    }
                }
            }
            if d {
                prev = c;
                saw = true;
                self.bump();
                continue;
            }
            if c == "_" {
                if self.i + 1 >= len(self.bytes) {
                    raise self.number_err();
                }
                let nxt = self.bytes[self.i + 1];
                if !self.underscore_ok(prev, nxt) {
                    raise self.number_err();
                }
                if radix == 10 {
                    if !(prev >= "0" && prev <= "9") {
                        raise self.number_err();
                    }
                }
                self.bump();
                continue;
            }
            break;
        }
        if !saw || start == self.i {
            raise self.number_err();
        }
        return ();
    }

    fn parse_float_slice(int start, int end, int line, int column) -> Result<float, TomlError> {
        let ten: float = 10.0;
        let i = start;
        let sign = 1.0;
        if i < end {
            if self.bytes[i] == "+" || self.bytes[i] == "-" {
                if self.bytes[i] == "-" {
                    sign = 0.0 - 1.0;
                }
                i = i + 1;
            }
        }
        let value = 0.0;
        let saw = false;
        while i < end {
            let c = self.bytes[i];
            if c == "_" {
                i = i + 1;
                continue;
            }
            if c < "0" || c > "9" {
                break;
            }
            let d: int = (c as int) - ("0" as byte as int);
            value = value * ten + (d as float);
            saw = true;
            i = i + 1;
        }
        let frac_places = 0;
        if i < end {
            if self.bytes[i] == "." {
                i = i + 1;
                while i < end {
                    let c = self.bytes[i];
                    if c == "_" {
                        i = i + 1;
                        continue;
                    }
                    if c < "0" || c > "9" {
                        break;
                    }
                    let d: int = (c as int) - ("0" as byte as int);
                    value = value * ten + (d as float);
                    frac_places = frac_places + 1;
                    saw = true;
                    i = i + 1;
                }
            }
        }
        if !saw {
            raise TomlError::Number { line: line, column: column };
        }
        let pfrac = 0;
        while pfrac < frac_places {
            value = value / ten;
            pfrac = pfrac + 1;
        }
        let exponent = 0;
        let divide_exp = false;
        if i < end {
            let c = self.bytes[i];
            if c == "e" || c == "E" {
                i = i + 1;
                if i < end {
                    if self.bytes[i] == "_" {
                        raise TomlError::Number { line: line, column: column };
                    }
                    if self.bytes[i] == "+" || self.bytes[i] == "-" {
                        divide_exp = self.bytes[i] == "-";
                        i = i + 1;
                    }
                }
                let exp_start = i;
                while i < end {
                    let d = self.bytes[i];
                    if d == "_" {
                        i = i + 1;
                        continue;
                    }
                    if d < "0" || d > "9" {
                        break;
                    }
                    exponent = exponent * 10 + ((d as int) - ("0" as byte as int));
                    i = i + 1;
                }
                if i == exp_start {
                    raise TomlError::Number { line: line, column: column };
                }
            }
        }
        if i != end {
            raise TomlError::Number { line: line, column: column };
        }
        let scaled = sign * value;
        let e = 0;
        while e < exponent {
            if divide_exp {
                scaled = scaled / ten;
            } else {
                scaled = scaled * ten;
            }
            e = e + 1;
        }
        if scaled != scaled {
            raise TomlError::Number { line: line, column: column };
        }
        if scaled != 0.0 {
            if scaled * 2.0 == scaled {
                raise TomlError::Number { line: line, column: column };
            }
        }
        return scaled;
    }

    fn parse_number() -> Result<int, TomlError> {
        let line = self.line;
        let col = self.col;
        let start = self.i;
        let neg = false;
        let signed = false;
        if !self.at_end() {
            if self.cur() == "+" {
                signed = true;
                self.bump();
            } else {
                if self.cur() == "-" {
                    signed = true;
                    neg = true;
                    self.bump();
                }
            }
        }
        if self.starts_with("inf") || self.starts_with("nan") {
            return self.parse_inf_nan(neg, signed)?;
        }
        if self.at_end() {
            raise TomlError::Invalid { line: line, column: col };
        }
        if self.cur() == "0" && self.i + 1 < len(self.bytes) {
            let n = self.bytes[self.i + 1];
            if n == "x" || n == "X" || n == "o" || n == "O" || n == "b" || n == "B" {
                if signed {
                    raise TomlError::Invalid { line: line, column: col };
                }
                self.bump();
                self.bump();
                let radix = 16;
                if n == "o" || n == "O" {
                    radix = 8;
                } else {
                    if n == "b" || n == "B" {
                        radix = 2;
                    }
                }
                let dig_start = self.i;
                self.scan_underscored(radix)?;
                let v = self.parse_int_digits(dig_start, self.i, radix, line, col)?;
                return self.store.add(TAG_INT, false, v, 0.0, "", "");
            }
        }
        if self.cur() == "0" {
            self.bump();
            if !self.at_end() && self.cur() >= "0" && self.cur() <= "9" {
                raise TomlError::Invalid { line: self.line, column: self.col };
            }
        } else {
            if !self.digit() {
                raise TomlError::Invalid { line: self.line, column: self.col };
            }
            self.scan_underscored(10)?;
        }
        let is_float = false;
        if !self.at_end() && self.cur() == "." {
            is_float = true;
            self.bump();
            if self.at_end() || self.cur() == "_" || !(self.cur() >= "0" && self.cur() <= "9") {
                raise TomlError::Invalid { line: self.line, column: self.col };
            }
            self.scan_underscored(10)?;
        }
        if !self.at_end() {
            if self.cur() == "e" || self.cur() == "E" {
                is_float = true;
                self.bump();
                if !self.at_end() {
                    if self.cur() == "+" || self.cur() == "-" {
                        self.bump();
                    }
                }
                if self.at_end() || self.cur() == "_" || !(self.cur() >= "0" && self.cur() <= "9") {
                    raise TomlError::Invalid { line: self.line, column: self.col };
                }
                self.scan_underscored(10)?;
            }
        }
        let end = self.i;
        if is_float {
            let f = self.parse_float_slice(start, end, line, col)?;
            return self.store.add(TAG_FLOAT, false, FLT_FINITE, f, "", "");
        }
        let adj = 0;
        if signed {
            adj = 1;
        }
        let v = self.parse_int_digits(start + adj, end, 10, line, col)?;
        if neg {
            if v == 0 {
                return self.store.add(TAG_INT, false, 0, 0.0, "", "");
            }
            return self.store.add(TAG_INT, false, 0 - v, 0.0, "", "");
        }
        return self.store.add(TAG_INT, false, v, 0.0, "", "");
    }

    fn descend_one(int node, string key, bool create) -> Result<int, TomlError> {
        let child = self.store.find_child(node, key);
        if child < 0 {
            if !create {
                raise self.invalid();
            }
            let t = self.store.add(TAG_TAB, false, KIND_IMPLICIT, 0.0, "", key);
            self.store.attach(node, t);
            return t;
        }
        if self.store.tags[child] == TAG_ARR && self.store.ints[child] == ARR_AOT {
            let last = self.store.last[child];
            if last < 0 {
                raise self.invalid();
            }
            return last;
        }
        if self.store.tags[child] != TAG_TAB {
            raise self.invalid();
        }
        if self.store.ints[child] == KIND_INLINE {
            raise self.invalid();
        }
        return child;
    }

    fn walk_parents(int from, Vec<string> keys, int last_i) -> Result<int, TomlError> {
        let node = from;
        let i = 0;
        while i < last_i {
            node = self.descend_one(node, keys[i], true)?;
            i = i + 1;
        }
        return node;
    }

    fn define_table(Vec<string> keys, bool aot) -> Result<int, TomlError> {
        let n = len(keys);
        if n == 0 {
            raise self.invalid();
        }
        let parent = self.walk_parents(self.root, keys, n - 1)?;
        let last = keys[n - 1];
        let child = self.store.find_child(parent, last);
        if aot {
            if child < 0 {
                let arr = self.store.add(TAG_ARR, false, ARR_AOT, 0.0, "", last);
                self.store.attach(parent, arr);
                let t = self.store.add(TAG_TAB, false, KIND_EXPLICIT, 0.0, "", "");
                self.store.attach(arr, t);
                return t;
            }
            if self.store.tags[child] != TAG_ARR || self.store.ints[child] != ARR_AOT {
                raise self.invalid();
            }
            let t = self.store.add(TAG_TAB, false, KIND_EXPLICIT, 0.0, "", "");
            self.store.attach(child, t);
            return t;
        }
        if child < 0 {
            let t = self.store.add(TAG_TAB, false, KIND_EXPLICIT, 0.0, "", last);
            self.store.attach(parent, t);
            return t;
        }
        if self.store.tags[child] != TAG_TAB {
            raise self.invalid();
        }
        if self.store.ints[child] == KIND_INLINE {
            raise self.invalid();
        }
        if self.store.ints[child] == KIND_EXPLICIT {
            raise self.invalid();
        }
        self.store.ints[child] = KIND_EXPLICIT;
        return child;
    }

    fn insert_keyval(int from, Vec<string> keys, int val) -> Result<(), TomlError> {
        let n = len(keys);
        if n == 0 {
            raise self.invalid();
        }
        let parent = self.walk_parents(from, keys, n - 1)?;
        let last = keys[n - 1];
        if self.store.find_child(parent, last) >= 0 {
            raise self.invalid();
        }
        self.store.keys[val] = last;
        self.store.attach(parent, val);
        return ();
    }

    #[max_depth(256)]
    fn parse_value() -> Result<int, TomlError> {
        if self.at_end() {
            raise self.invalid();
        }
        let c = self.cur();
        if c == "\"" || c == "'" {
            let s = self.parse_string()?;
            return self.store.add(TAG_STR, false, 0, 0.0, s, "");
        }
        if c == "t" {
            self.eat("true")?;
            if self.ident_cont() {
                raise self.invalid();
            }
            return self.store.add(TAG_BOOL, true, 0, 0.0, "", "");
        }
        if c == "f" {
            self.eat("false")?;
            if self.ident_cont() {
                raise self.invalid();
            }
            return self.store.add(TAG_BOOL, false, 0, 0.0, "", "");
        }
        if c == "i" {
            return self.parse_inf_nan(false, false)?;
        }
        if c == "n" {
            return self.parse_inf_nan(false, false)?;
        }
        if c == "[" {
            return self.parse_array()?;
        }
        if c == "{" {
            return self.parse_inline_table()?;
        }
        if c >= "0" && c <= "9" {
            let dt = false;
            let jd = self.i + 4;
            let jd2 = self.i + 7;
            if jd2 < len(self.bytes) {
                if self.bytes[jd] == "-" {
                    if self.bytes[jd2] == "-" {
                        dt = true;
                    }
                }
            }
            let jc = self.i + 2;
            let jc2 = self.i + 5;
            if jc2 < len(self.bytes) {
                if self.bytes[jc] == ":" {
                    if self.bytes[jc2] == ":" {
                        dt = true;
                    }
                }
            }
            if dt {
                return self.parse_datetime()?;
            }
            return self.parse_number()?;
        }
        if c == "+" {
            return self.parse_number()?;
        }
        if c == "-" {
            return self.parse_number()?;
        }
        raise self.invalid();
    }

    #[max_depth(256)]
    fn parse_array() -> Result<int, TomlError> {
        self.bump();
        let arr = self.store.add(TAG_ARR, false, ARR_VAL, 0.0, "", "");
        self.skip_trivia();
        if !self.at_end() && self.cur() == "]" {
            self.bump();
            return arr;
        }
        while true {
            self.skip_trivia();
            if !self.at_end() && self.cur() == "]" {
                self.bump();
                break;
            }
            let kid = self.parse_value()?;
            self.store.attach(arr, kid);
            self.skip_trivia();
            if !self.at_end() && self.cur() == "," {
                self.bump();
                self.skip_trivia();
                continue;
            }
            if !self.at_end() && self.cur() == "]" {
                self.bump();
                break;
            }
            raise self.invalid();
        }
        return arr;
    }

    #[max_depth(256)]
    fn parse_inline_table() -> Result<int, TomlError> {
        self.bump();
        let tab = self.store.add(TAG_TAB, false, KIND_INLINE, 0.0, "", "");
        self.skip_space();
        if !self.at_end() && self.cur() == "}" {
            self.bump();
            return tab;
        }
        while true {
            self.skip_space();
            let keys: Vec<string> = Vec::new();
            self.parse_keys(keys)?;
            self.skip_space();
            if self.at_end() || self.cur() != "=" {
                raise self.invalid();
            }
            self.bump();
            self.skip_space();
            let val = self.parse_value()?;
            self.insert_keyval(tab, keys, val)?;
            self.skip_space();
            if !self.at_end() && self.cur() == "," {
                self.bump();
                self.skip_space();
                if !self.at_end() && self.cur() == "}" {
                    raise self.invalid();
                }
                continue;
            }
            if !self.at_end() && self.cur() == "}" {
                self.bump();
                break;
            }
            raise self.invalid();
        }
        return tab;
    }

    fn parse_keyval() -> Result<(), TomlError> {
        let keys: Vec<string> = Vec::new();
        self.parse_keys(keys)?;
        self.skip_space();
        if self.at_end() || self.cur() != "=" {
            raise self.invalid();
        }
        self.bump();
        self.skip_trivia();
        let val = self.parse_value()?;
        self.insert_keyval(self.current, keys, val)?;
        return self.expect_stmt_end()?;
    }

    fn parse_header() -> Result<(), TomlError> {
        self.bump();
        let aot = false;
        if !self.at_end() && self.cur() == "[" {
            aot = true;
            self.bump();
        }
        let keys: Vec<string> = Vec::new();
        self.skip_space();
        self.parse_keys(keys)?;
        self.skip_space();
        if self.at_end() || self.cur() != "]" {
            raise self.invalid();
        }
        self.bump();
        if aot {
            if self.at_end() || self.cur() != "]" {
                raise self.invalid();
            }
            self.bump();
        }
        self.current = self.define_table(keys, aot)?;
        return self.expect_stmt_end()?;
    }

    fn parse_document() -> Result<int, TomlError> {
        if len(self.bytes) >= 3 {
            if self.bytes[0] == (239 as byte) && self.bytes[1] == (187 as byte) && self.bytes[2] == (191 as byte) {
                self.i = 3;
            }
        }
        self.root = self.store.add(TAG_TAB, false, KIND_EXPLICIT, 0.0, "", "");
        self.current = self.root;
        while true {
            self.skip_trivia();
            if self.at_end() {
                break;
            }
            if self.cur() == "[" {
                self.parse_header()?;
            } else {
                self.parse_keyval()?;
            }
        }
        return self.root;
    }
}

/// TOML 1.0 codec.
class Toml {
    spec: int,
}

impl Toml {
    /// TOML v1.0.0 encode/decode.
    static fn v1() -> Toml {
        return new Toml(1);
    }

    fn encode(TomlValue value) -> Result<Vec<byte>, TomlError> {
        let out: Vec<byte> = Vec::new();
        value.emit(out)?;
        return out;
    }

    fn decode(Vec<byte> bytes) -> Result<TomlValue, TomlError> {
        let _ = self.spec;
        let p = new Parser(bytes, 0, 1, 1, Store::new(), -1, -1);
        let root = p.parse_document()?;
        return TomlValue::wrap(p.store, root);
    }

    fn encode_str(TomlValue value) -> Result<string, TomlError> {
        let bytes = self.encode(value)?;
        return match from_bytes(bytes) {
            Result::Ok(s) => s,
            Result::Err(_) => raise TomlError::Utf8 { line: 1, column: 1 },
        };
    }

    fn decode_str(string s) -> Result<TomlValue, TomlError> {
        return self.decode(to_bytes(s))?;
    }
}
