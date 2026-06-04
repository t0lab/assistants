# Web backends cho Hermes: SearXNG + Firecrawl trên VM riêng, public qua Cloudflare Tunnel

**Status:** accepted
**Date:** 2026-06-04
**Supersedes (một phần):** [search-backend-searxng.md](./search-backend-searxng.md) — phần vận chuyển
NetBird/bind-mesh/no-auth. Giữ nguyên lựa chọn SearXNG + engine-mix + `limiter: false`.

## Context

Toolset `web` của Hermes cần **hai** năng lực: `web_search` và `web_extract` (fetch + đọc 1 URL).
Đọc source `plugins/web/` (2026-06-04): backend Hermes hỗ trợ = `brave_free, ddgs, exa, firecrawl,
parallel, searxng, tavily, xai`. Sự thật quyết định:

1. **`searxng` chỉ search** (`supports_extract()` → `False`). Để có `web_extract` self-host phải dùng
   **`firecrawl`** — backend duy nhất Hermes hỗ trợ sẵn cho extract mà tự host được.
2. **Không có provider `crawl4ai`.** API Crawl4AI (`/crawl` @ :11235) không Firecrawl-compatible → muốn
   dùng phải tự viết + maintain plugin. Loại. `crw` (Rust, drop-in Firecrawl) hấp dẫn nhưng AGPL + mới
   → giữ làm option tương lai, không chọn lần này.
3. **Client Hermes không chèn được custom header** (đọc source):
   - `searxng/provider.py`: chỉ đọc `SEARXNG_URL`, httpx, `Accept: application/json`, **không** auth
     header — **nhưng httpx tôn trọng `user:pass@host`** (HTTP Basic Auth nhúng URL).
   - `firecrawl/provider.py`: đọc `FIRECRAWL_API_KEY` + `FIRECRAWL_API_URL`, dùng SDK chính thức, gửi
     `Authorization: Bearer <key>`, hỗ trợ cả search lẫn extract.
4. **→ Cloudflare Access KHÔNG dùng được trước endpoint Hermes gọi.** SSO cần browser; Service Token
   cần header `CF-Access-Client-Id/Secret` mà Hermes không gửi → CF 302 về login, bot chết. Đây là
   blocker đã gặp và là lý do ADR cũ chọn NetBird.

Thay đổi yêu cầu so với ADR cũ: backends **không** đặt trên home server / NetBird nữa, mà trên **một VM
riêng ngoài mesh**, expose ra internet qua **Cloudflare Tunnel**. Hệ quả: biên bảo mật không còn là
WireGuard peer-auth của NetBird → **phải tự dựng auth ở tầng app**, bằng đúng credential mà Hermes gửi
được (Basic auth cho SearXNG, Bearer cho Firecrawl).

## Decision

**Một VM riêng (ngoài NetBird) chạy SearXNG + Firecrawl sau Caddy (auth) sau Cloudflare Tunnel; VM không
mở inbound port; auth ở tầng app bằng credential Hermes gửi được.**

Topology:

```
Hermes (phone hoặc docker home)
  │  SEARXNG_URL      = https://<user>:<pass>@search.timezlab.org   ← Basic auth (httpx hiểu)
  │  FIRECRAWL_API_URL= https://crawl.timezlab.org
  │  FIRECRAWL_API_KEY= <bearer-secret>                             ← SDK gửi Authorization: Bearer
  ▼  DNS Cloudflare-proxied ── WAF: rate-limit + geo-block ── (KHÔNG đặt Access lên 2 host này)
  │  Cloudflare Tunnel (outbound-only)
  ▼
VM (host dùng chung — KHÔNG publish port nào, kể cả localhost):
  tz-cloudflared (container, join tz-edge) ─► http://tz-nginx:80  (Host giữ nguyên)
  tz-nginx (chỉ expose :80 TRONG net, KHÔNG ports: ra host)
       ├── server_name search.timezlab.org → basic auth → http://tz-searxng:8080
       └── server_name crawl.timezlab.org  → kiểm Bearer → http://tz-firecrawl-api:3002
  Mọi service ở docker net `tz-edge`; KHÔNG service nào có `ports:` map ra host.
  (Tên theo namespace org `tz-`, KHÔNG prefix consumer "hermes" — VM tái dùng cho service khác.)
  (tùy chọn) admin.timezlab.org → Cloudflare Access (email SSO) → SearXNG prefs / Firecrawl playground
                                                                    ← CHỈ cho người, Hermes không dùng
```

