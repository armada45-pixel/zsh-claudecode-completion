#!/bin/bash
#
# Test for the built-in and plugin agents `_claude_agents` offers next to
# the user's own (see test-agent-names.sh for those).
#
# Builds a fake $HOME with installed plugins and a git project, then checks:
#   - a plugin agent is `<plugin>:<name>`, and a subfolder of `agents/`
#     becomes part of that name
#   - the name comes from the frontmatter, or from the file name without it
#   - the manifest can rename the plugin and replace the `agents/` scan
#   - plugins turned off in `enabledPlugins`, or off by default, are skipped,
#     and the project's settings override the user's
#   - a project-scoped install is offered only inside its project
#   - malformed entries, a missing installPath, a broken manifest and a
#     broken settings file do not hide the other plugins or print errors
#   - CLAUDE_CONFIG_DIR replaces ~/.claude, and CLAUDE_CODE_PLUGIN_CACHE_DIR
#     replaces its plugins directory
#   - the built-in agents are offered, and a user agent replaces one

set -e
TEST_NAME=test-agent-names-plugins
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_common_deps
require_dep jq

home=$(make_test_home)
trap 'rm -rf "$home"' EXIT

# Any zsh error raised while completing reads `_function:LINE: message`.
assert_clean() {
    assert_no_completion_errors "$1"
    if grep -Eq '(^|[^[:alnum:]_])_[a-z_]+:[0-9]+: ' <<< "$1"; then
        printf '%s\n' "$1" >&2
        fail "zsh error during completion"
    fi
}

# agent_file PATH [NAME [DESCRIPTION]] -- without NAME there is no frontmatter.
agent_file() {
    mkdir -p "$(dirname "$1")"
    if [[ -n "${2:-}" ]]; then
        printf -- '---\nname: %s\ndescription: %s\n---\nbody\n' "$2" "${3:-}" > "$1"
    else
        printf 'Just a prompt.\n' > "$1"
    fi
}

plug="$home/plug"
proj="$home/proj"
mkdir -p "$home/.claude/plugins" "$proj/.git" "$proj/.claude" "$home/elsewhere"

# --- plugins ---------------------------------------------------------------
agent_file "$plug/alpha/agents/top.md" top-agent "Top level plugin agent"
agent_file "$plug/alpha/agents/review/security.md" audit "Agent in a subfolder"
agent_file "$plug/alpha/agents/bare-file.md"

# The manifest renames the plugin and lists its agents; agents/ is ignored.
agent_file "$plug/renamed/custom/deep/lister.md" listed-agent "Named by the manifest"
agent_file "$plug/renamed/agents/ignored.md" ignored-agent "Default folder is replaced"
mkdir -p "$plug/renamed/.claude-plugin"
printf '{"name": "zeta-tools", "agents": ["./custom/deep/lister.md", "./../escape.md", "custom/bare.md", 7]}\n' \
    > "$plug/renamed/.claude-plugin/plugin.json"
# Both files exist, so only the path rules keep them out: a path stays
# inside the plugin and starts with `./`.
agent_file "$plug/escape.md" escape-agent "Outside the plugin root"
agent_file "$plug/renamed/custom/bare.md" prefixless-agent "Path without ./"

agent_file "$plug/off/agents/hidden.md" hidden-agent "Plugin is disabled"

agent_file "$plug/dflt/agents/sleeper.md" sleeper-agent "Off by default"
mkdir -p "$plug/dflt/.claude-plugin"
printf '{"name": "dflt", "defaultEnabled": false}\n' > "$plug/dflt/.claude-plugin/plugin.json"

agent_file "$plug/badmanifest/agents/survivor.md" survivor-agent "Manifest is not JSON"
mkdir -p "$plug/badmanifest/.claude-plugin"
printf '{ not json' > "$plug/badmanifest/.claude-plugin/plugin.json"

# The project's settings turn one plugin back on and another one off.
agent_file "$plug/relit/agents/back.md" back-agent "Enabled again by the project"
agent_file "$plug/muted/agents/quiet.md" quiet-agent "Disabled by the project"

agent_file "$plug/projonly/agents/local.md" local-agent "Project scoped install"

cat > "$home/.claude/plugins/installed_plugins.json" <<JSON
{
  "version": 2,
  "plugins": {
    "alpha@market": [{"scope": "user", "installPath": "$plug/alpha"}],
    "renamed@market": [{"scope": "user", "installPath": "$plug/renamed"}],
    "off@market": [{"scope": "user", "installPath": "$plug/off"}],
    "dflt@market": [{"scope": "user", "installPath": "$plug/dflt"}],
    "badmanifest@market": [{"scope": "user", "installPath": "$plug/badmanifest"}],
    "relit@market": [{"scope": "user", "installPath": "$plug/relit"}],
    "muted@market": [{"scope": "user", "installPath": "$plug/muted"}],
    "projonly@market": [{"scope": "project", "projectPath": "$proj", "installPath": "$plug/projonly"}],
    "gone@market": [{"scope": "user", "installPath": "$plug/does-not-exist"}],
    "nopath@market": [{"scope": "user"}],
    "wrongtype@market": "not a list",
    "numbers@market": [42, null]
  }
}
JSON
printf '{"enabledPlugins": {"off@market": false, "alpha@market": true, "relit@market": false}}\n' \
    > "$home/.claude/settings.json"
