/// Linear B: the names of gods on the clay tablets of the Mycenaean
/// palaces, the earliest Greek there is.
module myth.tablets for Tablet : Evidence

import myth
import greek

/// A god's name on a tablet: the tablet's designation, the palace, the
/// form as transliterated, its date, and whether the reading is secure.
type Tablet {
    id     : String
    site   : String
    being  : String
    form   : String
    year   : Int
    secure : Bool
    note   : String
}

/// The form in the syllabary, by the `greek` package: `di-we` is `𐀇𐀸`.
fn glyphs(self) : String = self.form.linear_b()

fn subject(self) : String = self.being
fn dated(self) : Int = self.year
fn kind(self) : String = "tablet"

fn reference(self) : String =
    fmt("{} ({}), {} {}{}", self.id, self.site, self.form, self.glyphs(), "" given self.secure otherwise ", reading disputed")
