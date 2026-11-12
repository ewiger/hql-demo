# Sourced by every use case: the hql binary to run, $HQL when it is set,
# else one built in the sibling hql repository, else hql on the PATH.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${HQL:-}" ]; then
  if [ -x "$here/../hql/target/debug/hql" ]; then
    HQL="$here/../hql/target/debug/hql"
  else
    HQL=hql
  fi
fi
export HQL

# Run a program and compare what it prints with the expected file.
expect() {
  local program="$1" expected="$2" actual
  actual="$("$HQL" run --to json --compact "$program")" || { echo "FAIL $program: hql failed" >&2; return 1; }
  if [ "$actual" = "$(cat "$expected")" ]; then
    echo "ok   $program"
  else
    echo "FAIL $program" >&2
    diff <(echo "$actual") "$expected" >&2 || true
    return 1
  fi
}