printf '{"enabledPlugins": {"relit@market": true, "muted@market": false}}\n' \
    > "$proj/.claude/settings.json"
# A settings file that is not JSON must not take the plugins with it.
printf 'not json at all' > "$proj/.claude/settings.local.json"

# --- user agents -----------------------------------------------------------
# Same unscoped name as a plugin agent, and same name as a built-in.
agent_file "$home/.claude/agents/top.md" top-agent "User agent of that name"
agent_file "$home/.claude/agents/explore.md" Explore "User replacement for Explore"

log "case 1: plugin agents, from inside the project"
output=$(run_completion "$home" "$proj" 'claude --agent \t')
assert_clean "$output"
for name in alpha:top-agent alpha:review:audit alpha:bare-file \
            zeta-tools:listed-agent badmanifest:survivor-agent \
            projonly:local-agent relit:back-agent; do
    assert_contains "$name" "$output" "agent list"
done
assert_contains "Agent in a subfolder" "$output" "plugin agent description"
assert_contains "Agent from alpha plugin" "$output" "fallback description"
# The `:` is escaped for _describe only; the backslash must not be shown.
assert_not_contains 'alpha\\' "$output" "agent list"

log "case 2: what must not be offered"
for bad in hidden-agent sleeper-agent ignored-agent renamed: escape prefixless quiet-agent \
           gone: nopath: wrongtype: numbers:; do
    assert_not_contains "$bad" "$output" "agent list"
done

log "case 3: the user's agent keeps its unscoped name"
assert_contains "User agent of that name" "$output" "agent list"
assert_contains "Top level plugin agent" "$output" "agent list"

log "case 4: built-in agents, and a user agent replacing one"
for name in general-purpose statusline-setup claude-code-guide Plan \
            "Catch-all with every tool"; do
    assert_contains "$name" "$output" "built-in agents"
done
assert_contains "User replacement for Explore" "$output" "built-in agents"
assert_not_contains "Fast, read-only agent" "$output" "built-in agents"

log "case 5: a scoped name completes with its colons"
output=$(run_completion "$home" "$proj" 'claude --agent alpha:rev\t')
assert_clean "$output"
assert_contains "alpha:review:audit" "$output" "completed name"
assert_not_contains 'alpha\\' "$output" "completed name"

log "case 6: 'claude agents --agent <TAB>' uses the same list"
output=$(run_completion "$home" "$proj" 'claude agents --agent \t')
assert_clean "$output"
assert_contains "alpha:review:audit" "$output" "agents --agent list"
assert_contains "general-purpose" "$output" "agents --agent list"

log "case 7: a project-scoped plugin stays in its project"
output=$(run_completion "$home" "$home/elsewhere" 'claude --agent \t')
assert_clean "$output"
assert_contains "alpha:top-agent" "$output" "agent list outside the project"
assert_not_contains "projonly" "$output" "agent list outside the project"
# The project's settings do not apply here, only the user's.
assert_contains "muted:quiet-agent" "$output" "agent list outside the project"
assert_not_contains "back-agent" "$output" "agent list outside the project"

log "case 8: CLAUDE_CONFIG_DIR replaces ~/.claude"
agent_file "$plug/other/agents/alt.md" alt-agent "From the alternate config dir"
mkdir -p "$home/altconfig/plugins"
printf '{"plugins": {"other@market": [{"scope": "user", "installPath": "%s"}]}}\n' \
    "$plug/other" > "$home/altconfig/plugins/installed_plugins.json"
output=$(run_completion "$home" "$home/elsewhere" 'claude --agent \t' \
    "set env(CLAUDE_CONFIG_DIR) \"$home/altconfig\"")
assert_clean "$output"
assert_contains "other:alt-agent" "$output" "agent list with CLAUDE_CONFIG_DIR"
assert_not_contains "alpha" "$output" "agent list with CLAUDE_CONFIG_DIR"
# No user agent replaces Explore here.
assert_contains "Fast, read-only agent" "$output" "built-in agents"

log "case 9: an unreadable installed_plugins.json leaves the rest alone"
mkdir -p "$home/brokenconfig/plugins" "$home/brokenconfig/agents"
printf '{"plugins": [' > "$home/brokenconfig/plugins/installed_plugins.json"
agent_file "$home/brokenconfig/agents/mine.md" still-here "User agent"
output=$(run_completion "$home" "$home/elsewhere" 'claude --agent \t' \
    "set env(CLAUDE_CONFIG_DIR) \"$home/brokenconfig\"")
assert_clean "$output"
assert_contains "still-here" "$output" "agent list with a broken plugin file"
assert_contains "general-purpose" "$output" "agent list with a broken plugin file"

log "case 10: CLAUDE_CODE_PLUGIN_CACHE_DIR replaces the plugins directory"
output=$(run_completion "$home" "$home/elsewhere" 'claude --agent \t' \
    "set env(CLAUDE_CODE_PLUGIN_CACHE_DIR) \"$home/altconfig/plugins\"")
assert_clean "$output"
assert_contains "other:alt-agent" "$output" "agent list with CLAUDE_CODE_PLUGIN_CACHE_DIR"
assert_not_contains "alpha" "$output" "agent list with CLAUDE_CODE_PLUGIN_CACHE_DIR"

pass "plugin and built-in agent completion OK"
