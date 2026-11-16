/// Sanctuaries and temples: where a god was worshipped, and since when.
module myth.sites for Site : Evidence

import myth

/// A place of cult, the god it belonged to, and its date.
type Site {
    id     : String
    name   : String
    place  : String
    being  : String
    year   : Int
    dating : String
    note   : String
}

fn subject(self) : String = self.being
fn dated(self) : Int = self.year
fn kind(self) : String = "site"
fn reference(self) : String = fmt("{}, {} ({})", self.name, self.place, self.dating)
