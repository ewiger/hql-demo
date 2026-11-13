# Sourced by every use case: the hql binary to run, $HQL when it is set,
# else one built in the sibling hql repository, else hql on the PATH; and
# the steps a case is made of, each reporting `ok` or, when it fails, the
# case, the step, the command, hql's own error output and a diff.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${HQL:-}" ]; then
  if [ -x "$here/../hql/target/debug/hql" ]; then
    HQL="$here/../hql/target/debug/hql"
  else
    HQL=hql
  fi
fi
export HQL

# The case is the directory the sourcing run.sh lives in.
case_name="$(basename "$(pwd)")"

# Report a failed step: the case, the step, the command that ran, what it
# printed on standard error, and, when there is one, a diff of the actual
# output (<) against the expected file (>).
fail() {
  local step="$1" command="$2" stderr="$3" diff="${4:-}"
  {
    echo "FAIL $case_name: $step"
    echo "  command:  $command"
    if [ -n "$stderr" ]; then
      echo "  stderr:"
      sed 's/^/    /' <<<"$stderr"
    fi
    if [ -n "$diff" ]; then
      echo "  diff (< actual, > expected):"
      sed 's/^/    /' <<<"$diff"
    fi
  } >&2
}

# check STEP EXPECTED COMMAND...: run the command and compare what it prints
# with the expected file.
check() {
  local step="$1" expected="$2" actual errfile stderr
  shift 2
  errfile="$(mktemp)"
  if ! actual="$("$@" 2>"$errfile")"; then
    stderr="$(cat "$errfile")"; rm -f "$errfile"
    fail "$step" "$*" "$stderr"
    return 1
  fi
  stderr="$(cat "$errfile")"; rm -f "$errfile"
  if [ "$actual" = "$(cat "$expected")" ]; then
    echo "ok   $step"
  else
    fail "$step" "$* (expected: $expected)" "$stderr" \
      "$(diff <(echo "$actual") "$expected")"
    return 1
  fi
}

# expect PROGRAM EXPECTED [STEP]: run a program to compact JSON and compare.
# STEP names the step when one program runs more than once.
expect() {
  check "${3:-$1}" "$2" "$HQL" run --to json --compact "$1"
}

# save STEP FILE COMMAND...: run the command, writing what it prints to FILE.
save() {
  local step="$1" file="$2" stderr
  shift 2
  if stderr="$("$@" 2>&1 >"$file")"; then
    echo "ok   $step"
  else
    fail "$step" "$* > $file" "$stderr"
    return 1
  fi
}

# run PROGRAM...: run each program for its side effects.
run() {
  local program
  for program in "$@"; do
    save "$program" /dev/null "$HQL" run --to none "$program" || return 1
  done
}

# up SERVICE...: start the case's containers and wait until they are healthy.
up() {
  local out
  if ! out="$(docker compose up -d --wait "$@" 2>&1)"; then
    fail "services $*" "docker compose up -d --wait $*" "$(tail -n 20 <<<"$out")"
    return 1
  fi
}

# once SERVICE: run a one-shot setup container (topics, streams, buckets).
once() {
  local out
  if ! out="$(docker compose run --rm "$1" 2>&1)"; then
    fail "setup $1" "docker compose run --rm $1" "$(tail -n 20 <<<"$out")"
    return 1
  fi
}
