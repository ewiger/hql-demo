// Hesiod's Theogony as data: every birth the poem tells, in the order it
// tells them, each set of parents once with the children the passage gives
// them. A being born of one parent alone has one; Erebus and Night, born
// of Chaos, have Chaos alone.
import myth.kb
import myth.genealogy

type Births { lines : String, parents : List<String>, children : List<String> }

names = to_map(kb.beings(), b => b.id, b => b.name)
name = (id: String) => names.get(id).unwrap_or(id)

// The first line a passage cites, to put the births in the poem's order.
fn opening(passage: String) : Int =
    passage.split(",")[0].unwrap_or("").split("–")[0].unwrap_or("") | to_int | unwrap_or(0)

kb.parentage()
| filter(a => a.work == "theogony")
| group(by = a => fmt("{} {}", a.passage, a.parents | join(" ")))
| map(g => Births(
    lines    = g.items[0].map(a => a.passage).unwrap_or(""),
    parents  = g.items[0].map(a => a.parents).unwrap_or([]) | map(name),
    children = g.items | map(a => name(a.child)),
  ))
| sort(by = b => opening(b.lines))
