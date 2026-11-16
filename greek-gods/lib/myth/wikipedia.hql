/// Wikipedia as an external namespace. The knowledge base names a being by
/// its own id, `kronos`; Wikipedia names the same being by an article title,
/// `Cronus`, and Wikidata by an item, `Q44204`. The mapping between them is
/// not a record file: it is a Markdown table in the vault's card
/// `wikipedia`, which people read and edit, and this module reads it from
/// the card's text. A module does not see the vault, so the text is passed
/// in: `wikipedia.articles(@[[wikipedia]].body.unwrap_or(""))`.
module myth.wikipedia for Article

/// A being's article in Wikipedia and its item in Wikidata. `wikidata` is
/// empty, and `note` says why, where the being has no article of its own.
type Article {
    being    : String
    title    : String
    url      : String
    wikidata : String
    note     : String
}

/// The cells of a Markdown table row, trimmed.
private fn cells(line: String) : List<String> =
    line.trim().trim_prefix("|").trim_suffix("|").split("|") | map(c => c.trim())

/// The text of a Markdown link, `[text](target)`.
private fn label(link: String) : String = link.trim_prefix("[").split("](")[0].unwrap_or("")

/// The target of a Markdown link.
private fn target(link: String) : String = link.split("](")[1].unwrap_or("").trim_suffix(")")

/// Every row of the tables in `body` with four cells whose second is a
/// link: the being's id, the article, the Wikidata item and a note.
fn articles(body: String) : List<Article> =
    body.lines()
    | map(cells)
    | filter(cs => cs.size() == 4 and cs[1].unwrap_or("").starts_with("["))
    | map(cs => Article(
        being    = cs[0].unwrap_or(""),
        title    = label(cs[1].unwrap_or("")),
        url      = target(cs[1].unwrap_or("")),
        wikidata = label(cs[2].unwrap_or("")),
        note     = cs[3].unwrap_or(""),
      ))

/// The article of `being`, if the namespace maps it.
fn article(articles: List<Article>, being: String) : Option<Article> = articles | find(a => a.being == being)

/// The article as a Markdown link: `[Cronus](https://en.wikipedia.org/wiki/Cronus)`.
fn link(self) : String = fmt("[{}]({})", self.title, self.url)

/// The Wikidata item as a Markdown link, or nothing where there is none.
fn item(self) : String =
    "" given self.wikidata == "" otherwise fmt("[{}](https://www.wikidata.org/wiki/{})", self.wikidata, self.wikidata)
