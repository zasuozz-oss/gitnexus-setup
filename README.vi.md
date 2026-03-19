# GitNexus for Antigravity

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
**🌐 [English](README.md)**

> Auto-setup [GitNexus](https://github.com/abhigyanpatwari/GitNexus) MCP server cho [Antigravity](https://github.com/google-deepmind/antigravity).

---

## GitNexus là gì?

[GitNexus](https://github.com/abhigyanpatwari/GitNexus) — tác giả [Abhigyan Patwari](https://github.com/abhigyanpatwari) — là một **code intelligence engine** xây dựng knowledge graph từ codebase.

Nó phân tích AST (Tree-sitter), trích xuất mọi function, class, dependency, call chain, rồi expose qua [Model Context Protocol (MCP)](https://modelcontextprotocol.io/). Script này cấu hình GitNexus riêng cho **Antigravity** để bạn có code intelligence tools trực tiếp trong AI assistant.

Hỗ trợ 13 ngôn ngữ: TypeScript, JavaScript, Python, Java, Kotlin, C#, Go, Rust, PHP, Ruby, Swift, C, C++.

### Tại sao cần GitNexus?

Nếu không có GitNexus, AI chỉ đọc code **từng file một** — có thể grep và search, nhưng không thực sự hiểu các phần code liên kết với nhau thế nào. GitNexus cung cấp cho AI một **bản đồ cấu trúc** toàn bộ codebase:

- 🔍 **Truy vết luồng thực thi** — xem toàn bộ call chain `A → B → C`, không chỉ từng file riêng lẻ
- 💥 **Phân tích blast radius** — trước khi sửa một function, biết chính xác những gì sẽ bị ảnh hưởng (caller trực tiếp, phụ thuộc gián tiếp, module liên quan)
- ⚠️ **Phát hiện rủi ro trước khi commit** — map `git diff` tới các process bị ảnh hưởng và đánh giá mức độ rủi ro trước khi push
- ✏️ **Rename an toàn đa file** — đổi tên symbol trên toàn bộ codebase dựa vào knowledge graph, không phải regex find-and-replace

> **Tóm lại:** GitNexus biến AI từ "đọc file" thành "hiểu kiến trúc."

---

## Quick Start

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/zasuozz-oss/gitnexus-setup/main/setup.sh | bash
```

**Hoặc clone rồi chạy:**

```bash
git clone https://github.com/zasuozz-oss/gitnexus-setup.git
cd gitnexus-setup
./setup.sh
```

Script làm 4 việc:

1. **Cấu hình** Antigravity MCP (`~/.gemini/antigravity/mcp_config.json`)
2. **Cài đặt** `gitnexus-sync` vào `~/.local/bin/` — đồng bộ skill GitNexus sang định dạng Antigravity
3. **Clone** repo GitNexus (qua `gh fork` hoặc `git clone`) và cài Web UI dependencies
4. **Pre-download** `gitnexus` qua npx cache

Sau khi xong → **restart Antigravity** để load MCP server mới.

---

## Sử dụng

### 1. Index codebase

Vào thư mục project bất kỳ và index:

```bash
cd your-project
npx gitnexus analyze --skills
```

GitNexus tạo knowledge graph trong `.gitnexus/` (đã gitignore). Flag `--skills` tạo skill files cho AI agent. Chạy 1 lần, re-analyze khi code thay đổi.

### 2. Đồng bộ skill sang Antigravity

GitNexus ghi skill vào `.claude/skills/` (định dạng Claude Code). Chạy `gitnexus-sync` để chuyển sang định dạng Antigravity:

```bash
gitnexus-sync
```

Skill sẽ được copy sang `.agents/skills/gitnexus-*/SKILL.md` kèm YAML frontmatter chuẩn. Hỗ trợ cả file phẳng (`.claude/skills/*.md`) và skill sinh tự động (`.claude/skills/generated/*/SKILL.md`).

### 3. Khởi chạy Web UI

Trực quan hóa knowledge graph trên trình duyệt:

```bash
./web-ui.sh
```

Khởi động cả **backend** (`http://127.0.0.1:4747`) lẫn **frontend** (`http://localhost:5173`) trong một lệnh. Nhấn `Ctrl+C` để dừng cả hai.

> **Lưu ý:** Cần chạy `./setup.sh` trước (clone repo GitNexus và cài dependencies).

### 4. Sử dụng trong Antigravity

Khi đã index, Antigravity tự động có thể dùng các MCP tools:

```
# Tìm execution flows theo concept
gitnexus_query({query: "authentication middleware"})

# Xem 360° — ai gọi nó, nó gọi ai, thuộc flow nào
gitnexus_context({name: "validateUser"})

# Blast radius trước khi sửa
gitnexus_impact({target: "UserService", direction: "upstream"})

# Xem thay đổi ảnh hưởng gì trước khi commit
gitnexus_detect_changes({scope: "staged"})

# Rename an toàn qua knowledge graph
gitnexus_rename({symbol_name: "oldName", new_name: "newName", dry_run: true})
```

---

## MCP Tools

| Tool | Mô tả | Khi nào dùng |
|------|--------|-------------|
| `query` | Tìm execution flows (hybrid: BM25 + semantic) | Muốn hiểu code liên quan đến 1 chủ đề |
| `context` | 360° symbol view — callers, callees, processes | Cần biết mọi thứ về 1 function/class |
| `impact` | Blast radius với phân tầng depth | **Trước khi sửa** bất kỳ symbol nào |
| `detect_changes` | Map git diff → affected processes + risk | **Trước khi commit** |
| `rename` | Multi-file rename qua knowledge graph | Rename symbol an toàn |
| `cypher` | Custom Cypher queries trên code graph | Query phức tạp, tùy biến |
| `list_repos` | Liệt kê tất cả repos đã index | Multi-repo |

---

## Cấu trúc dự án

```
gitnexus-setup/
├── setup.sh          # Setup chính — MCP config, cài sync, clone Web UI, npx cache
├── sync-skills.sh    # Chuyển .claude/skills/ → .agents/skills/ (định dạng Antigravity)
├── web-ui.sh         # Khởi chạy backend + frontend bằng 1 lệnh
├── test-sync.sh      # Bộ test cho sync-skills.sh (6 test cases)
├── GitNexus/         # Repo GitNexus đã clone (gitignored, tạo bởi setup.sh)
├── LICENSE           # MIT
└── README.md
```

---

## Cập nhật

```bash
./setup.sh update
```

Cập nhật gitnexus lên version mới nhất và kiểm tra lại MCP config.

---

## Chạy test

Chạy bộ test cho sync-skills:

```bash
bash test-sync.sh
```

Bao gồm: flat skills, generated skills, ghi đè frontmatter, idempotency, xử lý lỗi, và bố cục skill hỗn hợp.

---

## Cách hoạt động

Script cấu hình `~/.gemini/antigravity/mcp_config.json`:

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

Dùng `npx gitnexus@latest` — luôn dùng version mới nhất, không hardcode đường dẫn, hoạt động trên mọi thiết bị.

---

## Yêu cầu

- **Node.js** ≥ 18 (kèm npm)
- **python3** (tùy chọn, cho auto-config MCP)
- **gh** CLI (tùy chọn, để fork thay vì clone)
- **macOS** hoặc **Linux**

---

## Credits

- **[GitNexus](https://github.com/abhigyanpatwari/GitNexus)** by [Abhigyan Patwari](https://github.com/abhigyanpatwari)
- **[MCP](https://modelcontextprotocol.io/)** — Model Context Protocol

## License

Script setup: [MIT](LICENSE) · GitNexus: [PolyForm Noncommercial](https://github.com/abhigyanpatwari/GitNexus/blob/main/LICENSE)