0. **Docker network chung `tz-edge`** (external): tz-nginx + tz-searxng + tz-firecrawl-* + tz-cloudflared
   cùng net này. Backend reachable qua tên container, **không** service nào lộ port ra host. Namespace
   `tz-` (org timezlab, KHÔNG "hermes") để VM tái dùng cho service khác mà không đụng tên.
1. **Compose SearXNG**: tái dùng `searxng/docker-compose.yml` nhưng **bỏ publish port host** (gỡ bind
   IP NetBird), đổi `container_name` → `tz-searxng` (+ `tz-searxng-valkey`), join `tz-edge`; nginx gọi
   `http://tz-searxng:8080`. Giữ `limiter: false`, `formats: [html, json]`, engine-mix chống-429
   (bing/mojeek/qwant/startpage/wikipedia; tắt google/ddg/brave).
2. **Compose Firecrawl** (`firecrawl/` mới): self-host stack (`tz-firecrawl-api`, `-worker`,
   `-playwright`, `-redis`, `-rabbitmq`, `-nuq-postgres`) join `tz-edge`; api **không** publish host
   port, nginx gọi `http://tz-firecrawl-api:3002`. `USE_DB_AUTHENTICATION=false` = **Firecrawl tự nó
   KHÔNG check key** → **bearer enforcement nằm ở nginx**, không phải Firecrawl.
3. **nginx** (`nginx/` mới — container `tz-nginx`): chỉ `expose: [80]` TRONG net `tz-edge`, **không**
   `ports:` ra host. Route theo `server_name`: `search.*` → `auth_basic` (htpasswd, password ngoài
   repo) → tz-searxng; `crawl.*` → `map $http_authorization` khớp `Bearer <key>` (else 401) →
   tz-firecrawl-api. Là cổng auth duy nhất.
4. **cloudflared** (container `tz-cloudflared`, join `tz-edge`): **token mode** (`tunnel run`,
   `TUNNEL_TOKEN` từ `.env`). **Ingress cấu hình trên dashboard Cloudflare** (Zero Trust → Tunnels →
   Public Hostname): `search.*` và `crawl.*` → Service `http://tz-nginx:80` (cloudflared ở `tz-edge`
   nên resolve `tz-nginx`; Host giữ nguyên → nginx vhost tự tách). Không service nào publish port host
   → **cloudflared là đường vào duy nhất**. Đánh đổi: ingress sống ở dashboard, KHÔNG trong repo (xem
   Consequences).
5. **Hermes env** (cả Jarvis `~/.hermes/.env` lẫn Friday `~/.hermes/profiles/friday/.env`):
   `SEARXNG_URL=https://<u>:<p>@search.timezlab.org`, `FIRECRAWL_API_URL=https://crawl.timezlab.org`,
   `FIRECRAWL_API_KEY=<bearer>`. `web.search_backend: searxng` + `web.extract_backend: firecrawl`
   trong config.yaml (config-as-code). Bật toolset `web` per-platform (re-audit sau nâng cấp Hermes).
   Friday: web ở allowlist; vẫn TUYỆT ĐỐI không bật terminal/code_execution/file/browser/device.
6. **KHÔNG Cloudflare Access trên `search.*`/`crawl.*`** (phá client-máy). Access chỉ cho host admin
   người-dùng (tùy chọn). WAF rate-limit/geo-block là defense-in-depth cho 2 host máy.

## Alternatives considered

