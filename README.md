# coil-toml

Userland TOML 1.0 for [coil](https://github.com/ardax-corp/coil-lang). Package name is `toml`, so `use toml::{Toml, TomlValue, TomlError}` resolves here.

Pure Coil encode/decode. No native library. The tree is an arena of primitive vecs; a `TomlValue` is a `(store, idx)` handle — named-module recursive `Vec<TomlValue>` does not unify (`TomlValue` vs `toml::TomlValue`).

One module, `toml` (`src/toml.coil`): the `Toml` codec, the `TomlValue` handle it decodes to, and the `TomlError` it reports.

## Example

```coil
use toml::{Toml, TomlError};
use io::sync::{println};
use string::{format};

fn main() {
    let t = Toml::v1();
    match t.decode_str("name = \"demo\"\n\n[server]\nport = 8080\n") {
        Result::Ok(v) => {
            let server = v.get("server");
            if server.has("port") {
                println(format("port %i", server.get("port").i))?;
            }
            println(t.encode_str(v).unwrap_or("encode failed"))?;
        },
        Result::Err(TomlError::Invalid { line, column }) => {
            println(format("invalid TOML at %i:%i", line, column))?;
        },
        Result::Err(_) => {
            println("bad number or UTF-8")?;
        },
    }
}
```

Run it with `coil --root ../coil-stdlib/src --root ../coil-toml/src main.coil` (prints `port 8080`, then the document re-encoded).

## API

```coil
use toml::{Toml, TomlValue, TomlError};

let t = Toml::v1();
let v = t.decode_str("a = 1\n\n[b]\nc = true\n")?;
let bytes = t.encode(v)?;
```

`Toml::v1()` is TOML 1.0.0. Invalid input returns `TomlError` with 1-based line/column (`Invalid`, `Utf8`, `Number`), not panic.

| Method | Role |
|--------|------|
| `Toml::v1()` | TOML 1.0 codec |
| `decode` / `encode` | `Vec<byte>` |
| `decode_str` / `encode_str` | UTF-8 string helpers |

Reading a decoded value (`TomlValue`):

| Method / field | Role |
|--------|------|
| `is_string()` … `is_table()` | type checks |
| `has(key)` / `get(key)` | table member (`get` returns the table itself when the key is missing) |
| `child(n)` / `key_at(n)` | nth array element or table value / nth table key |
| `array_len()` / `table_len()` | child counts |
| `s` / `i` / `f` / `flag` | scalar payloads (string or date-time text, int, float, bool) |

The document root is always a table (empty input is an empty table). Objects/tables are ordered children; each member's `keys[child]` is the key. Duplicate keys are an error.

Covered syntax: comments, bare/quoted/dotted keys, basic and literal strings (including multiline), integers (decimal/hex/octal/binary, underscores, signs), floats (`inf`/`nan`), booleans, offset/local datetimes, local dates and times, arrays (trailing commas), inline tables, `[table]` headers, and `[[array-of-tables]]`.

## Layout

| Path | Role |
|------|------|
| `src/toml.coil` | `Toml`, `TomlValue`, `TomlError`, parser/stringify |
| `coil.toml` | spool manifest (`[package] name = "toml"`); coil does not read it |

## Consume

```bash
spool add toml --git https://github.com/ardax-corp/coil-toml.git --rev <commit SHA>
```

No tags yet, so pin a commit. Without spool, pass `--root ../coil-toml/src` to `coil`. See [docs/consume.md](docs/consume.md).

## Test

```bash
# from coil-toml, with coil on PATH and coil-stdlib checked out next to it
coil test --root ../coil-stdlib/src
```

This runs `tests/` and the examples in the `///` docs of `src/toml.coil`.

## License

MIT. See [LICENSE](LICENSE).
