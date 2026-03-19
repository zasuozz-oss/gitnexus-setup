# GitNexus + Antigravity Setup

> Auto-setup [GitNexus](https://github.com/abhigyanpatwari/GitNexus) với [Antigravity](https://github.com/AntimatterAI/antimatter) — zero manual steps.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/zasuozz-oss/gitnexus-setup/main/setup.sh | bash
```

Hoặc clone repo này rồi chạy:

```bash
git clone https://github.com/zasuozz-oss/gitnexus-setup.git
cd gitnexus-setup
./setup.sh
```

## Script tự động làm gì?

| Bước | Chi tiết |
|------|----------|
| **1. Kiểm tra prerequisites** | Node.js ≥ 18, npm, git, python3 |
| **2. Clone GitNexus** | Từ [upstream repo](https://github.com/abhigyanpatwari/GitNexus) vào thư mục hiện tại |
| **3. Install dependencies** | `gitnexus` (core CLI + MCP server) và `gitnexus-web` (Web UI) |
| **4. Configure MCP** | Tự động thêm/cập nhật entry `gitnexus` trong `~/.gemini/antigravity/mcp_config.json` |

Sau khi chạy xong, **restart Antigravity** để load MCP server mới.

## Update

Khi GitNexus upstream có version mới:

```bash
./setup.sh update
```

Script sẽ:
- `git pull --ff-only` lấy code mới nhất
- Xóa `node_modules` + `dist` (clean rebuild)
- Reinstall + rebuild
- Cập nhật lại đường dẫn MCP nếu cần

## Cấu hình nâng cao

### Chọn thư mục cài đặt

Mặc định script clone vào `./git-nexus`. Override bằng biến môi trường:

```bash
GITNEXUS_DIR=/path/to/your/dir ./setup.sh
```

### MCP Config

Script tự động ghi vào `~/.gemini/antigravity/mcp_config.json`:

```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "node",
      "args": ["/absolute/path/to/gitnexus/dist/cli/index.js", "mcp"]
    }
  }
}
```

Đường dẫn được tính tự động dựa trên vị trí thực tế của repo — **không fix cứng**, hoạt động đúng trên mọi thiết bị.

## GitNexus MCP Tools

Sau khi setup, Antigravity có thể sử dụng các tools:

| Tool | Mô tả |
|------|--------|
| `gitnexus_query` | Tìm execution flows theo concept |
| `gitnexus_context` | Xem 360° của một symbol (callers, callees, processes) |
| `gitnexus_impact` | Blast radius trước khi sửa code |
| `gitnexus_detect_changes` | Kiểm tra scope thay đổi trước commit |
| `gitnexus_rename` | Rename an toàn qua knowledge graph |
| `gitnexus_cypher` | Custom Cypher queries trên code graph |

## Yêu cầu hệ thống

- **Node.js** ≥ 18
- **npm** (đi kèm Node.js)
- **git**
- **python3** (cho auto-config MCP, không bắt buộc)
- **macOS** hoặc **Linux**

## License

Script setup được phát hành theo [MIT License](LICENSE).  
GitNexus bản thân sử dụng [PolyForm Noncommercial License](https://github.com/abhigyanpatwari/GitNexus/blob/main/LICENSE).
