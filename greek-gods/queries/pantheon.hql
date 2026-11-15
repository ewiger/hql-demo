// The Olympians: the twelve of the Parthenon's east frieze, with Hestia
// and Hades, who are Kronos's children but not among them. Each name in
// Greek, in Latin letters and without its marks, the last two by the
// `greek` package; the Roman counterpart; and the parents in Hesiod.
//
// `from myth.beings import Being.*` binds the receivers over `Being` and
// nothing else of the module, so `latin` is a receiver and a function.
from myth.beings import Being.*
from myth.genealogy import parents_of
import myth.kb

type God {
    name    : String
    greek   : String
    latin   : String
    plain   : String
    roman   : String
    domains : List<String>
    parents : List<String>
}

rows = kb.parentage()

kb.beings()
| filter(b => b.olympian() or b.id == "hestia" or b.id == "hades")
| map(b => God(
    name    = b.name,
    greek   = b.greek,
    latin   = latin(b),
    plain   = b.plain(),
    roman   = b.roman.unwrap_or(""),
    domains = b.domains,
    parents = parents_of(rows, b.id) | map(kb.name),
  ))
