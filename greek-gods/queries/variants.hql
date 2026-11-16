// Where the sources disagree on a birth: each account, in the order the
// records list them, Hesiod's first. Aphrodite is born of Uranus's foam in
// Hesiod and a daughter of Zeus and Dione in Homer; Hephaestus is Hera's
// alone in Hesiod and Zeus's son too in Homer; Hesiod himself gives the
// Moirai to Night and, later in the poem, to Zeus and Themis.
from myth.genealogy import accounts, disputed
import myth.kb
import myth.works

type Account { source : String, parents : List<String>, note : String }
type Dispute { being : String, accounts : List<Account> }

works = kb.works()
rows = kb.parentage()

disputed(rows)
| map(child => Dispute(
    being    = kb.name(child),
    accounts = accounts(rows, child) | map(a => Account(
        source  = works | find(w => w.id == a.work) | map(w => w.cite(a.passage)) | unwrap_or(a.work),
        parents = a.parents | map(kb.name),
        note    = a.note.unwrap_or(""),
      )),
  ))
