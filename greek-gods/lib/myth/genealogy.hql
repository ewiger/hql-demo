/// Who was born of whom, account by account. The sources disagree, so a
/// parentage is a claim with its source; the functions here take the
/// accounts a program read and follow them.
module myth.genealogy for Parentage

/// One account of a being's birth: the parents a work names, in a passage.
/// One parent is a birth without union, as Hera's of Hephaestus, unless the
/// account is `partial`: it names one parent and leaves the other unsaid.
type Parentage {
    child    : String
    parents  : List<String>
    work     : String
    passage  : String
    note?    : String
    partial? : Bool
}

/// A being a lineage passes through, and how many generations back.
type Ancestor { being : String, generation : Int }

/// Whether this account names `parent`.
fn names(self, parent: String) : Bool = self.parents.contains(parent)

/// Every account of the birth of `child`, in the order they were read.
fn accounts(rows: List<Parentage>, child: String) : List<Parentage> =
    rows | filter(r => r.child == child)

/// The parents the first account names. The records list Hesiod first,
/// then Homer, then the later mythographers.
fn parents_of(rows: List<Parentage>, child: String) : List<String> =
    accounts(rows, child) | first | map(r => r.parents) | unwrap_or([])

/// The children any account gives `parent`, each once.
fn children_of(rows: List<Parentage>, parent: String) : List<String> =
    rows | filter(r => r.names(parent)) | map(r => r.child) | distinct

/// Every ancestor of `child` by the first accounts, with the generation it
/// is reached at; a being reached by two paths appears once per path.
private fn climb(rows: List<Parentage>, child: String, generation: Int) : List<Ancestor> =
    parents_of(rows, child)
    | flat_map(p => concat([Ancestor(being = p, generation = generation)], climb(rows, p, generation + 1)))

/// Every ancestor of `child`, each once, at the nearest generation it is
/// reached at, nearest first.
fn lineage(rows: List<Parentage>, child: String) : List<Ancestor> =
    climb(rows, child, 1)
    | group(by = a => a.being)
    | map(g => Ancestor(being = g.key, generation = g.items | map(a => a.generation) | min | unwrap_or(0)))
    | sort(by = a => a.generation)

/// Whether every parent `a` names, `b` names too.
private fn within(a: Parentage, b: Parentage) : Bool = a.parents.all(p => b.parents.contains(p))

/// Whether two accounts agree: they name the same parents, or one is
/// partial and names some of the other's. Homer's Sthenelus, a son of
/// Perseus, agrees with Apollodorus's, a son of Perseus and Andromeda;
/// Hesiod's Hephaestus, born of Hera alone, does not agree with Homer's.
private fn agree(a: Parentage, b: Parentage) : Bool =
    (within(a, b) and (within(b, a) or a.partial.unwrap_or(false)))
    or (within(b, a) and b.partial.unwrap_or(false))

/// The beings with two accounts that do not agree on the parents.
fn disputed(rows: List<Parentage>) : List<String> =
    rows
    | group(by = r => r.child)
    | filter(g => g.items | any(a => g.items | any(b => not agree(a, b))))
    | map(g => g.key)
    | sort
