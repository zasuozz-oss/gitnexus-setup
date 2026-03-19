#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# GitNexus Auto Setup — fully automatic, zero manual steps
#
# Fresh install:  curl -fsSL <raw-url> | bash
#                 — or —  ./setup.sh
#
# Update:         ./setup.sh update
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
REPO_URL="https://github.com/abhigyanpatwari/GitNexus.git"
ANTIGRAVITY_MCP="$HOME/.gemini/antigravity/mcp_config.json"

# Detect install dir: repo dir > env var > current working dir
detect_install_dir() {
  local script_dir
  # If script is run directly (not piped), check if we're inside the repo
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/gitnexus/package.json" ]; then
      INSTALL_DIR="$script_dir"
      return
    fi
  fi
  # Env var override, or clone into current directory
  INSTALL_DIR="${GITNEXUS_DIR:-$(pwd)/git-nexus}"
}

detect_install_dir

GITNEXUS_PKG="$INSTALL_DIR/gitnexus"
GITNEXUS_WEB="$INSTALL_DIR/gitnexus-web"
MCP_ENTRY="$GITNEXUS_PKG/dist/cli/index.js"

# ── Prereqs ──────────────────────────────────────────────────
check_prereqs() {
  step "Checking prerequisites"

  local ok_count=0

  if ! command -v git &>/dev/null; then
    err "git not found"; exit 1
  fi
  ok "git $(git --version | awk '{print $3}')"
  ((ok_count++))

  if ! command -v node &>/dev/null; then
    err "Node.js not found. Install Node >= 18 first."; exit 1
  fi
  local node_major
  node_major=$(node -v | sed 's/v//' | cut -d. -f1)
  if (( node_major < 18 )); then
    err "Node >= 18 required (found $(node -v))"; exit 1
  fi
  ok "Node $(node -v)"
  ((ok_count++))

  if ! command -v npm &>/dev/null; then
    err "npm not found"; exit 1
  fi
  ok "npm $(npm -v)"
  ((ok_count++))

  if ! command -v python3 &>/dev/null; then
    warn "python3 not found — MCP config will need manual setup"
  else
    ok "python3 $(python3 --version | awk '{print $2}')"
  fi
}

# ── Clone ────────────────────────────────────────────────────
clone_repo() {
  step "Cloning repository"

  if [ -f "$GITNEXUS_PKG/package.json" ]; then
    ok "Already cloned at $INSTALL_DIR"
    return
  fi

  mkdir -p "$INSTALL_DIR"
  # Clone into install dir (handles both empty and non-existent dirs)
  if [ "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
    err "$INSTALL_DIR is not empty and not a GitNexus repo"
    exit 1
  fi

  git clone "$REPO_URL" "$INSTALL_DIR"
  ok "Cloned to $INSTALL_DIR"
}

# ── Install packages ─────────────────────────────────────────
install_packages() {
  step "Installing dependencies"

  for dir in "$GITNEXUS_PKG" "$GITNEXUS_WEB"; do
    local name="$(basename "$dir")"
    if [ ! -f "$dir/package.json" ]; then
      warn "Skipping $name (no package.json)"
      continue
    fi
    info "Installing $name..."
    (cd "$dir" && npm install --no-fund --no-audit 2>&1 | tail -1)
    ok "$name"
  done
}

# ── Get version ──────────────────────────────────────────────
get_version() {
  if [ -f "$GITNEXUS_PKG/package.json" ]; then
    node -e "console.log(require('$GITNEXUS_PKG/package.json').version)" 2>/dev/null || echo "?"
  else
    echo "—"
  fi
}

# ── Configure MCP (upsert — always writes correct path) ──────
configure_mcp() {
  step "Configuring Antigravity MCP"

  if ! command -v python3 &>/dev/null; then
    warn "python3 not found — add manually to $ANTIGRAVITY_MCP:"
    echo "  \"gitnexus\": {\"command\":\"node\",\"args\":[\"$MCP_ENTRY\",\"mcp\"]}"
    return
  fi

  mkdir -p "$(dirname "$ANTIGRAVITY_MCP")"
  [ -f "$ANTIGRAVITY_MCP" ] || echo '{"mcpServers":{}}' > "$ANTIGRAVITY_MCP"

  local action
  action=$(python3 << PYEOF
import json, sys

path = "$ANTIGRAVITY_MCP"
entry_path = "$MCP_ENTRY"

with open(path) as f:
    cfg = json.load(f)

servers = cfg.setdefault("mcpServers", {})
expected = {"command": "node", "args": [entry_path, "mcp"]}
existing = servers.get("gitnexus")

if existing == expected:
    print("unchanged")
    sys.exit(0)

action = "updated" if existing else "added"
servers["gitnexus"] = expected

with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(action)
PYEOF
  )

  case "$action" in
    added)    ok "MCP entry added → $MCP_ENTRY" ;;
    updated)  ok "MCP path updated → $MCP_ENTRY" ;;
    unchanged) ok "MCP already correct" ;;
  esac
}

