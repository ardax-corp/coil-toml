# Consuming coil-toml

This package is `toml`. `use toml::{Toml, TomlValue, TomlError}` resolves from `src/toml.hy`. One-shot encode/decode ships here. Do not add a native/FFI dep.

## Depend on it

With [spool](https://github.com/ardax-corp/spool):

```bash
spool add toml --git https://github.com/ardax-corp/coil-toml.git --rev <commit SHA>
```

This repo has no tags, so pin a commit with `--rev`. spool records the dep in `coil.toml`, writes `coil.lock` (`rev` + `content_hash`), links `.spool/deps/toml`, and passes `--root` for it and coil-stdlib to `coil` on `spool build` / `run` / `test`.

Without spool, clone this repo next to your project and pass the roots yourself. coil reads no `coil.toml` and no `coil.lock`.

```bash
coil --root ../coil-toml/src main.hy
```

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
        default => false,
    },
}
```
