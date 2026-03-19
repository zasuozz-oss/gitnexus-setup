# GitNexus + Antigravity Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> One-command setup [GitNexus](https://github.com/abhigyanpatwari/GitNexus) MCP server cho [Antigravity](https://github.com/AntimatterAI/antimatter).

---

## GitNexus là gì?

[GitNexus](https://github.com/abhigyanpatwari/GitNexus) — tác giả [Abhigyan Patwari](https://github.com/abhigyanpatwari) — là một **code intelligence engine** xây dựng knowledge graph từ codebase của bạn.

Nó phân tích AST (Tree-sitter), trích xuất mọi function, class, dependency, call chain, rồi expose qua [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) để AI agent có thể:

- **Hiểu cấu trúc thực sự** của codebase thay vì chỉ grep text
- **Phân tích blast radius** trước khi sửa code — biết chính xác cái gì sẽ vỡ
- **Trace execution flows** — theo dõi dòng chảy từ entry point đến terminal
- **Rename an toàn** qua knowledge graph, không phải find-and-replace mù

Hỗ trợ 13 ngôn ngữ: TypeScript, JavaScript, Python, Java, Kotlin, C#, Go, Rust, PHP, Ruby, Swift, C, C++.

> GitNexus sử dụng [PolyForm Noncommercial License](https://github.com/abhigyanpatwari/GitNexus/blob/main/LICENSE). Repo setup script này (chỉ chứa script, không chứa source GitNexus) sử dụng [MIT License](LICENSE).

---

## Quick Start

**Cách 1 — One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/zasuozz-oss/gitnexus-setup/main/setup.sh | bash
```

**Cách 2 — Clone rồi chạy:**

```bash
git clone https://github.com/zasuozz-oss/gitnexus-setup.git
cd gitnexus-setup
./setup.sh
```

Script tự động:

1. ✅ Kiểm tra Node.js ≥ 18, npm, git
2. 📦 Clone [GitNexus](https://github.com/abhigyanpatwari/GitNexus) vào `./git-nexus`
3. 📦 Install dependencies + build
4. ⚙️ Cấu hình MCP vào `~/.gemini/antigravity/mcp_config.json`

Sau khi xong → **restart Antigravity** để load MCP server mới.

---

## Sử dụng

### 1. Index codebase

Sau khi setup, chạy lệnh sau **trong thư mục project** bạn muốn phân tích:

```bash
npx gitnexus analyze
```

GitNexus sẽ tạo knowledge graph trong `.gitnexus/` (đã gitignore). Quá trình này chạy 1 lần, sau có thể re-analyze khi code thay đổi.

### 2. Sử dụng trong Antigravity

Khi đã index xong, Antigravity tự động có thể sử dụng các MCP tools khi bạn làm việc với codebase đó:

```
# Tìm execution flows liên quan đến authentication
gitnexus_query({query: "authentication middleware"})

# Xem 360° một function — ai gọi nó, nó gọi ai, thuộc flow nào
gitnexus_context({name: "validateUser"})

# Kiểm tra blast radius trước khi sửa
gitnexus_impact({target: "UserService", direction: "upstream"})

# Xem thay đổi ảnh hưởng gì trước khi commit
gitnexus_detect_changes({scope: "staged"})

# Rename an toàn qua knowledge graph
gitnexus_rename({symbol_name: "oldName", new_name: "newName", dry_run: true})
```

### 3. Web UI (tùy chọn)

```bash
cd git-nexus/gitnexus-web
npm run dev
```

Mở browser xem visual graph explorer + AI chat. Hoặc dùng online tại [gitnexus.vercel.app](https://gitnexus.vercel.app).

---

## MCP Tools Reference

| Tool | Mô tả | Khi nào dùng |
|------|--------|-------------|
| `query` | Tìm execution flows theo concept (hybrid: BM25 + semantic) | Muốn hiểu code liên quan đến 1 chủ đề |
| `context` | 360° symbol view — callers, callees, processes | Cần biết mọi thứ về 1 function/class |
| `impact` | Blast radius — d=1 sẽ vỡ, d=2 có thể ảnh hưởng, d=3 cần test | **Trước khi sửa** bất kỳ symbol nào |
| `detect_changes` | Map git diff → affected processes + risk level | **Trước khi commit** |
| `rename` | Multi-file rename qua knowledge graph + text search | Khi cần rename symbol an toàn |
| `cypher` | Custom Cypher queries trên code graph | Query phức tạp, tùy biến |
| `list_repos` | Liệt kê tất cả repos đã index | Khi làm việc multi-repo |

---

## Update

Khi GitNexus có version mới:

```bash
./setup.sh update
```

Script sẽ `git pull` → clean rebuild → cập nhật MCP path.

---

## Cấu hình

### Chọn thư mục cài đặt

```bash
GITNEXUS_DIR=/path/to/dir ./setup.sh
```

Mặc định clone vào `./git-nexus` (thư mục đang đứng).

### MCP Config

Script tự ghi vào `~/.gemini/antigravity/mcp_config.json`:

```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "node",
      "args": ["<absolute-path>/gitnexus/dist/cli/index.js", "mcp"]
    }
  }
}
```

Đường dẫn tự tính dựa trên vị trí thực tế — **không fix cứng**, hoạt động đúng trên mọi thiết bị.

---

## Yêu cầu hệ thống

| | Bắt buộc | Tùy chọn |
|---|---------|----------|
| **Node.js** | ≥ 18 | |
| **npm** | ✓ (đi kèm Node.js) | |
| **git** | ✓ | |
| **python3** | | Cho auto-config MCP |
| **OS** | macOS, Linux | |

---

## Credits

- **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** by [Abhigyan Patwari](https://github.com/abhigyanpatwari) — Code intelligence engine
- **[Antigravity](https://github.com/AntimatterAI/antimatter)** — AI coding assistant
- **[MCP](https://modelcontextprotocol.io/)** — Model Context Protocol

## License

Script setup: [MIT License](LICENSE).  
GitNexus: [PolyForm Noncommercial License](https://github.com/abhigyanpatwari/GitNexus/blob/main/LICENSE).