- **Giữ NetBird (ADR cũ)** — rejected lần này: yêu cầu mới là VM riêng ngoài mesh + Cloudflare; và cần
  client có thể ở ngoài mesh. (Nếu sau muốn private trở lại, NetBird vẫn sạch hơn — xem *Revisit*.)
- **Crawl4AI** — rejected: Hermes không có provider; API không tương thích → phải viết+nuôi plugin,
  không lợi gì cho use-case extract-backend.
- **crw (Rust, drop-in Firecrawl)** — không chọn (giữ tương lai): ~50MB/1 binary, gộp được search +
  extract, nhưng AGPL-3.0 + mới, chưa muốn phụ thuộc cho lõi.
- **Cloudflare Access / Service Token / mTLS trên host máy** — rejected: Hermes không gửi được
  header/cert client → 302/handshake fail → bot chết. Chỉ dùng được cho host người-dùng.
- **Tavily/Exa/Parallel (managed)** — vẫn là escape-hatch (switching ≈ 0, đổi env), nghịch privacy nên
  không phải mặc định.

## Consequences

**Better:**
- Có `web_extract` (Firecrawl) — Hermes đọc được nội dung 1 URL, không chỉ search.
- Backends cô lập trên VM riêng → không tải home server, không phụ thuộc NetBird trên phone.
- Reachable từ Hermes **ở bất kỳ đâu** (phone hoặc docker home) qua HTTPS công khai; hưởng
  DDoS/anycast/WAF của Cloudflare; origin IP ẩn sau tunnel.

**Worse:**
- **Lộ ra internet** → bề mặt tấn công thật (giảm thiểu = tunnel-only + auth + WAF, nhưng vẫn > NetBird).
- Auth tầng app là **cổng duy nhất** cho client-máy (không SSO): rò Basic-auth pass hoặc Bearer = ai
  cũng dùng được backend → phải secret mạnh + rotate + WAF rate-limit.
- Firecrawl **nặng** (6 service + Chromium) → VM cần RAM/đĩa kha khá (đề xuất ≥4GB RAM, ≥2 vCPU).
- Thêm secrets phải quản: Basic-auth pass, Firecrawl bearer, Cloudflare tunnel token.
- **Ingress cloudflared ở dashboard (token mode), KHÔNG trong repo** → lệch docs-as-code: mapping
  hostname→service không version-control, phải tự ghi lại (README) + audit trên dashboard. (Đổi lấy
  setup đơn giản, không quản creds-file/UUID.)

**Must now be true:**
- **Không service nào có `ports:` ra host** (đều chỉ trong net `tz-edge`); **cloudflared là đường vào
  duy nhất**, gọi `tz-nginx:80` qua docker DNS; VM không mở inbound port (verify bằng scan từ ngoài =
  closed, và `docker ps` không cột PORTS map ra host).
- Basic-auth password + Firecrawl bearer = random mạnh, để trong `.env`/secret **không commit**; nginx
  dùng file `.htpasswd` (bcrypt) — password thật ngoài repo.
- `FIRECRAWL_API_KEY` ở **cả hai** `.env` (Jarvis + Friday); `SEARXNG_URL` dạng `user:pass@` ở cả hai;
  không commit.
- Vì SearXNG `limiter: false` mà nay public → **rate-limit phải đặt ở nginx/Cloudflare WAF** (không còn
  NetBird che).
- **Không** đặt Cloudflare Access lên `search.*`/`crawl.*`.
- Friday vẫn không có terminal/code_execution/file/browser/memory/device (kiểm `hermes -p friday tools`).

## Revisit if

- Muốn private hoàn toàn trở lại / bỏ public → quay về NetBird (ADR cũ) hoặc đặt VM vào mesh.
- `crw` đủ chín → thay Firecrawl (nhẹ hơn nhiều, gộp search) bằng đổi `FIRECRAWL_API_URL`.
- Hermes thêm provider-fallback → SearXNG primary + managed dự phòng.
- Firecrawl quá nặng cho VM → cân nhắc `crw` hoặc chỉ chạy api+worker+redis tối thiểu.