# ── Update ───────────────────────────────────────────────────
do_update() {
  echo -e "\n${CYAN}🔄 GitNexus Update${NC}"

  check_prereqs

  if [ ! -d "$INSTALL_DIR/.git" ]; then
    err "Not a git repo at $INSTALL_DIR. Run setup first."
    exit 1
  fi

  local old_ver
  old_ver="$(get_version)"

  step "Pulling latest"
  (cd "$INSTALL_DIR" && git pull --ff-only)
  ok "Git pull complete"

  local new_ver
  new_ver="$(get_version)"

  if [ "$old_ver" = "$new_ver" ]; then
    ok "Already on latest (v$new_ver)"
  else
    info "v$old_ver → v$new_ver"
  fi

  step "Clean rebuild"
  rm -rf "$GITNEXUS_PKG/dist" "$GITNEXUS_PKG/node_modules" "$GITNEXUS_WEB/node_modules"
  ok "Cleaned old builds"

  install_packages
  configure_mcp
  print_done "Updated to v$(get_version)"
}

# ── Fresh setup ──────────────────────────────────────────────
do_setup() {
  echo -e "\n${CYAN}🔧 GitNexus Auto Setup${NC}"

  check_prereqs
  clone_repo
  install_packages
  configure_mcp
  print_done "Setup complete (v$(get_version))"
}

# ── Done banner ──────────────────────────────────────────────
print_done() {
  local msg="${1:-Done}"
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════${NC}"
  echo -e "${GREEN}  $msg${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${DIM}Install${NC}   $INSTALL_DIR"
  echo -e "  ${DIM}CLI${NC}       cd $INSTALL_DIR && npx gitnexus --help"
  echo -e "  ${DIM}Analyze${NC}   cd $INSTALL_DIR && npx gitnexus analyze"
  echo -e "  ${DIM}Web UI${NC}    cd $INSTALL_DIR/gitnexus-web && npm run dev"
  echo -e "  ${DIM}Update${NC}    $INSTALL_DIR/setup.sh update"
  echo ""
  echo -e "  ${YELLOW}→ Restart Antigravity to load MCP${NC}"
  echo ""
}

# ── Usage ────────────────────────────────────────────────────
usage() {
  echo "Usage: ./setup.sh [command]"
  echo ""
  echo "Commands:"
  echo "  (none)     Full auto setup from scratch"
  echo "  update     Pull latest + clean rebuild"
  echo "  help       Show this help"
  echo ""
  echo "Environment:"
  echo "  GITNEXUS_DIR   Override install directory (default: ./git-nexus)"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────
main() {
  case "${1:-}" in
    update|upgrade)  do_update ;;
    help|--help|-h)  usage ;;
    *)               do_setup ;;
  esac
}

main "$@"
