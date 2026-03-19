# GitNexus for Antigravity

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
**🌐 [Tiếng Việt](README.vi.md)**

> Auto-setup [GitNexus](https://github.com/abhigyanpatwari/GitNexus) MCP server for [Antigravity](https://github.com/google-deepmind/antigravity).

---

## What is GitNexus?

[GitNexus](https://github.com/abhigyanpatwari/GitNexus) — by [Abhigyan Patwari](https://github.com/abhigyanpatwari) — is a **code intelligence engine** that builds a knowledge graph from any codebase.

It parses ASTs (Tree-sitter), extracts every function, class, dependency, and call chain, then exposes it via [Model Context Protocol (MCP)](https://modelcontextprotocol.io/). This setup script configures GitNexus specifically for **Antigravity** so you get code intelligence tools directly in your AI assistant.

Supports 13 languages: TypeScript, JavaScript, Python, Java, Kotlin, C#, Go, Rust, PHP, Ruby, Swift, C, C++.

### Why?

Without GitNexus, AI assistants read code **file-by-file** — they can grep and search, but don't truly understand how pieces connect. GitNexus gives AI a **structural map** of your entire codebase:

- 🔍 **Trace execution flows** — see the full call chain `A → B → C`, not just individual files
- 💥 **Blast radius analysis** — before editing a function, know exactly what will break (direct callers, indirect dependents, affected modules)
- ⚠️ **Pre-commit risk detection** — map your `git diff` to affected processes and get a risk assessment before pushing
- ✏️ **Safe multi-file renames** — rename a symbol across the entire codebase using the knowledge graph, not regex find-and-replace

> **In short:** GitNexus turns your AI from a "file reader" into a "codebase navigator."

---

## Quick Start

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/zasuozz-oss/gitnexus-setup/main/setup.sh | bash
```

**Or clone and run:**

```bash
git clone https://github.com/zasuozz-oss/gitnexus-setup.git
cd gitnexus-setup
./setup.sh
```

The script does four things:

1. **Configures** Antigravity MCP (`~/.gemini/antigravity/mcp_config.json`)
2. **Installs** `gitnexus-sync` to `~/.local/bin/` — syncs GitNexus skills to Antigravity format
3. **Clones** the GitNexus repo (via `gh fork` or `git clone`) and installs Web UI dependencies
4. **Pre-downloads** `gitnexus` via npx cache

After completion → **restart Antigravity** to load the MCP server.

---

## Usage

### 1. Index a codebase

Go to any project directory and index it:

```bash
cd your-project
npx gitnexus analyze --skills
```

This creates a knowledge graph in `.gitnexus/` (gitignored). The `--skills` flag generates skill files for AI agents. Run once per repo, re-run when code changes.

### 2. Sync skills to Antigravity

GitNexus writes skills to `.claude/skills/` (Claude Code format). Run `gitnexus-sync` to convert them to Antigravity format:

```bash
gitnexus-sync
```

This copies skills to `.agents/skills/gitnexus-*/SKILL.md` with proper YAML frontmatter. Supports both flat files (`.claude/skills/*.md`) and generated skills (`.claude/skills/generated/*/SKILL.md`).

### 3. Launch the Web UI

Visualize the knowledge graph in your browser:

```bash
./web-ui.sh
```

This starts both the **backend** (`http://127.0.0.1:4747`) and **frontend** (`http://localhost:5173`) in one command. Press `Ctrl+C` to stop both.

> **Note:** Requires `./setup.sh` to have been run first (clones GitNexus repo and installs dependencies).

### 4. Use in Antigravity

Once indexed, Antigravity automatically has access to these MCP tools when working with that codebase:

```
# Find execution flows by concept
gitnexus_query({query: "authentication middleware"})

# 360° view — who calls it, what it calls, which flows it belongs to
gitnexus_context({name: "validateUser"})

# Blast radius before editing
gitnexus_impact({target: "UserService", direction: "upstream"})

# Check what your changes affect before committing
gitnexus_detect_changes({scope: "staged"})

# Safe rename via knowledge graph
gitnexus_rename({symbol_name: "oldName", new_name: "newName", dry_run: true})
```

---

## MCP Tools

| Tool | What it does | When to use |
|------|-------------|-------------|
| `query` | Search execution flows (hybrid: BM25 + semantic) | Understand code related to a topic |
| `context` | 360° symbol view — callers, callees, processes | Full picture of a function/class |
| `impact` | Blast radius analysis with depth grouping | **Before editing** any symbol |
| `detect_changes` | Map git diff → affected processes + risk | **Before committing** |
| `rename` | Multi-file rename via knowledge graph | Safe symbol renaming |
| `cypher` | Custom Cypher queries on code graph | Complex/custom queries |
| `list_repos` | List all indexed repositories | Multi-repo workflows |

---

## Project Structure

```
gitnexus-setup/
├── setup.sh          # Main setup — MCP config, sync install, Web UI clone, npx cache
├── sync-skills.sh    # Bridge .claude/skills/ → .agents/skills/ (Antigravity format)
├── web-ui.sh         # Launch backend + frontend in one command
├── test-sync.sh      # Test suite for sync-skills.sh (6 tests)
├── GitNexus/         # Cloned GitNexus repo (gitignored, created by setup.sh)
├── LICENSE           # MIT
└── README.md
```

---

## Update

```bash
./setup.sh update
```

Updates gitnexus to the latest version and re-validates MCP config.

---

## Testing

Run the sync-skills test suite:

```bash
bash test-sync.sh
```

Covers: flat skills, generated skills, frontmatter rewriting, idempotency, graceful error handling, and mixed skill layouts.

---

## How it works

The script configures `~/.gemini/antigravity/mcp_config.json`:

```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "npx",
      "args": ["-y", "gitnexus@latest", "mcp"]
    }
  }
}
```

Uses `npx gitnexus@latest` — always uses the latest version, no hardcoded paths, works on any machine.

---

## Requirements

- **Node.js** ≥ 18 (with npm)
- **python3** (optional, for auto-config MCP)
- **gh** CLI (optional, for forking instead of cloning)
- **macOS** or **Linux**

---

## Credits

- **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** by [Abhigyan Patwari](https://github.com/abhigyanpatwari)
- **[MCP](https://modelcontextprotocol.io/)** — Model Context Protocol

## License

Setup script: [MIT](LICENSE) · GitNexus: [PolyForm Noncommercial](https://github.com/abhigyanpatwari/GitNexus/blob/main/LICENSE)
