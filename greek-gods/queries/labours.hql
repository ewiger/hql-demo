// The twelve labours of Heracles in Apollodorus's order, numbered as a
// Greek would number them: `12.numeral()` is `ιβʹ`, by the `greek`
// package. Apollodorus says Eurystheus first set ten, and refused to count
// the hydra, where Iolaus helped, and the stables, where Augeas promised
// pay.
import greek
import myth.kb
import myth.stories

type Labour { number : String, title : String, place : String, sources : List<String> }

works = kb.works()

kb.myths()
| filter(m => m.id.starts_with("labour-"))
| sort(by = m => m.seq)
| enumerate
| map(p => Labour(
    number  = (p.first + 1).numeral(),
    title   = p.second.title,
    place   = p.second.place.unwrap_or(""),
    sources = p.second.sources(works),
  ))
