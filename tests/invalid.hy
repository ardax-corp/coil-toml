// Invalid TOML 1.0 input: positions are 1-based.
use toml::{Toml, TomlValue, TomlError};

fn codec() -> Toml {
    return Toml::v1();
}

fn is_invalid(Result<TomlValue, TomlError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            TomlError::Invalid { line, column } => line >= 1 && column >= 1,
            _ => false,
        },
    };
}

test("duplicate key") {
    assert(is_invalid(codec().decode_str("a = 1\na = 2\n")), "dup")?;
}

test("redefine table") {
    assert(is_invalid(codec().decode_str("[a]\n[a]\n")), "table twice")?;
}

test("trailing comma inline table") {
    assert(is_invalid(codec().decode_str("a = { b = 1, }\n")), "inline comma")?;
}

test("newline in inline table") {
    assert(is_invalid(codec().decode_str("a = { b = 1\n}\n")), "inline nl")?;
}

test("extend inline table") {
    assert(is_invalid(codec().decode_str("a = { b = 1 }\n[a.c]\n")), "closed inline")?;
}

test("leading zero") {
    assert(is_invalid(codec().decode_str("a = 01\n")), "01")?;
}

test("signed hex") {
    assert(is_invalid(codec().decode_str("a = +0x10\n")), "signed hex")?;
}

test("leading plus datetime is number fail or invalid") {
    match codec().decode_str("a = +1979-05-27\n") {
        Result::Ok(_) => assert(false, "plus date parsed")?,
        Result::Err(_) => assert(true)?,
    };
}

test("trailing junk on line") {
    assert(is_invalid(codec().decode_str("a = 1 b = 2\n")), "junk")?;
}

test("unterminated string") {
    assert(is_invalid(codec().decode_str("a = \"hello")), "unterm")?;
}

test("bare key missing value") {
    assert(is_invalid(codec().decode_str("a\n")), "no eq")?;
}

test("invalid date") {
    assert(is_invalid(codec().decode_str("t = 1979-02-29\n")), "not leap")?;
}

test("dotted overwrite") {
    assert(is_invalid(codec().decode_str("a = 1\na.b = 2\n")), "overwrite")?;
}

test("array then table") {
    assert(is_invalid(codec().decode_str("a = [1]\n[a]\n")), "arr vs table")?;
}

test("invalid on second line") {
    let r = codec().decode_str("a = 1\n[");
    assert(match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            TomlError::Invalid { line, column } => line == 2 && column >= 1,
            _ => false,
        },
    }, "line 2")?;
}

test("empty input is valid table") {
    match codec().decode_str("") {
        Result::Ok(v) => assert(v.is_table(), "empty table")?,
        Result::Err(_) => assert(false, "empty should work")?,
    };
}

test("lone surrogate unicode") {
    let r = codec().decode_str("s = \"\\uD800\"\n");
    assert(match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            TomlError::Utf8 { line, column } => line >= 1 && column >= 1,
            _ => false,
        },
    }, "Utf8")?;
}

test("bad underscore") {
    assert(is_invalid(codec().decode_str("a = 1_\n")) || match codec().decode_str("a = 1_\n") {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            TomlError::Number { line, column } => line >= 1 && column >= 1,
            _ => false,
        },
    }, "1_")?;
}
