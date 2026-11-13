#!/usr/bin/env bash
# The crypto use case, end to end, with no service: list a release folder
# into a manifest of SHA-256 digests, sign the manifest with an Ed25519 key,
# verify the folder and an altered copy of it against the signed manifest,
# then verify a forged manifest, and keep one webhook delivery per body by
# its fingerprint.
set -euo pipefail
cd "$(dirname "$0")"
source ../bin/hql-bin.sh

# A private key file is read only with mode 0600, which git does not keep.
chmod 600 keys/rfc8032-test-1.pem
rm -rf work && mkdir work
trap 'rm -rf work' EXIT

# Compare a command's compact JSON output with an expected file.
check() {
  local name="$1" expected="$2" actual
  shift 2
  actual="$("$@")" || { echo "FAIL $name: hql failed" >&2; return 1; }
  if [ "$actual" = "$(cat "$expected")" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name" >&2
    diff <(echo "$actual") "$expected" >&2 || true
    return 1
  fi
}

"$HQL" run --to jsonlines manifest.hql > work/manifest.jsonl
check manifest.hql expected/manifest.jsonl cat work/manifest.jsonl

"$HQL" run --to json --compact sign.hql > work/manifest.sig.json
check sign.hql expected/manifest.sig.json cat work/manifest.sig.json

check "verify.hql, the release" expected/verify-release.json \
  "$HQL" run --to json --compact verify.hql

# A copy of the release as shipped: one file altered, one removed.
cp -R release work/shipped
printf 'region,amount\nnorth,999\nsouth,80\n' > work/shipped/totals.csv
rm work/shipped/settings.toml
check "verify.hql, an altered copy" expected/verify-altered.json \
  "$HQL" run --to json --compact --arg dir=work/shipped verify.hql

# A manifest changed after it was signed: its signature no longer verifies.
sed 's/"size":33/"size":34/' work/manifest.jsonl > work/forged.jsonl
mv work/forged.jsonl work/manifest.jsonl
check "verify.hql, a forged manifest" expected/verify-forged.json \
  "$HQL" run --to json --compact verify.hql

check fingerprints.hql expected/fingerprints.json \
  "$HQL" run --to json --compact fingerprints.hql
