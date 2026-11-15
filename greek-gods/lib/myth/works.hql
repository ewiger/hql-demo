/// The ancient works the knowledge base cites, and how to cite them.
module myth.works for Work

/// A work: its author, its title and its approximate date.
type Work {
    id     : String
    author : String
    title  : String
    year   : Int
    dating : String
}

/// A passage of the work, as a reference: `Hesiod, Theogony 453–458`.
fn cite(self, passage: String) : String = fmt("{}, {} {}", self.author, self.title, passage)
