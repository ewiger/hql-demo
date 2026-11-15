//! The extension of the `greek` package: one Rust function per name its
//! contract, `modules/greek/mod.hql`, declares without a body.
//!
//! Each function is plain Rust over `&str` or `i64`, tested on its own with
//! `cargo test`; the operations at the end of the file adapt them to the
//! values a program passes and receives.

#![deny(unsafe_code)]

use hql::ext::{self, Diagnostic, EvalCx, Operation, Span, TypedArg, Value};
use unicode_normalization::UnicodeNormalization;

const ROUGH: char = '\u{0314}';
const DIAERESIS: char = '\u{0308}';
const IOTA_SUBSCRIPT: char = '\u{0345}';

/// One letter of decomposed Greek: its base character and the marks on it.
struct Letter {
    base: char,
    marks: Vec<char>,
}

impl Letter {
    fn lower(&self) -> char {
        self.base.to_lowercase().next().unwrap_or(self.base)
    }

    fn upper(&self) -> bool {
        self.base.is_uppercase()
    }

    fn has(&self, mark: char) -> bool {
        self.marks.contains(&mark)
    }
}

/// The text in canonical decomposition, as letters with their marks. A mark
/// with no letter before it is dropped.
fn letters(text: &str) -> Vec<Letter> {
    let mut out: Vec<Letter> = Vec::new();
    for c in text.nfd() {
        if is_mark(c) {
            if let Some(last) = out.last_mut() {
                last.marks.push(c);
            }
        } else {
            out.push(Letter { base: c, marks: Vec::new() });
        }
    }
    out
}

fn is_mark(c: char) -> bool {
    ('\u{0300}'..='\u{036F}').contains(&c)
}

fn is_vowel(c: char) -> bool {
    matches!(c, 'α' | 'ε' | 'η' | 'ι' | 'ο' | 'υ' | 'ω')
}

/// A lower-case Greek letter; final ς lies inside the range.
fn is_greek(c: char) -> bool {
    ('α'..='ω').contains(&c)
}

/// The Latin of one lower-case letter, outside the rules that look at its
/// neighbours.
fn latin(c: char) -> &'static str {
    match c {
        'α' => "a",
        'β' => "b",
        'γ' => "g",
        'δ' => "d",
        'ε' => "e",
        'ζ' => "z",
        'η' => "ē",
        'θ' => "th",
        'ι' => "i",
        'κ' => "k",
        'λ' => "l",
        'μ' => "m",
        'ν' => "n",
        'ξ' => "x",
        'ο' => "o",
        'π' => "p",
        'ρ' => "r",
        'σ' | 'ς' => "s",
        'τ' => "t",
        'υ' => "y",
        'φ' => "ph",
        'χ' => "ch",
        'ψ' => "ps",
        'ω' => "ō",
        _ => "",
    }
}

/// Capitalise the first character of a piece of Latin.
fn capital(piece: &str) -> String {
    let mut chars = piece.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().chain(chars).collect(),
        None => String::new(),
    }
}

/// Polytonic Greek in Latin letters. Characters that are not Greek letters
/// are kept as they are.
pub fn transliterate(text: &str) -> String {
    let letters = letters(text);
    let mut out = String::new();
    for (i, letter) in letters.iter().enumerate() {
        let c = letter.lower();
        if !is_greek(c) {
            out.push(letter.base);
            continue;
        }
        let previous = i.checked_sub(1).map(|p| &letters[p]);
        let next = letters.get(i + 1);
        let word_start = previous.is_none_or(|p| !is_greek(p.lower()));

        let mut piece = String::new();
        // A rough breathing is written on the first vowel of a word, or on
        // the second of an opening diphthong; either way it is an `h` before
        // the word. On ρ it follows the letter, `rh`.
        let opens_rough = word_start
            && is_vowel(c)
            && (letter.has(ROUGH)
                || next.is_some_and(|n| {
                    matches!(n.lower(), 'ι' | 'υ') && !n.has(DIAERESIS) && n.has(ROUGH)
                }));
        if opens_rough {
            piece.push('h');
        }
        match c {
            // υ after a vowel, without a diaeresis, closes a diphthong: `u`.
            'υ' if previous.is_some_and(|p| {
                matches!(p.lower(), 'α' | 'ε' | 'η' | 'ο') && !letter.has(DIAERESIS)
            }) =>
            {
                piece.push('u');
            }
            // γ before a velar is nasal: ἄγγελος is angelos.
            'γ' if next.is_some_and(|n| matches!(n.lower(), 'γ' | 'κ' | 'ξ' | 'χ')) => {
                piece.push('n');
            }
            'ρ' if letter.has(ROUGH)
                || (word_start && letter.upper())
                || previous.is_some_and(|p| p.lower() == 'ρ') =>
            {
                piece.push_str("rh");
            }
            _ => piece.push_str(latin(c)),
        }
        if letter.has(IOTA_SUBSCRIPT) {
            piece.push('i');
        }
        if letter.upper() {
            piece = capital(&piece);
        }
        out.push_str(&piece);
    }
    out
}

