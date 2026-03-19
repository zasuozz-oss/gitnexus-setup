#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# GitNexus for Antigravity — auto setup MCP server
#
# Install:  curl -fsSL <raw-url> | bash
#           — or —  ./setup.sh
# ══════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}  ✓${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "\n${CYAN}── $* ──${NC}"; }

# ── Config ───────────────────────────────────────────────────
ANTIGRAVITY_MCP="$HOME/.gemini/antigravity/mcp_config.json"
GITNEXUS_DIR="$HOME/AI-Tool/GitNexus"
GITNEXUS_WEB_DIR="$GITNEXUS_DIR/gitnexus-web"

# ── Prereqs ──────────────────────────────────────────────────
check_prereqs() {
  step "Checking prerequisites"

  if ! command -v node &>/dev/null; then
    err "Node.js not found. Install Node >= 18 first."; exit 1
  fi
  local node_major
  node_major=$(node -v | sed 's/v//' | cut -d. -f1)
  if (( node_major < 18 )); then
    err "Node >= 18 required (found $(node -v))"; exit 1
  fi
  ok "Node $(node -v)"

  if ! command -v npx &>/dev/null; then
    err "npx not found (should come with Node.js)"; exit 1
  fi
  ok "npx available"
}

# ── Configure Antigravity MCP ────────────────────────────────
configure_mcp() {
  step "Configuring Antigravity MCP"

  if ! command -v python3 &>/dev/null; then
    warn "python3 not found — add manually to $ANTIGRAVITY_MCP:"
    cat << 'EOF'
  "gitnexus": {
    "command": "npx",
    "args": ["-y", "gitnexus@latest", "mcp"]
  }
EOF
    return
  fi

  mkdir -p "$(dirname "$ANTIGRAVITY_MCP")"
  [ -f "$ANTIGRAVITY_MCP" ] || echo '{"mcpServers":{}}' > "$ANTIGRAVITY_MCP"

  local action
  action=$(python3 -c "
import json, sys

path = '$ANTIGRAVITY_MCP'

with open(path) as f:
    cfg = json.load(f)

servers = cfg.setdefault('mcpServers', {})
expected = {
    'command': 'npx',
    'args': ['-y', 'gitnexus@latest', 'mcp']
}
existing = servers.get('gitnexus')

if existing == expected:
    print('unchanged')
    sys.exit(0)

action = 'updated' if existing else 'added'
servers['gitnexus'] = expected

with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')

print(action)
")

  case "$action" in
    added)     ok "MCP entry added" ;;
    updated)   ok "MCP entry updated" ;;
    unchanged) ok "MCP already configured" ;;
  esac

  info "MCP command: npx -y gitnexus@latest mcp"
}

# ── Warm cache (optional, non-blocking) ──────────────────────
warm_cache() {
  step "Pre-downloading gitnexus"
  info "Running npx to cache gitnexus (this may take a moment)..."
  if npx -y gitnexus@latest --version 2>/dev/null; then
    ok "gitnexus v$(npx -y gitnexus@latest --version 2>/dev/null) cached"
  else
    warn "Pre-download failed — Antigravity will download on first use"
  fi
}

# ── Install gitnexus-sync to PATH ────────────────────────────
install_sync_script() {
  step "Installing gitnexus-sync"

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local src="$script_dir/sync-skills.sh"
  local dest_dir="$HOME/.local/bin"
  local dest="$dest_dir/gitnexus-sync"

  if [ ! -f "$src" ]; then
    warn "sync-skills.sh not found — skipping sync script install"
    return
  fi

  mkdir -p "$dest_dir"
  cp "$src" "$dest"
  chmod +x "$dest"
  ok "Installed gitnexus-sync → $dest"

  # Check if ~/.local/bin is in PATH
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$dest_dir"; then
    warn "$dest_dir is not in PATH"
    info "Add to your shell profile:  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
}

# ── Fork/clone GitNexus for Web UI ────────────────────────────
fork_web_ui() {
  step "Setting up GitNexus Web UI"

  if [ -d "$GITNEXUS_WEB_DIR" ]; then
    ok "GitNexus already cloned at $GITNEXUS_DIR"
    # Pull latest
    if git -C "$GITNEXUS_DIR" pull --ff-only 2>/dev/null; then
      ok "Pulled latest changes"
    fi
    return
  fi

  mkdir -p "$(dirname "$GITNEXUS_DIR")"

  if command -v gh &>/dev/null; then
    info "Forking abhigyanpatwari/GitNexus via GitHub CLI..."
    if (cd "$(dirname "$GITNEXUS_DIR")" && gh repo fork abhigyanpatwari/GitNexus --clone=true 2>&1); then
      ok "Forked and cloned → $GITNEXUS_DIR"
    else
      warn "Fork failed — falling back to clone"
      git clone https://github.com/abhigyanpatwari/GitNexus.git "$GITNEXUS_DIR"
      ok "Cloned → $GITNEXUS_DIR"
    fi
  else
    info "gh CLI not found — cloning directly..."
    git clone https://github.com/abhigyanpatwari/GitNexus.git "$GITNEXUS_DIR"
    ok "Cloned → $GITNEXUS_DIR"
  fi

  # Install web UI dependencies
  if [ -d "$GITNEXUS_WEB_DIR" ]; then
    step "Installing Web UI dependencies"
    (cd "$GITNEXUS_WEB_DIR" && npm install 2>&1)
    ok "Web UI dependencies installed"
  else
    warn "gitnexus-web/ not found in cloned repo"
  fi
}

# ── Main ─────────────────────────────────────────────────────
main() {
  echo -e "\n${CYAN}🔧 GitNexus for Antigravity${NC}"

  check_prereqs
  configure_mcp
  install_sync_script
  fork_web_ui
  warm_cache

  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════${NC}"
  echo -e "${GREEN}  Setup complete!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${DIM}Index a repo${NC}    cd your-project && npx gitnexus analyze --skills"
  echo -e "  ${DIM}Sync skills${NC}    gitnexus-sync"
  echo -e "  ${DIM}Web UI${NC}         npx gitnexus serve & cd $GITNEXUS_WEB_DIR && npm run dev"
  echo -e "  ${DIM}Re-run setup${NC}   ./setup.sh"
  echo ""
  echo -e "  ${YELLOW}→ Restart Antigravity to load MCP${NC}"
  echo ""
}

main "$@"
