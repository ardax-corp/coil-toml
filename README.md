# coil-toml

Userland TOML 1.0 for [coil](https://github.com/ardax-corp/coil-lang). Package name is `toml`, so `use toml::{Toml, TomlValue, TomlError}` resolves here.

Pure Coil encode/decode. No native library. The tree is an arena of primitive vecs; a `TomlValue` is a `(store, idx)` handle — named-module recursive `Vec<TomlValue>` does not unify (`TomlValue` vs `toml::TomlValue`).

## API

```coil
use toml::{Toml, TomlValue, TomlError};

let t = Toml::v1();
let v = t.decode_str("a = 1\n\n[b]\nc = true\n")?;
let bytes = t.encode(v)?;
```

`Toml::v1()` is TOML 1.0.0. Invalid input returns `TomlError` with 1-based line/column (`Invalid`, `Io`, `Utf8`, `Number`), not panic.

| Method | Role |
|--------|------|
| `Toml::v1()` | TOML 1.0 codec |
| `decode` / `encode` | `Vec<byte>` |
| `decode_str` / `encode_str` | UTF-8 string helpers |

The document root is always a table (empty input is an empty table). Objects/tables are ordered children; each member's `keys[child]` is the key. Duplicate keys are an error.

Covered syntax: comments, bare/quoted/dotted keys, basic and literal strings (including multiline), integers (decimal/hex/octal/binary, underscores, signs), floats (`inf`/`nan`), booleans, offset/local datetimes, local dates and times, arrays (trailing commas), inline tables, `[table]` headers, and `[[array-of-tables]]`.

## Layout

| Path | Role |
|------|------|
| `src/toml.hy` | `Toml`, `TomlValue`, `TomlError`, parser/stringify |
| `coil.toml` | `[package] name = "toml"` so `use toml::{…}` resolves |

## Consume

Sibling checkout, or a git dep plus `coil.lock` pin. Call `Toml::v1()` from [docs/consume.md](docs/consume.md).

```toml
[dependencies]
toml = { git = "https://github.com/ardax-corp/coil-toml.git" }
```

`{ git }` is the parseable form. `version` is optional schema, not a tag. The pin is `coil.lock` `rev` + `content_hash`.

## Test

```bash
# from coil-toml (coil on PATH or ../coil-lang/target/debug/coil)
coil test
```

## License

MIT. See [LICENSE](LICENSE).
