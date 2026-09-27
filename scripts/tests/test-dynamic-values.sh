#!/bin/bash
#
# Coverage for the value completers that read Claude's own config:
# _claude_models, _claude_agents, _claude_mcp_servers,
# _claude_installed_plugins, _claude_available_plugins and
# _claude_marketplaces. Also guards the $words trimming that lets
# positional specs in nested subcommands (e.g. `claude plugin validate
# <path>`) line up, including when a flag precedes the subcommand.

set -e
TEST_NAME=test-dynamic-values
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

require_common_deps
require_dep jq

# ---------------------------------------------------------------------------
# Fixture builder
# ---------------------------------------------------------------------------
#
#   - agents:  user agent `reviewer` (frontmatter name differs from file
#              name) and project agent `local-helper` in $proj/.claude/agents
#   - MCP:     `user-srv` (user scope) and `local-srv` (local scope for $proj)
#              in ~/.claude.json, `proj-srv` in $proj/.mcp.json
#   - plugins: `alpha@mp1` installed; marketplace `mp1` offers `beta`, next
#              to a malformed entry that must not hide it
#   - files:   $proj/somefile.txt for the positional-path check
#   - CRLF:    $proj/.claude/agents/win.md saved with Windows line endings
build_fixture() {
    local home="$1" proj="$2"
    local plugins="$home/.claude/plugins"
    mkdir -p "$home/.claude/agents" "$proj/.claude/agents" \
             "$plugins/marketplaces/mp1/.claude-plugin"

    cat > "$home/.claude/agents/review-agent.md" <<'MD'
---
name: reviewer
description: "Reviews code for bugs\n\n<example>ignored</example>"
---
You review code.
MD

    cat > "$proj/.claude/agents/local-helper.md" <<'MD'
---
description: Project-only helper
---
You help.
MD

    cat > "$home/.claude.json" <<JSON
{
  "mcpServers": {"user-srv": {"command": "true"}},
  "projects": {"$proj": {"mcpServers": {"local-srv": {"command": "true"}}}}
}
JSON

    cat > "$proj/.mcp.json" <<'JSON'
{"mcpServers": {"proj-srv": {"command": "true"}}}
JSON

    cat > "$plugins/installed_plugins.json" <<'JSON'
{"version": 2, "plugins": {"alpha@mp1": [{"scope": "user", "version": "1.0.0"}]}}
JSON

    cat > "$plugins/known_marketplaces.json" <<JSON
{"mp1": {"source": {"source": "github", "repo": "acme/mp1"},
         "installLocation": "$plugins/marketplaces/mp1"}}
JSON

    cat > "$plugins/marketplaces/mp1/.claude-plugin/marketplace.json" <<'JSON'
{"name": "mp1", "plugins": [
  {"name": "odd-desc", "description": {"en": "not a string"}},
  "not-an-object",
  {"name": "beta", "description": "Beta plugin"}
]}
JSON

    touch "$proj/somefile.txt"
    printf -- '---\r\nname: crlf-agent\r\ndescription: Windows file\r\n---\r\n' \
        > "$proj/.claude/agents/win.md"
}

home=$(make_test_home)
trap 'rm -rf "$home"' EXIT
proj="$home/proj"
build_fixture "$home" "$proj"

log "case 1: top-level commands carry descriptions"
output=$(run_completion "$home" "$proj" 'claude \t')
assert_no_completion_errors "$output"
assert_contains "Manage background agents" "$output" "command descriptions"

log "case 2: --model offers aliases"
output=$(run_completion "$home" "$proj" 'claude --model \t')
assert_no_completion_errors "$output"
assert_contains "opusplan" "$output" "model aliases"
assert_contains "sonnet\[1m\]" "$output" "model aliases"

log "case 3: --agent reads user and project agents"
output=$(run_completion "$home" "$proj" 'claude --agent \t')
assert_no_completion_errors "$output"
assert_contains "reviewer" "$output" "agent names"
assert_contains "local-helper" "$output" "agent names"
assert_contains "Reviews code for bugs" "$output" "agent description"
assert_not_contains "review-agent" "$output" "agent names (frontmatter name wins)"
assert_not_contains "<example>" "$output" "agent description"
assert_contains "crlf-agent" "$output" "agent with CRLF line endings"
assert_contains "Windows file" "$output" "agent with CRLF line endings"

log "case 4: mcp get lists user, local and project servers"
output=$(run_completion "$home" "$proj" 'claude mcp get \t')
assert_no_completion_errors "$output"
assert_contains "user-srv" "$output" "MCP servers"
assert_contains "local-srv" "$output" "MCP servers"
assert_contains "proj-srv" "$output" "MCP servers"

log "case 5: plugin uninstall completes installed plugins"
output=$(run_completion "$home" "$proj" 'claude plugin uninstall \t')
assert_no_completion_errors "$output"
assert_contains "alpha@mp1" "$output" "installed plugins"

log "case 6: plugin install completes marketplace plugins"
output=$(run_completion "$home" "$proj" 'claude plugin install \t')
assert_no_completion_errors "$output"
assert_contains "beta@mp1" "$output" "available plugins (next to a malformed entry)"
assert_contains "odd-desc@mp1" "$output" "plugin with a non-string description"

log "case 7: plugin marketplace remove completes marketplaces"
output=$(run_completion "$home" "$proj" 'claude plugin marketplace remove \t')
assert_no_completion_errors "$output"
assert_contains "mp1" "$output" "marketplaces"

log "case 8: nested positional path completes (plugin validate <path>)"
output=$(run_completion "$home" "$proj" 'claude plugin validate somefi\t')
assert_no_completion_errors "$output"
assert_contains "somefile.txt" "$output" "positional path"

log "case 9: flag before the subcommand does not shift positionals"
output=$(run_completion "$home" "$proj" 'claude --verbose mcp get proj\t')
assert_no_completion_errors "$output"
assert_contains "proj-srv" "$output" "MCP server after leading flag"

log "case 10: older installed_plugins.json (one object per plugin)"
cat > "$home/.claude/plugins/installed_plugins.json" <<'JSON'
{"version": 1, "plugins": {"legacy@mp1": {"version": "0.9.0"}}}
JSON
output=$(run_completion "$home" "$proj" 'claude plugin uninstall \t')
assert_no_completion_errors "$output"
assert_contains "legacy@mp1" "$output" "installed plugins (old format)"

pass "dynamic value completion OK"
