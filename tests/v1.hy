// TOML 1.0 decode/encode tests for Toml::v1.
// Test bodies use assert's string error; TOML Results are matched, not `?`.
use toml::{Toml, TomlValue, TomlError};
use string::{from_bytes, to_bytes};

fn codec() -> Toml {
    return Toml::v1();
}

fn must_decode(string s) -> TomlValue {
    return match codec().decode_str(s) {
        Result::Ok(v) => v,
        Result::Err(_) => panic "decode failed",
    };
}

fn must_encode(TomlValue v) -> string {
    return match codec().encode_str(v) {
        Result::Ok(s) => s,
        Result::Err(_) => panic "encode failed",
    };
}

fn is_invalid(Result<TomlValue, TomlError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            TomlError::Invalid { line, column } => line >= 1 && column >= 1,
            default => false,
        },
    };
}

fn is_number(Result<TomlValue, TomlError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            TomlError::Number { line, column } => line >= 1 && column >= 1,
            default => false,
        },
    };
}

test("empty document") {
    let v = must_decode("");
    assert(v.is_table() && v.table_len() == 0, "empty")?;
    assert(must_encode(v) == "")?;
}

test("comment only") {
    let v = must_decode("# just a comment\n");
    assert(v.is_table() && v.table_len() == 0, "comment")?;
}

test("string int bool") {
    let v = must_decode("a = \"hi\"\nn = 42\nok = true\nno = false\n");
    assert(v.table_len() == 4, "four keys")?;
    assert(v.get("a").is_string() && v.get("a").s == "hi", "string")?;
    assert(v.get("n").is_int() && v.get("n").i == 42, "int")?;
    assert(v.get("ok").is_bool() && v.get("ok").flag, "true")?;
    assert(v.get("no").is_bool() && !v.get("no").flag, "false")?;
}

test("literal string") {
    let v = must_decode("p = 'C:\\Users\\n'\n");
    assert(v.get("p").s == "C:\\Users\\n", "literal")?;
}

test("basic escapes") {
    let v = must_decode("s = \"a\\n\\t\\\"\\\\\"\n");
    assert(v.get("s").s == "a\n\t\"\\", "escapes")?;
}

test("unicode escape") {
    let v = must_decode("s = \"\\u0041\"\n");
    assert(v.get("s").s == "A", "u0041")?;
}

test("multiline basic string") {
    let v = must_decode("s = \"\"\"\nhello\nworld\"\"\"\n");
    assert(v.get("s").s == "hello\nworld", "ml basic")?;
}

test("multiline line-ending backslash") {
    let v = must_decode("s = \"\"\"\nfoo \\\n  bar\"\"\"\n");
    assert(v.get("s").s == "foo bar", "ml trim")?;
}

test("multiline literal") {
    let v = must_decode("s = '''\nC:\\x'''\n");
    assert(v.get("s").s == "C:\\x", "ml lit")?;
}

test("integers bases and underscores") {
    let v = must_decode("a = 1_000\nb = 0xDEAD\nc = 0o10\nd = 0b1010\ne = +99\nf = -1\n");
    assert(v.get("a").i == 1000, "underscores")?;
    assert(v.get("b").i == 57005, "hex")?;
    assert(v.get("c").i == 8, "oct")?;
    assert(v.get("d").i == 10, "bin")?;
    assert(v.get("e").i == 99, "plus")?;
    assert(v.get("f").i == (0 - 1), "neg")?;
}

test("floats") {
    let v = must_decode("a = 1.5\nb = 1e2\nc = inf\nd = -inf\ne = nan\n");
    assert(v.get("a").is_float() && v.get("a").f > 1.4 && v.get("a").f < 1.6, "1.5")?;
    assert(v.get("b").is_float() && v.get("b").f > 99.9 && v.get("b").f < 100.1, "1e2")?;
    assert(v.get("c").is_float() && v.get("c").i == 1 && !v.get("c").flag, "inf")?;
    assert(v.get("d").is_float() && v.get("d").i == 1 && v.get("d").flag, "-inf")?;
    assert(v.get("e").is_float() && v.get("e").i == 2, "nan")?;
}

test("offset datetime") {
    let a = must_decode("t = 1979-05-27T07:32:00Z\n");
    assert(a.get("t").is_datetime() && a.get("t").s == "1979-05-27T07:32:00Z", "odt")?;
}

