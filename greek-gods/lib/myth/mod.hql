/// Greek myth: what the modules under `myth` share. A year is an `Int`,
/// negative before the common era, and every kind of evidence that a god
/// was known keeps one contract.
module myth

/// A year as a historian writes it: `era(-700)` is `700 BCE`.
fn era(year: Int) : String = fmt("{} BCE", 0 - year) given year < 0 otherwise fmt("{} CE", year)

/// Evidence that a being was known: a tablet, a site or a text. Each kind
/// is a receiver module over a type of its own that lists this trait,
/// `module myth.tablets for Tablet : Evidence`, and so must declare the
/// four functions written here without a body. `Witness` is the union of
/// those types.
trait Evidence as Witness {
    /// The being it attests, by id.
    fn subject(self) : String

    /// When, as a year; negative before the common era.
    fn dated(self) : Int

    /// The kind of evidence: `tablet`, `site` or `text`.
    fn kind(self) : String

    /// Where to find it.
    fn reference(self) : String

    /// One line: the date, the kind and the reference. Every kind inherits
    /// it. The body names no function of this module: a default body runs
    /// in the scope of the module that implements the trait.
    fn line(self) : String = fmt(
        "c. {} {}, {}: {}",
        (0 - self.dated()) given self.dated() < 0 otherwise self.dated(),
        "BCE" given self.dated() < 0 otherwise "CE",
        self.kind(),
        self.reference(),
    )
}
