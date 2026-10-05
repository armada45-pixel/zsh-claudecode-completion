#!/bin/bash
#
# Self-test for the harness in lib/common.sh. `assert_no_completion_errors`
# has to fail on any error zsh prints during completion, not only on the
# `_arguments` ones. A completer that printed `_alternative:7: bad option: -J`
# on every TAB once passed the whole suite because nothing looked for it.
#
# The test registers throwaway completers for made-up commands, so it does
# not depend on what `_claude` currently contains.

set -e
TEST_NAME=test-harness-errors
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_common_deps

home=$(make_test_home)
trap 'rm -rf "$home"' EXIT

cat >> "$home/.zshrc" <<'ZSHRC'
# `_arguments` hands compadd options to a bare action; `_alternative`
# rejects them and prints `_alternative:N: bad option: -J`.
_harness_bad() { _arguments ':thing:_alternative "things:thing:(alpha beta)"' }
compdef _harness_bad harness-bad
_harness_good() { _arguments ':thing:(alpha beta)' }
compdef _harness_good harness-good
ZSHRC

log "case 1: a completer that prints a zsh error is rejected"
output=$(run_completion "$home" "$home" 'harness-bad \t')
assert_contains "bad option" "$output" "output of the broken completer"
if ( assert_no_completion_errors "$output" ) >/dev/null 2>&1; then
    printf '%s\n' "$output" >&2
    fail "assert_no_completion_errors accepted output containing a zsh error"
fi

log "case 2: a clean completer is still accepted"
output=$(run_completion "$home" "$home" 'harness-good \t')
assert_no_completion_errors "$output"
assert_contains "alpha" "$output" "output of the clean completer"

pass "harness detects zsh errors printed during completion"
