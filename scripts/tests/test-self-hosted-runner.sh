#!/bin/bash
#
# Completion test for the hidden `claude self-hosted-runner` command.
# Verifies that the command is offered at the top level, its subcommand
# list (`setup`, `doctor`, `orchestrator`), a sample of the runner's own
# flags, that `orchestrator` gets its own flag set instead of the runner's,
# and the enumerated values of `--log-level` and `--host-config-snapshot`.

set -e
TEST_NAME=test-self-hosted-runner
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_common_deps

home=$(make_test_home)
trap 'rm -rf "$home"' EXIT

# Any error zsh prints from inside a completion function looks like
# `_name:NN: message`; none may appear.
assert_no_zsh_errors() {
    assert_no_completion_errors "$1"
    if grep -qE '(^|[^[:alnum:]_])_[[:alnum:]_]+:[0-9]+: ' <<< "$1"; then
        printf '%s\n' "$1" >&2
        fail "zsh error printed during completion"
    fi
}

log "case 1: 'claude se<TAB>' lists self-hosted-runner next to setup-token"
output=$(run_completion "$home" "$home" 'claude se\t')
assert_no_zsh_errors "$output"
assert_contains "self-hosted-runner" "$output" "top-level commands"
assert_contains "setup-token" "$output" "top-level commands"

log "case 2: 'claude self-hosted-runner <TAB>' lists the subcommands"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner \t')
assert_no_zsh_errors "$output"
for cmd in setup doctor orchestrator; do
    assert_contains "$cmd" "$output" "self-hosted-runner subcommand '$cmd'"
done

log "case 3: 'claude self-hosted-runner --<TAB>' offers runner flags only"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner --\t')
assert_no_zsh_errors "$output"
for flag in --api-url --capacity --base-dir --git-ssh-rewrite --trust-workspace \
            --confine-repo-settings --host-config-snapshot --retire-at \
            --kill-session-after-min --debug-token-dir; do
    assert_contains -- "$flag" "$output" "runner flag '$flag'"
done
for flag in --hook-concurrency --min-idle --scm-connector-host; do
    assert_not_contains -- "$flag" "$output" "runner flags (orchestrator-only '$flag')"
done

log "case 4: 'claude self-hosted-runner orchestrator --<TAB>' offers orchestrator flags only"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner orchestrator --\t')
assert_no_zsh_errors "$output"
for flag in --api-url --hooks-dir --hook-concurrency --hook-timeout \
            --expected-spawn-seconds --min-idle --scm-connector-host --debug-dir; do
    assert_contains -- "$flag" "$output" "orchestrator flag '$flag'"
done
for flag in --capacity --base-dir --trust-workspace --retire-at; do
    assert_not_contains -- "$flag" "$output" "orchestrator flags (runner-only '$flag')"
done

log "case 5: '--host-config-snapshot <TAB>' lists disk and memory"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner --host-config-snapshot \t')
assert_no_zsh_errors "$output"
assert_contains "disk" "$output" "--host-config-snapshot values"
assert_contains "memory" "$output" "--host-config-snapshot values"

log "case 6: 'orchestrator --log-level <TAB>' lists info and debug"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner orchestrator --log-level \t')
assert_no_zsh_errors "$output"
assert_contains "info" "$output" "--log-level values"
assert_contains "debug" "$output" "--log-level values"

log "case 7: a flag in front keeps the runner's flags; subcommands are first-word only"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner --capacity 2 --\t')
assert_no_zsh_errors "$output"
assert_contains -- "--base-dir" "$output" "runner flags after another flag"
assert_not_contains -- "--hook-concurrency" "$output" "runner flags after another flag"

pass "self-hosted-runner completion OK"
