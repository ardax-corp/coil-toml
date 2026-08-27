# Consuming coil-toml

This package is `toml`. `use toml::{Toml, TomlValue, TomlError}` resolves from `src/toml.hy`. One-shot encode/decode ships here. Do not add a native/FFI dep.

Coil-to-Coil deps will be spool-owned once a public `spool` CLI exists. Until then `{ git }` parses and the pin is `coil.lock` `rev` + `content_hash`.

## Sibling checkout

Clone this repo next to your project. In the consumer `coil.toml`:

```toml
[module]
roots = ["./src", "../coil-toml/src"]
```

`roots` is what loads `src/toml.hy`. The compiler does not follow path deps for discovery.

## Git dep and coil.lock

```toml
[dependencies]
toml = { git = "https://github.com/ardax-corp/coil-toml.git" }

[module]
roots = ["./src", "./.spool/deps/toml/src"]
```

This repo has no tags. The pin is `coil.lock` `rev` + `content_hash`. Omit `tag`. Use sibling checkout until spool materializes `.spool/deps`. The compiler does not read `coil.lock` and does not inject roots.

```
# spool lockfile v1
[[package]]
name = 'toml'
git = 'https://github.com/ardax-corp/coil-toml.git'
rev = '<commit SHA>'
content_hash = '<tree SHA>'
```

`rev` is the commit. `content_hash` is that commit's git tree (`git rev-parse 'HEAD^{tree}'`). Replace both when you move the pin.

## Call Toml::v1()

Signatures are in [`src/toml.hy`](../src/toml.hy). Call patterns are in [`tests/v1.hy`](../tests/v1.hy).

```coil
use toml::{Toml, TomlValue, TomlError};

let t = Toml::v1();
let v = t.decode_str("a = 1\n\n[owner]\nname = \"x\"\n")?;
let s = t.encode_str(v)?;
let bytes = t.encode(v)?;
```

`decode_str` takes `string` and returns `Result<TomlValue, TomlError>`. `encode_str` takes `TomlValue` and returns `Result<string, TomlError>`. `decode` takes `Vec<byte>` and returns `Result<TomlValue, TomlError>`. `encode` takes `TomlValue` and returns `Result<Vec<byte>, TomlError>`.

`decode_str` is `to_bytes` then `decode`. `encode_str` is `encode` then `from_bytes`. A `from_bytes` failure on encode is `TomlError::Utf8`.

Prefer matching directly on `decode` / `decode_str` results. Storing `Result<TomlValue, TomlError>` in a `let` before matching can mis-handle the payload until a compiler fix lands.

### TomlValue

`TomlValue` is a class plus arena handle, not an enum. Nested tables and arrays come from decode. Scalar constructors:

```coil
TomlValue::from_bool(true)
TomlValue::from_int(7)
TomlValue::from_float(1.5)
TomlValue::from_string("hi")
TomlValue::from_datetime("1979-05-27T07:32:00Z")
TomlValue::empty_table()
```

Predicates: `is_string`, `is_int`, `is_float`, `is_bool`, `is_datetime`, `is_array`, `is_table`. Lengths: `array_len`, `table_len`. Access: `child(n)`, `key_at(n)`, `has(key)`, `get(key)`. Scalar payloads on the handle are `flag`, `i`, `f`, `s`.

```coil
let n = t.decode_str("a = -42\n")?;
let is_neg = n.get("a").is_int() && n.get("a").i == (0 - 42);
```

A number token with no `.` / `e` / `E` / `inf` / `nan` that fits in i64 is an int. Otherwise it is a float. `inf` / `-inf` / `nan` use `i` as a kind (`1` inf, `2` nan) and `flag` for the sign of inf.

### TomlError

```coil
enum TomlError {
    Invalid { line: int, column: int },
    Io { line: int, column: int },
    Utf8 { line: int, column: int },
    Number { line: int, column: int },
}
```

`line` and `column` are 1-based. Column counts bytes in the line. Malformed input returns `TomlError::Invalid` with position, not a panic.

```coil
match t.decode_str("a = 1\na = 2\n") {
    Result::Ok(_) => false,
    Result::Err(e) => match e {
        TomlError::Invalid { line, column } => line >= 1 && column >= 1,
        _ => false,
    },
}
```
