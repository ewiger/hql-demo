#!/usr/bin/env bash
# The Greek Gods use case, with no service: a knowledge base of Greek myth
# from Chaos to Heracles, kept as HQL modules with their records under
# lib/myth/, the Greek script handled by the `greek` package, whose module
# declares functions without bodies and whose Rust crate, packages/greek/,
# implements them. hql builds the crate on the first run, against itself.
#
# The programs under queries/ are checked as JSON Lines. The documents are
# the cards of a vault; their HQL cells query the same modules, and each
# keeps its output below it, as `hql render --emit after --in-place` wrote
# it. A document is checked by rendering it again: the result must be the
# document as committed, outputs and all.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

for program in theogony pantheon lineage variants labours evidence; do
  check "queries/$program.hql" "expected/$program.jsonl" \
    "$HQL" run --to jsonlines "queries/$program.hql"
done

for document in index theogony olympians heracles evidence wikipedia; do
  check "$document.hmd" "$document.hmd" \
    "$HQL" render --emit after "$document.hmd"
done

# The crate's own tests, of its Rust functions alone, built against the hql
# source beside this repository, as hql builds the package itself.
hql_source="$(cd ../.. && pwd)/hql"
if [ -f "$hql_source/Cargo.toml" ]; then
  save "packages/greek/: cargo test" /dev/null \
    cargo test --quiet --manifest-path packages/greek/Cargo.toml \
    --config "patch.crates-io.hql.path=\"$hql_source\""
fi
