// The contract of module `greek`. Every function is declared without a
// body: the `greek` package's extension, src/lib.rs, implements each one,
// and hql refuses the package if a declaration here has no implementation.

/// Greek script: polytonic text in Latin letters and without its marks,
/// alphabetic numerals, and the Linear B syllabary.
module greek

// A contract names its types through its own imports: `String` and `Int`
// are declared by `core`.
import core

/// Polytonic Greek in Latin letters, the scholarly way: η and ω as `ē` and
/// `ō`, a rough breathing as `h`, υ as `y` outside a diphthong, γ before a
/// velar as `n`. `"Ἀθηνᾶ".transliterate()` is `Athēna`, `"Ἡρακλῆς"` gives
/// `Hēraklēs`.
fn transliterate(self: String) : String

/// The text with its accents, breathings and iota subscripts removed:
/// `"Ζεύς".unaccented()` is `Ζευς`.
fn unaccented(self: String) : String

/// A number from 1 to 9999 as a Greek alphabetic numeral, with the keraia:
/// `12.numeral()` is `ιβʹ`, `2026.numeral()` is `͵βκϛʹ`.
fn numeral(self: Int) : String

/// A Linear B word, transliterated with hyphens between syllables, in the
/// syllabary itself; words are separated by the Aegean word divider.
/// `"di-we".linear_b()` is `𐀇𐀸`.
fn linear_b(self: String) : String
