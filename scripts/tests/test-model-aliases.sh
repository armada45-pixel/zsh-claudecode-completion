#!/bin/bash
#
# Test for model alias completion (issue #225). Every option that takes a
# model offers the aliases from Claude's model documentation.
# `--fallback-model` takes a comma-separated list, so it must not offer a
# model twice and must join the next one with a comma.

set -e
TEST_NAME=test-model-aliases
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_common_deps

home=$(make_test_home)
trap 'rm -rf "$home"' EXIT

complete() { run_completion "$home" "$home" "$1"; }

# The descriptions are unique to the alias list, so matching one proves
# the list came from _claude_models and not from the typed command line.
for opt in '--model' 'agents --model' 'plugin eval --model' \
           'plugin eval --judge-model' 'auto-mode critique --model'; do
    log "case: 'claude $opt <TAB>' offers the aliases"
    output=$(complete "claude $opt \\t")
    assert_no_completion_errors "$output"
    assert_contains "Latest Opus" "$output" "aliases for '$opt'"
    assert_contains "Fast and efficient Haiku" "$output" "aliases for '$opt'"
    assert_contains "opusplan" "$output" "aliases for '$opt'"
    assert_contains "sonnet\[1m\]" "$output" "aliases for '$opt'"
done

log "case: '--fallback-model <TAB>' offers the aliases"
output=$(complete 'claude --fallback-model \t')
assert_no_completion_errors "$output"
assert_contains "Latest Opus" "$output" "first fallback model"

log "case: a model already in the list is not offered again"
output=$(complete 'claude --fallback-model opus,\t')
assert_no_completion_errors "$output"
assert_contains "Latest Sonnet" "$output" "second fallback model"
assert_not_contains "Latest Opus" "$output" "second fallback model"

# zsh prints the separator it will insert as a bold `,` right after the
# completed word: `haiku<ESC>[1m,`. A space there would end the list.
log "case: the next model is joined with a comma, not a space"
output=$(complete 'claude --fallback-model opus,hai\t')
assert_no_completion_errors "$output"
assert_contains "fallback-model opus,haiku.\[1m," "$output" "completed second fallback model"
assert_not_contains "fallback-model opus,haiku " "$output" "completed second fallback model"

log "case: '--advisor <TAB>' offers only the advisor models"
output=$(complete 'claude --advisor \t')
assert_no_completion_errors "$output"
assert_contains "fable  *opus  *sonnet" "$output" "advisor models"
assert_not_contains "haiku" "$output" "advisor models"

pass "model alias completion OK"