/// The text without accents, breathings, diaereses or iota subscripts.
pub fn unaccented(text: &str) -> String {
    text.nfd().filter(|c| !is_mark(*c)).nfc().collect()
}

const UNITS: [char; 9] = ['α', 'β', 'γ', 'δ', 'ε', 'ϛ', 'ζ', 'η', 'θ'];
const TENS: [char; 9] = ['ι', 'κ', 'λ', 'μ', 'ν', 'ξ', 'ο', 'π', 'ϟ'];
const HUNDREDS: [char; 9] = ['ρ', 'σ', 'τ', 'υ', 'φ', 'χ', 'ψ', 'ω', 'ϡ'];
const KERAIA: char = 'ʹ';
const THOUSANDS: char = '͵';

/// A number from 1 to 9999 in the Greek alphabetic system: units, tens and
/// hundreds each a letter, thousands a unit letter after `͵`, and the
/// keraia at the end. `None` outside that range, which has no numeral.
pub fn numeral(n: i64) -> Option<String> {
    if !(1..=9999).contains(&n) {
        return None;
    }
    let digit = |place: i64| usize::try_from((n / place) % 10).ok();
    let mut out = String::new();
    for (place, letters) in [(1000, &UNITS), (100, &HUNDREDS), (10, &TENS), (1, &UNITS)] {
        let d = digit(place)?;
        if d > 0 {
            if place == 1000 {
                out.push(THOUSANDS);
            }
            out.push(letters[d - 1]);
        }
    }
    out.push(KERAIA);
    Some(out)
}

/// The Linear B syllabograms by their transliteration, U+10000 onward.
const SYLLABARY: [(&str, u32); 74] = [
    ("a", 0x10000), ("e", 0x10001), ("i", 0x10002), ("o", 0x10003), ("u", 0x10004),
    ("da", 0x10005), ("de", 0x10006), ("di", 0x10007), ("do", 0x10008), ("du", 0x10009),
    ("ja", 0x1000A), ("je", 0x1000B), ("jo", 0x1000D), ("ju", 0x1000E),
    ("ka", 0x1000F), ("ke", 0x10010), ("ki", 0x10011), ("ko", 0x10012), ("ku", 0x10013),
    ("ma", 0x10014), ("me", 0x10015), ("mi", 0x10016), ("mo", 0x10017), ("mu", 0x10018),
    ("na", 0x10019), ("ne", 0x1001A), ("ni", 0x1001B), ("no", 0x1001C), ("nu", 0x1001D),
    ("pa", 0x1001E), ("pe", 0x1001F), ("pi", 0x10020), ("po", 0x10021), ("pu", 0x10022),
    ("qa", 0x10023), ("qe", 0x10024), ("qi", 0x10025), ("qo", 0x10026),
    ("ra", 0x10028), ("re", 0x10029), ("ri", 0x1002A), ("ro", 0x1002B), ("ru", 0x1002C),
    ("sa", 0x1002D), ("se", 0x1002E), ("si", 0x1002F), ("so", 0x10030), ("su", 0x10031),
    ("ta", 0x10032), ("te", 0x10033), ("ti", 0x10034), ("to", 0x10035), ("tu", 0x10036),
    ("wa", 0x10037), ("we", 0x10038), ("wi", 0x10039), ("wo", 0x1003A),
    ("za", 0x1003C), ("ze", 0x1003D), ("zo", 0x1003F),
    ("a2", 0x10040), ("a3", 0x10041), ("au", 0x10042), ("dwe", 0x10043), ("dwo", 0x10044),
    ("nwa", 0x10045), ("pu2", 0x10046), ("pte", 0x10047), ("ra2", 0x10048), ("ra3", 0x10049),
    ("ro2", 0x1004A), ("ta2", 0x1004B), ("twe", 0x1004C), ("two", 0x1004D),
];

/// The Aegean word separator line, written between words.
const WORD_DIVIDER: char = '\u{10100}';

/// Transliterated Linear B in the syllabary. The error names the first
/// syllable that is not a syllabogram's value.
pub fn linear_b(text: &str) -> Result<String, String> {
    let mut words = Vec::new();
    for word in text.split_whitespace() {
        let mut out = String::new();
        for syllable in word.split('-') {
            let wanted = syllable.to_lowercase();
            let glyph = SYLLABARY
                .iter()
                .find(|(value, _)| *value == wanted)
                .and_then(|(_, code)| char::from_u32(*code))
                .ok_or_else(|| format!("`{syllable}` is not a Linear B syllable"))?;
            out.push(glyph);
        }
        words.push(out);
    }
    Ok(words.join(&WORD_DIVIDER.to_string()))
}

