/// The evidence that the gods were known: Linear B tablets, sites of cult
/// and the passages of texts, each a module implementing the trait
/// `Evidence` of `myth`, and all of them together as `Witness`es.
///
/// Kept apart from `myth.kb`: a document whose cells each import a module
/// declaring a trait's named type is refused at the second import, so the
/// modules most cells need do not import `myth`.
module myth.evidence

import myth
import myth.kb
import myth.works
import myth.tablets
import myth.sites
import myth.mentions

// The declared result of each reader is the type `source` decodes to.
private fn read_tablets() : Seq<Tablet> = source(file("records/tablets.jsonl"))
private fn read_sites() : Seq<Site> = source(file("records/sites.jsonl"))

/// The names of gods on Linear B tablets.
fn tablets() : List<Tablet> = List(read_tablets())

/// Sanctuaries and temples.
fn sites() : List<Site> = List(read_sites())

private fn mention(works: List<Work>, being: String, work: String, passage: String) : List<Mention> =
    works | filter(w => w.id == work) | map(w => Mention(being = being, work = w, passage = passage))

/// Every passage that names a being, in an account of a birth or in a myth.
fn mentions() : List<Mention> {
    cited = kb.works()
    births = kb.parentage()
        | flat_map(b => concat([b.child], b.parents) | flat_map(being => mention(cited, being, b.work, b.passage)))
    told = kb.myths()
        | flat_map(m => m.figures | flat_map(being => m.cites | flat_map(c => mention(cited, being, c.work, c.passage))))
    concat(births, told)
}

// A binding inside a block takes no type, so each kind is widened to the
// trait's union by a function's declared result.
private fn found() : List<Witness> = tablets()
private fn places() : List<Witness> = sites()
private fn texts() : List<Witness> = mentions()

/// All the evidence, of every kind, as one list.
fn witnesses() : List<Witness> = concat(concat(found(), places()), texts())

/// The earliest witness of `being`, of `kind` or, for `""`, of any kind,
/// as its `line`.
fn earliest(witnesses: List<Witness>, being: String, kind: String) : Option<String> =
    witnesses
    | filter(w => w.subject() == being and (kind == "" or w.kind() == kind))
    | sort(by = w => w.dated())
    | first
    | map(w => w.line())
