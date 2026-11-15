# Greek Gods: an HQL demo over a small ontology

This folder is a demonstration of the [HQL](https://github.com/ewiger/hql)
language, not a mythology project. It needs a subject that has real
structure, so it uses a small one: Greek myth from Chaos to Heracles, kept
as a deliberately minimal ontology. Over it, the case shows the ways HQL is
meant to be used and extended, together in one project:

- **typed records and pipelines**: JSON Lines read as declared types, then
  filtered, grouped, joined and ordered;
- **library modules written in HQL**: a module root, receiver modules,
  traits with functions declared without a body, private helpers, a module
  reading data kept beside it;
- **a user-loadable Rust module**: the package `greek`, a local crate whose
  HQL module declares functions without bodies and whose Rust implements
  them, built and loaded by hql from one line of configuration;
- **HyperMarkdown documents**: a vault of `.hmd` cards whose HQL cells query
  the library and call the Rust module, each keeping its output below it.

## The ontology

Six kinds of record, each a type declared by a module of `lib/myth/`:

```text
Work ◀── cited by ── Parentage ── child, parents ──▶ Being
  ▲                                                  ▲  ▲
  └──── cited by ── Myth ──────── figures ───────────┘  │
                                                        │
          Tablet, Site ───────── attests ───────────────┘
```

| Type | Module | One record is | Records |
| --- | --- | --- | --- |
| `Being` | `myth.beings` | a god, Titan, monster, mortal or hero, with its Greek name | 103 |
| `Parentage` | `myth.genealogy` | one source's account of one birth: the parents, the work, the passage | 98 |
| `Myth` | `myth.stories` | an episode: who takes part, where, and the passages that tell it | 49 |
| `Work` | `myth.works` | an ancient text and its date | 17 |
| `Tablet` | `myth.tablets` | a god's name on a Linear B tablet | 14 |
| `Site` | `myth.sites` | a sanctuary or temple of a god | 17 |

Two choices keep it small and still correct:

- **A claim is a record with its source.** Parentage is not a field of
  `Being`. Hesiod and Homer give Aphrodite different parents, so each
  account is a separate `Parentage` naming its work and lines, and
  `genealogy.disputed` finds where the accounts disagree. An account that
  names one parent and leaves the other unsaid is marked `partial`, so that
  it is not read as a birth without union.
- **Evidence is one trait over three types.** A tablet, a site and a
  passage of a text all attest a being at a date. The trait `Evidence` in
  `myth` declares `subject`, `dated`, `kind` and `reference` without a body.
  Each of `myth.tablets`, `myth.sites` and `myth.mentions` implements it for
  its own type, and `Witness`, the trait's named type, holds all three in
  one list.

The records are in `lib/myth/records/` and were checked against the
ancient texts and the Linear B corpus. They are a sample, not a complete
mythology.

### External namespaces

The ontology names each being by an id of its own, `kronos`. Two external
namespaces name the same beings differently: Wikipedia by article title,
`Cronus`, and Wikidata by item, `Q44204`. The mapping is not a record file.
It is a Markdown table in the vault's card [wikipedia.hmd](wikipedia.hmd),
one row per being with both as links, which people read and edit there.
`myth.wikipedia` parses the table out of the card's text. A module does not
see the vault, so a cell passes the text in through a reference to the
card:

```hql
import myth.wikipedia

articles = wikipedia.articles(@[[wikipedia]].body.unwrap_or(""))
```

The card checks itself every time it is rendered: each being has a row
and each row names a being. The titles were resolved through Wikipedia's
API, following redirects, and each description was read to keep out pages
that list several figures of one name. Two beings, Menoetius and Alcaeus,
have only such a page, and their rows say so.

## Layout

```text
greek-gods/
├── .hql/config.toml        the project: the module root and the package
├── .hmd/config.toml        the vault: the documents in this folder are its cards
├── lib/myth/               the ontology, as HQL modules
│   ├── mod.hql             the trait Evidence and its named type Witness
│   ├── beings.hql …        a receiver module per record type
│   ├── kb.hql              reads records/, beside it
│   ├── evidence.hql        tablets, sites and texts as one list of Witness
│   ├── wikipedia.hql       reads the external namespace from its card
│   └── records/*.jsonl     the data
├── greek/                  the Rust module: the crate of the package `greek`
│   ├── Cargo.toml
│   ├── modules/greek/mod.hql   the contract: declarations without bodies
│   └── src/lib.rs              their implementations
├── *.hmd                   the documents, with their HQL cells and outputs
├── wikipedia.hmd           among them, the mapping to Wikipedia and Wikidata
├── queries/*.hql           programs over the same modules
├── expected/*.jsonl        what the programs print
└── run.sh                  the case, end to end
```

## A Rust module loaded by the user: `greek`

HQL code can call native code through a **package**: a Cargo crate holding
HQL modules whose functions are declared without a body, and the Rust that
implements them. Book chapters 32 to 36 in the hql repository describe the
mechanism. `greek` is a working minimal example.

**The contract** is `greek/modules/greek/mod.hql`. A program reads it like
any other module, and the checker types calls from it alone:

```hql
module greek

import core

fn transliterate(self: String) : String
fn unaccented(self: String) : String
fn numeral(self: Int) : String
fn linear_b(self: String) : String
```

**The implementation** is `greek/src/lib.rs`. Each function is plain Rust
over `&str` or `i64`, unit-tested on its own, with a thin adapter that
takes and gives `hql::ext::Value`. One table registers the adapters under
the declared names, and `hql::extension!` exports it:

```rust
static GREEK: &[Operation] = &[
    hql::native!("transliterate", transliterate_op),
    hql::native!("unaccented", unaccented_op),
    hql::native!("numeral", numeral_op),
    hql::native!("linear_b", linear_b_op),
];

hql::extension!(ext::extension("greek", env!("CARGO_PKG_VERSION"), &[ext::provided("greek", GREEK)]));
```

**The crate** is named `hql-ext-greek`, builds a `cdylib`, and names its
package in `[package.metadata.hql]`:

```toml
[package.metadata.hql]
package = "greek"
provides = ["greek"]
modules = "modules"
```

**Loading it** takes one line in `.hql/config.toml`:

```toml
[packages]
paths = ["greek"]
```

The first run in the project builds the crate with cargo, about a minute,
and loads the library. Later runs reuse the build until a file under
`src/` or `modules/`, or `Cargo.toml`, changes. A Rust library must match
the hql that loads it exactly: the same `hql` crate version, the same
compiler and the same dependency versions. So hql builds the crate against
its own source, overriding the crate's `hql = "0.7"` dependency, and the
crate compiles against an unreleased hql `main` as well as a release. If a
declaration has no implementation, hql refuses the package and names the
declaration.

**Calling it** is the same as calling any module:

```hql
import greek

["Ἡρακλῆς".transliterate(), "Ζεύς".unaccented(), 12.numeral(), "di-wo-nu-so".linear_b()]
```

```text
["Hēraklēs", "Ζευς", "ιβʹ", "𐀇𐀺𐀝𐀰"]
```

The library uses it too. `myth.beings` writes
`fn latin(self) : String = self.greek.transliterate()`, and `myth.tablets`
writes `fn glyphs(self) : String = self.form.linear_b()`. A program or
document that calls `b.latin()` reaches Rust through an HQL module without
importing `greek` itself.

## The documents

Each `.hmd` file is a card of the vault this folder declares. A fenced
block marked `hql` is a cell: `id=name` shares its value with the
document's other cells, and `hidden` runs it without output. Rendering a
document writes each cell's output below the cell, between
`<!-- hql:output -->` markers:

```sh
hql render --emit after --in-place heracles.hmd
```

Start with [index.hmd](index.hmd). Its last cell queries the vault itself,
listing each card and the links between them. The others are
[theogony.hmd](theogony.hmd), [olympians.hmd](olympians.hmd),
[heracles.hmd](heracles.hmd), [evidence.hmd](evidence.hmd) and
[wikipedia.hmd](wikipedia.hmd).

## Running

From the repository root, with hql built in the sibling `hql` checkout and
a Rust toolchain on the `PATH`:

```sh
./greek-gods/run.sh
```

The script runs the six programs and compares their output with
`expected/`. It renders each document again and requires the result to
equal the committed file, outputs included. Last, it runs the crate's unit
tests. Single commands, from this folder:

```sh
hql run queries/lineage.hql              # Heracles' ancestors, as JSON Lines
hql render evidence.hmd                  # a document, built to Markdown
hql eval 'import greek
"Ἀθηνᾶ".transliterate()'                 # the Rust module, directly
```

## Changing it

- **Data.** Edit `lib/myth/records/*.jsonl`. Every account of a birth and
  every myth cites a work by its id and a passage. Re-render the documents
  one per command, `for d in *.hmd; do hql render --emit after --in-place
  "$d"; done`, and write `expected/` again from the programs.
- **A function in Rust.** Declare it in `greek/modules/greek/mod.hql`,
  implement it in `src/lib.rs` and add it to the `GREEK` table. The next
  run rebuilds the crate.
- **A kind of evidence.** Write a receiver module `for YourType : Evidence`
  that declares the trait's four functions, and add it to
  `myth.evidence.witnesses`.

## Limits found on the way

Writing this case found six places where hql does not yet behave as its
book describes. Two of them shape the layout. A document may read only
files under its own directory, so the documents sit above `lib/`. A module
declaring a trait's named type is refused the second time it is imported
in one render, so `evidence.hmd` imports the evidence modules in one hidden
cell. [doc/memory/greek-gods.hmd](../doc/memory/greek-gods.hmd) lists all
six, with how to reproduce each.