fn text(input: &Value, span: &Span) -> Result<String, Diagnostic> {
    match input {
        Value::Str(text) => Ok(text.to_string()),
        _ => Err(ext::failure(span.clone(), "expected a `String`")),
    }
}

/// `fn transliterate(self: String) : String`
fn transliterate_op(
    _cx: &mut dyn EvalCx,
    input: Value,
    _arguments: &[TypedArg],
    span: Span,
) -> Result<Value, Diagnostic> {
    Ok(Value::Str(transliterate(&text(&input, &span)?).into()))
}

/// `fn unaccented(self: String) : String`
fn unaccented_op(
    _cx: &mut dyn EvalCx,
    input: Value,
    _arguments: &[TypedArg],
    span: Span,
) -> Result<Value, Diagnostic> {
    Ok(Value::Str(unaccented(&text(&input, &span)?).into()))
}

/// `fn numeral(self: Int) : String`
fn numeral_op(
    _cx: &mut dyn EvalCx,
    input: Value,
    _arguments: &[TypedArg],
    span: Span,
) -> Result<Value, Diagnostic> {
    let Value::Int(n) = input else {
        return Err(ext::failure(span, "expected an `Int`"));
    };
    numeral(n)
        .map(|written| Value::Str(written.into()))
        .ok_or_else(|| ext::failure(span, format!("{n} has no Greek numeral: write 1 to 9999")))
}

/// `fn linear_b(self: String) : String`
fn linear_b_op(
    _cx: &mut dyn EvalCx,
    input: Value,
    _arguments: &[TypedArg],
    span: Span,
) -> Result<Value, Diagnostic> {
    linear_b(&text(&input, &span)?)
        .map(|written| Value::Str(written.into()))
        .map_err(|message| ext::failure(span, message))
}

/// The operations of module `greek`, one per declared name.
static GREEK: &[Operation] = &[
    hql::native!("transliterate", transliterate_op),
    hql::native!("unaccented", unaccented_op),
    hql::native!("numeral", numeral_op),
    hql::native!("linear_b", linear_b_op),
];

hql::extension!(ext::extension(
    "greek",
    env!("CARGO_PKG_VERSION"),
    &[ext::provided("greek", GREEK)],
));

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn transliterates_the_names_of_the_gods() {
        for (greek, latin) in [
            ("Ζεύς", "Zeus"),
            ("Ἀθηνᾶ", "Athēna"),
            ("Ἀπόλλων", "Apollōn"),
            ("Ἡρακλῆς", "Hēraklēs"),
            ("Ἥφαιστος", "Hēphaistos"),
            ("Ἑρμῆς", "Hermēs"),
            ("Ῥέα", "Rhea"),
            ("Οὐρανός", "Ouranos"),
            ("Διόνυσος", "Dionysos"),
            ("Εἰλείθυια", "Eileithyia"),
            ("Ἑκατόγχειρες", "Hekatoncheires"),
            ("ᾍδης", "Haidēs"),
            ("Ὕλλος", "Hyllos"),
            ("Ἠώς", "Ēōs"),
            ("Νεμεαῖος λέων", "Nemeaios leōn"),
            ("Πύρρα", "Pyrrha"),
            ("Αἵμων", "Haimōn"),
        ] {
            assert_eq!(transliterate(greek), latin, "{greek}");
        }
    }

    #[test]
    fn removes_the_marks() {
        assert_eq!(unaccented("Ζεύς"), "Ζευς");
        assert_eq!(unaccented("ᾍδης"), "Αδης");
        assert_eq!(unaccented("Ἑκατόγχειρες"), "Εκατογχειρες");
    }

    #[test]
    fn writes_alphabetic_numerals() {
        assert_eq!(numeral(1).as_deref(), Some("αʹ"));
        assert_eq!(numeral(12).as_deref(), Some("ιβʹ"));
        assert_eq!(numeral(666).as_deref(), Some("χξϛʹ"));
        assert_eq!(numeral(99).as_deref(), Some("ϟθʹ"));
        assert_eq!(numeral(2026).as_deref(), Some("͵βκϛʹ"));
        assert_eq!(numeral(0), None);
        assert_eq!(numeral(10_000), None);
    }

    #[test]
    fn writes_linear_b() {
        assert_eq!(linear_b("di-we").as_deref(), Ok("𐀇𐀸"));
        assert_eq!(linear_b("e-ma-a2").as_deref(), Ok("𐀁𐀔𐁀"));
        assert_eq!(linear_b("di-ka-ta-jo di-we").as_deref(), Ok("𐀇𐀏𐀲𐀍𐄀𐀇𐀸"));
        assert_eq!(
            linear_b("di-xo"),
            Err("`xo` is not a Linear B syllable".to_owned())
        );
    }
}
