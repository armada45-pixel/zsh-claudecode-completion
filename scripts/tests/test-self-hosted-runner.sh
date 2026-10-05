#!/bin/bash
#
# Completion test for the hidden `claude self-hosted-runner` command.
# Verifies that the command is offered at the top level, its subcommand
# list (`setup`, `doctor`, `orchestrator`), a sample of the runner's own
# flags, that `orchestrator` gets its own flag set instead of the runner's,
# that `setup` only gets `-h`/`--help`, and the enumerated values of
# `--log-level`, `--host-config-snapshot`, `--confine-repo-settings` and
# the optional bool of `--trust-workspace`.

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
# Only the subcommands: neither the runner's flags nor the top-level list.
assert_not_contains -- "--capacity" "$output" "self-hosted-runner subcommands"
assert_not_contains "setup-token" "$output" "self-hosted-runner subcommands"

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

log "case 8: 'claude self-hosted-runner setup -<TAB>' offers -h/--help, not the runner's flags"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner setup -\t')
assert_no_zsh_errors "$output"
assert_contains -- "--help" "$output" "setup flags"
assert_contains -- "-h " "$output" "setup flags"
assert_not_contains -- "--capacity" "$output" "setup flags"

log "case 9: '--confine-repo-settings <TAB>' lists warn, enforce and off"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner --confine-repo-settings \t')
assert_no_zsh_errors "$output"
for mode in warn enforce off; do
    assert_contains "$mode" "$output" "--confine-repo-settings values"
done

log "case 10: '--trust-workspace <TAB>' lists the optional true/false"
output=$(run_completion "$home" "$home" 'claude self-hosted-runner --trust-workspace \t')
assert_no_zsh_errors "$output"
assert_contains "true" "$output" "--trust-workspace values"
assert_contains "false" "$output" "--trust-workspace values"

pass "self-hosted-runner completion OK"
