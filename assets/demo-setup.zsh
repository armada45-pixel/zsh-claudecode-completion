# Sourced by demo-top.tape and demo-bottom.tape before recording. Builds a throwaway $HOME with
# made-up sessions, agents, MCP servers and plugins, so the recording shows
# every value completer without touching real Claude data.

demo_root=${0:A:h:h}
export HOME=$(mktemp -d)
proj=$HOME/projects/my-app
plugins=$HOME/.claude/plugins
mkdir -p $proj/.git $proj/.claude/agents $HOME/.claude/agents \
  $plugins/marketplaces/acme-tools/.claude-plugin \
  $plugins/cache/acme-tools/code-review/1.4.0/{.claude-plugin,agents}

# Sessions: claude --resume
sessions=$HOME/.claude/projects/${proj//[^a-zA-Z0-9]/-}
mkdir -p $sessions
session() {  # uuid, age, branch, kilobytes, title
  print -r -- '{"type":"user","gitBranch":"'$3'","message":{"content":"'$5'"}}' > $sessions/$1.jsonl
  head -c $(( $4 * 1024 )) /dev/zero | tr '\0' ' ' >> $sessions/$1.jsonl
  touch -d "$2" $sessions/$1.jsonl
}
session 3f9a1c2e-5b7d-4e1a-9c3f-0a1b2c3d4e5f '12 minutes ago' main              412 'Fix flaky login test'
session a81d07b4-2c6e-4f3b-8d9a-1b2c3d4e5f60 '3 hours ago'    feat/dark-mode    1830 'Add a dark mode toggle'
session 6c2e9f10-7a4b-4d8c-b1e2-2c3d4e5f6071 '1 day ago'      main               96 'Explain the payment retry logic'
session d4b7e3a9-1f5c-4a2d-a6b8-3d4e5f607182 '5 days ago'     chore/deps         248 'Upgrade to React 19'

# Agents: claude --agent
print -r -- $'---\nname: db-migrator\ndescription: Writes and checks database migrations\n---' > $proj/.claude/agents/db-migrator.md
print -r -- $'---\nname: release-notes\ndescription: Drafts release notes from merged pull requests\n---' > $HOME/.claude/agents/release-notes.md
print -r -- $'---\nname: reviewer\ndescription: Reviews a diff for bugs and style\n---' > $plugins/cache/acme-tools/code-review/1.4.0/agents/reviewer.md
print -r -- '{ "name": "code-review" }' > $plugins/cache/acme-tools/code-review/1.4.0/.claude-plugin/plugin.json

# MCP servers: claude mcp get / remove
cat > $HOME/.claude.json <<JSON
{
  "mcpServers": {
    "github": { "type": "http", "url": "https://api.githubcopilot.com/mcp/" },
    "postgres": { "type": "stdio", "command": "npx" }
  },
  "projects": { "$proj": { "mcpServers": { "sentry": { "type": "http", "url": "https://mcp.sentry.dev/mcp" } } } }
}
JSON
print -r -- '{ "mcpServers": { "playwright": { "type": "stdio", "command": "npx" } } }' > $proj/.mcp.json

# Plugins: claude plugin install / enable
cat > $plugins/installed_plugins.json <<JSON
{ "version": 2, "plugins": {
  "code-review@acme-tools": [
    { "scope": "user", "version": "1.4.0", "installPath": "$plugins/cache/acme-tools/code-review/1.4.0" } ],
  "docs-writer@acme-tools": [ { "scope": "user", "version": "0.8.2" } ] } }
JSON
print -r -- '{ "acme-tools": { "source": { "source": "github", "repo": "acme/claude-plugins" } } }' > $plugins/known_marketplaces.json
cat > $plugins/marketplaces/acme-tools/.claude-plugin/marketplace.json <<JSON
{ "name": "acme-tools", "plugins": [
  { "name": "code-review", "description": "Review pull requests with a team of agents" },
  { "name": "commit-helper", "description": "Write conventional commit messages" },
  { "name": "docs-writer", "description": "Keep the README and API docs in sync" },
  { "name": "test-runner", "description": "Run and fix failing tests" } ] }
JSON

fpath=($demo_root $fpath)
autoload -Uz compinit && compinit -u -d /dev/null
autoload -Uz _claude && compdef _claude claude
setopt AUTO_LIST NO_BEEP
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
PROMPT='%F{cyan}my-app%f %F{green}❯%f '

# Keystroke badge: pressing Tab shows it just after the cursor, and the
# next key typed or deleted removes it again.
demo-tab() {
  zle expand-or-complete
  POSTDISPLAY='  Tab '
  region_highlight=("$(( $#BUFFER + 2 )) $(( $#BUFFER + 7 )) bg=yellow,fg=black")
}
demo-key() {
  if [[ -n $POSTDISPLAY ]]; then
    POSTDISPLAY=
    region_highlight=()
    zle reset-prompt
  fi
  zle .$WIDGET
}
zle -N demo-tab
zle -N self-insert demo-key
zle -N backward-delete-char demo-key
bindkey '^I' demo-tab
cd $proj
unset demo_root proj plugins sessions
unfunction session
clear
