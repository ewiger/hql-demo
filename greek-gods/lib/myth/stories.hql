/// The myths, in the order they happen: from the first beings to Heracles
/// among the gods. Each names who takes part and the passages that tell it.
module myth.stories for Myth

import myth.works

/// A passage of a work, by the work's id.
type Cite { work : String, passage : String }

/// A myth: its place in the sequence, who takes part, where, what happens,
/// and where it is told.
type Myth {
    id      : String
    seq     : Int
    title   : String
    figures : List<String>
    place?  : String
    summary : String
    cites   : List<Cite>
}

/// Whether `being` takes part.
fn features(self, being: String) : Bool = self.figures.contains(being)

/// The passages that tell it, as references, through the works read:
/// `Hesiod, Theogony 453–491`.
fn sources(self, works: List<Work>) : List<String> =
    self.cites
    | map(c => works | find(w => w.id == c.work) | map(w => w.cite(c.passage)) | unwrap_or(c.work))