test("local datetime") {
    let b = must_decode("t = 1979-05-27T07:32:00\n");
    assert(b.get("t").s == "1979-05-27T07:32:00", "ldt")?;
}

test("local date") {
    let c = must_decode("t = 1979-05-27\n");
    assert(c.get("t").s == "1979-05-27", "date")?;
}

test("local time") {
    let d = must_decode("t = 07:32:00\n");
    assert(d.get("t").s == "07:32:00", "time")?;
}

test("datetime space separator") {
    let e = must_decode("t = 1979-05-27 07:32:00-07:00\n");
    assert(e.get("t").s == "1979-05-27 07:32:00-07:00", "space sep")?;
}

test("array mixed trailing comma") {
    let v = must_decode("a = [1, \"x\", true,]\n");
    assert(v.get("a").is_array() && v.get("a").array_len() == 3, "arr")?;
    assert(v.get("a").child(0).is_int() && v.get("a").child(0).i == 1, "0")?;
    assert(v.get("a").child(1).is_string() && v.get("a").child(1).s == "x", "1")?;
}

test("inline table") {
    let v = must_decode("p = { x = 1, y = 2 }\n");
    assert(v.get("p").is_table() && v.get("p").table_len() == 2, "inline")?;
    assert(v.get("p").get("x").i == 1 && v.get("p").get("y").i == 2, "xy")?;
}

test("dotted keys") {
    let v = must_decode("a.b.c = 1\n");
    assert(v.get("a").is_table(), "a")?;
    assert(v.get("a").get("b").get("c").i == 1, "c")?;
}

test("quoted keys") {
    let v = must_decode("\"a.b\" = 1\n'' = 2\n");
    assert(v.get("a.b").i == 1, "quoted")?;
    assert(v.has("") && v.get("").i == 2, "empty key")?;
}

test("table header") {
    let v = must_decode("name = \"root\"\n\n[owner]\nname = \"x\"\n");
    assert(v.get("name").s == "root", "root")?;
    assert(v.get("owner").is_table() && v.get("owner").get("name").s == "x", "owner")?;
}

test("nested table header") {
    let v = must_decode("[a.b]\nc = 1\n[a]\nd = 2\n");
    assert(v.get("a").get("d").i == 2, "super")?;
    assert(v.get("a").get("b").get("c").i == 1, "nested")?;
}

test("array of tables") {
    let v = must_decode("[[prod]]\nname = \"a\"\n[[prod]]\nname = \"b\"\n");
    assert(v.get("prod").is_array() && v.get("prod").array_len() == 2, "aot")?;
    assert(v.get("prod").child(0).get("name").s == "a", "0")?;
    assert(v.get("prod").child(1).get("name").s == "b", "1")?;
}

test("subtable of last array element") {
    let v = must_decode("[[fruit]]\nname = \"apple\"\n[fruit.phys]\ncolor = \"red\"\n");
    assert(v.get("fruit").child(0).get("phys").get("color").s == "red", "phys")?;
}

test("encode constructors") {
    assert(must_encode(TomlValue::from_int(7)) == "7")?;
    assert(must_encode(TomlValue::from_bool(true)) == "true")?;
    assert(must_encode(TomlValue::from_string("hi")) == "\"hi\"")?;
    assert(must_encode(TomlValue::empty_table()) == "")?;
}

test("round-trip nested") {
    let src = "a = 1\n\n[b]\nc = true\n";
    let v = must_decode(src);
    let out = must_encode(v);
    let v2 = must_decode(out);
    assert(must_encode(v2) == out, "stable encode")?;
    assert(v2.get("a").i == 1 && v2.get("b").get("c").flag, "values")?;
}

test("bytes entry points") {
    let raw = to_bytes("k = 1\n");
    let v = match codec().decode(raw) {
        Result::Ok(x) => x,
        Result::Err(_) => panic "decode bytes",
    };
    let encoded = match codec().encode(v) {
        Result::Ok(b) => b,
        Result::Err(_) => panic "encode bytes",
    };
    let text = match from_bytes(encoded) {
        Result::Ok(s) => s,
        Result::Err(_) => panic "utf8",
    };
    assert(text == "k = 1\n")?;
}

test("whitespace around keys") {
    let v = must_decode("  a  .  b  =  1  \n");
    assert(v.get("a").get("b").i == 1, "ws keys")?;
}

test("array newlines and comments") {
    let v = must_decode("a = [\n  1, # c\n  2\n]\n");
    assert(v.get("a").array_len() == 2, "arr nl")?;
}
