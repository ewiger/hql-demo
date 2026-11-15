/// The beings of Greek myth, from Chaos to Heracles: their names in Greek
/// and Latin, what kind of being each is, and what each is over.
module myth.beings for Being

// The `greek` package's module. Its functions have no body in HQL; the
// package's Rust implements them, and this module calls them as it would
// any other.
import greek

/// A being: its id, its usual English name, its Greek name in polytonic
/// script, its Roman counterpart where it has one, its kind and domains.
type Being {
    id      : String
    name    : String
    greek   : String
    roman?  : String
    kind    : String
    domains : List<String>
    note?   : String
}

/// The Greek name in Latin letters, by the `greek` package: `Ἡρακλῆς` is
/// `Hēraklēs`.
fn latin(self) : String = self.greek.transliterate()

/// The Greek name without its accents and breathings.
fn plain(self) : String = self.greek.unaccented()

/// The name and the Greek: `Zeus (Ζεύς)`.
fn label(self) : String = fmt("{} ({})", self.name, self.greek)

/// One of the twelve of the Parthenon frieze.
fn olympian(self) : Bool = self.kind == "olympian"
