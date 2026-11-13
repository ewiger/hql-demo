# hql-demo

Use cases for [HQL](https://github.com/ewiger/hql) against real systems. The
README says what each case does and how to run it.

## No release process

hql-demo has no releases, no versions and no tags. It is a set of examples
that run against hql's latest `main`, not documentation versioned with hql.
Decided 2026-11-13.

- Do not tag hql-demo, cut a release, keep a changelog, or name an hql
  version a case needs. A case that needs a newer hql is updated when hql
  `main` changes, not pinned to a version.
- Keep changes small and only as needed: fix a case when hql `main` breaks
  it, add one when a feature deserves a real-system example. Do not
  restructure the cases to follow an hql release.
- Work goes on a short-lived branch and merges to `main`. A branch named
  after an hql release (such as `release-0.6.0`) is a work branch only, not
  a release of hql-demo.
- hql runs `./run-all.sh` before its own releases as a check against real
  services, and hql-demo's CI builds hql `main` and runs a subset. Both test
  hql; neither makes hql-demo part of hql's release.

## Running

`./run-all.sh` runs every case, `./<case>/run.sh` one. Each case starts and
removes its own containers. Set `HQL` to use a binary other than
`../hql/target/debug/hql`.
