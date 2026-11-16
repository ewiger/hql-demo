// When each god is first attested, by three kinds of evidence: a name on a
// Linear B tablet of the Mycenaean palaces, a site of cult, and a text.
//
// Each kind is a module that implements the trait `Evidence` of `myth`,
// declaring the four functions the trait writes without a body; `Witness`
// is the union of the three types. `evidence.witnesses()` is one list of
// all of them, and `line`, the trait's default, writes each one.
import myth.kb
import myth.beings
import myth.evidence

type Attested { god : String, earliest : String, tablet : String, text : String, site : String }

witnesses = evidence.witnesses()
first = (being: String, kind: String) => evidence.earliest(witnesses, being, kind).unwrap_or("none")

kb.beings()
| filter(b => b.olympian() or b.id == "hestia" or b.id == "hades" or b.id == "heracles")
| map(b => Attested(
    god      = b.name,
    earliest = first(b.id, ""),
    tablet   = first(b.id, "tablet"),
    text     = first(b.id, "text"),
    site     = first(b.id, "site"),
  ))
