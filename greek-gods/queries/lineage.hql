// From Heracles back to the first powers: every ancestor the first
// account of each birth names, at the nearest generation it is reached.
// Through Zeus the line reaches Kronos, Uranus and Gaia in three steps;
// through Alcmene it reaches Perseus, and through Danaë, Zeus again.
//
// The Greek names are written in Latin letters by the `greek` package,
// whose functions are declared in HQL and implemented in Rust.
import myth.kb
import myth.beings
import myth.genealogy as family

type Forebear { generation : Int, name : String, greek : String, latin : String, kind : String }

family.lineage(kb.parentage(), "heracles")
| map(a => kb.being(a.being) | map(b => Forebear(
    generation = a.generation,
    name       = b.name,
    greek      = b.greek,
    latin      = b.latin(),
    kind       = b.kind,
  )))
| somes
