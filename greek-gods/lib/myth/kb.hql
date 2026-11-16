/// The knowledge base: the records under records/, beside this module,
/// read as the type its module declares. A relative path written in a
/// module is read against the module's own directory, so a program or a
/// document anywhere reads the same files through these functions. The
/// evidence, which implements the trait of `myth`, is `myth.evidence`.
module myth.kb

import myth.beings
import myth.works
import myth.genealogy
import myth.stories

// Each file is read through a function whose declared result is a `Seq` of
// the record type: that result is what `source` decodes each line as.
private fn read_beings() : Seq<Being> = source(file("records/beings.jsonl"))
private fn read_works() : Seq<Work> = source(file("records/works.jsonl"))
private fn read_parentage() : Seq<Parentage> = source(file("records/parentage.jsonl"))
private fn read_myths() : Seq<Myth> = source(file("records/myths.jsonl"))

/// The gods, Titans, monsters, mortals and heroes.
fn beings() : List<Being> = List(read_beings())

/// The ancient works cited, with their dates.
fn works() : List<Work> = List(read_works())

/// Every account of a birth, Hesiod's first, then Homer's, then the
/// later mythographers'.
fn parentage() : List<Parentage> = List(read_parentage())

/// The myths, in the order they happen.
fn myths() : List<Myth> = List(read_myths())

/// The being `id`, if the knowledge base has it.
fn being(id: String) : Option<Being> = beings() | find(b => b.id == id)

/// The name of the being `id`, or the id itself where there is none.
fn name(id: String) : String = being(id) | map(b => b.name) | unwrap_or(id)
