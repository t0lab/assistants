# Search backend cho Hermes: SearXNG self-host qua NetBird

**Status:** superseded-in-part (2026-06-04) — phần *vận chuyển/biên bảo mật* (NetBird, bind IP mesh,
no app-auth) bị thay bởi [web-backends-public-vm.md](./web-backends-public-vm.md): SearXNG chuyển sang
VM riêng, public qua Cloudflare Tunnel + Basic auth. Phần *chọn SearXNG làm search backend*, engine-mix
chống-429, `limiter: false`, `formats: [json]` **vẫn còn hiệu lực**.
**Date:** 2026-06-01

## Context

Toolset `web` của Hermes (`web_search` + `web_extract`) **không có search keyless built-in** — bắt
buộc cấu hình một provider, nếu không tool bị drop lúc runtime (bật trong `hermes tools` nhưng không
xuất hiện trong session → model fallback sang `code_execution` để tự fetch, còn Friday đã tắt
`code_execution` nên group mù web hoàn toàn).

Provider Hermes hỗ trợ (env var): `TAVILY_API_KEY`, `EXA_API_KEY`, `PARALLEL_API_KEY` (managed, có
key), `SEARXNG_URL` (self-host, keyless), `FIRECRAWL_API_KEY` (extract). Nous Portal paid sub thì đi
qua Tool Gateway khỏi key — không áp dụng.

Yêu cầu: ưu tiên **privacy** (query không rời hạ tầng của user). Ràng buộc: home server **không
export port** ra internet; user từng bị **429/ban IP** (Google News, DuckDuckGo) trên một VM cũ.

Sự thật quyết định thiết kế:
1. SearXNG là **meta-search proxy** (không index) → nhẹ (~200–300MB RAM, 0 GPU); chạy trên home
   server (31GB RAM, 88 core) là phụ tải không đáng kể.
2. Client **duy nhất** là Hermes trên phone (máy-gọi-máy), và phone + home server **đã cùng mesh
   NetBird** (`100.97.86.95` ↔ `100.97.17.10`, `/16`). → Không cần expose ra internet.
3. **Cloudflare Access không hợp cho client-máy:** nó là SSO browser; Hermes (chỉ nhận `SEARXNG_URL`,
   không set custom header) không qua được. Service Token cần header → không cấu hình được; basic-auth
   nhét URL thì lại phải mở public → thêm bề mặt tấn công.
4. **429 phụ thuộc IP outbound + engine mix:** IP datacenter (case VM cũ) bị ban nhanh; **residential
   ISP (home server) khoan dung hơn nhiều**. SearXNG gộp nhiều engine → 1 engine 429 vẫn còn cái khác.
5. **Limiter của SearXNG chặn `format=json`** (bot-detection) → với client-máy phải **tắt limiter**;
   an toàn vì instance private qua NetBird.

## Decision

**SearXNG self-host trên home server, truy cập riêng tư qua NetBird, không expose internet, không
auth tầng app** (NetBird mesh là biên bảo mật).

1. **Compose** `searxng/docker-compose.yml`: `hermes-searxng` + `hermes-searxng-valkey` (namespace
   `hermes-search` tránh đụng SearXNG khác). Bind port **chỉ vào IP NetBird** `100.97.17.10:8888`
   (không 0.0.0.0) → localhost/LAN/internet không tới được (verified).
2. **Settings config-as-code:** `searxng/settings.yml.example` commit (template), live `settings.yml`
   (có `secret_key`) **gitignore**. Bắt buộc `search.formats: [html, json]`; `server.limiter: false`.
3. **Engine mix chống-429:** tắt `google` + `duckduckgo` + `brave` (hay ban/hard-429); bật
   `bing, mojeek, qwant, startpage, wikipedia` (verified 2026-06-01: 38 results, unresponsive rỗng).
4. **Phone:** `SEARXNG_URL=http://100.97.17.10:8888` trong **cả** `~/.hermes/.env` (Jarvis) và
   `~/.hermes/profiles/friday/.env` (Friday) — không commit (đã trong `.env.example`).
5. **Toolset `web` phải được bật** per-platform qua `hermes tools` (cả default lẫn friday) — provider
   key/URL không tự bật toolset.

## Alternatives considered

- **Tavily/Exa/Parallel (managed API)** — rejected (mặc định): query qua bên thứ 3, nghịch privacy.
  Nhưng **switching cost ≈ 0** (đổi `SEARXNG_URL`→`TAVILY_API_KEY`, restart) → giữ làm escape-hatch
  nếu 429 quá nhiều.
- **Cloudflare Tunnel + Access/Service-Token/basic-auth** — rejected: client-máy không qua SSO được;
  các cách cho máy qua đều phải mở public + thêm bề mặt tấn công. NetBird sạch hơn mọi mặt.
- **SearXNG + Tor (`using_tor_proxy`)** — rejected: exit node Tor bị engine chặn/captcha còn nặng hơn.
- **Bỏ web, để model tự fetch bằng `code_execution`** — rejected: không phải search engine thật; và
  Friday đã tắt `code_execution`.

## Consequences

**Better:**
- Query **không rời nhà** (privacy-first); không phụ thuộc/không trả phí bên thứ 3.
- Không expose gì ra internet; biên bảo mật = NetBird (WireGuard peer-auth), không thêm secret/auth.
- Nhẹ, GPU nhàn; cả Jarvis + Friday dùng chung 1 backend.

**Worse:**
- Thêm **dependency vận hành**: nếu home server / NetBird trên phone down → search fail (graceful: chỉ
  mất web, không crash bot).
- **429/engine-ban vẫn có thể xảy ra** dù IP residential → phải bảo trì engine mix (theo dõi
  `unresponsive_engines`).
- Phải nhớ **bật toolset `web`** sau mỗi lần nâng cấp Hermes (re-audit `hermes tools`).

**Must now be true:**
- Port SearXNG **chỉ** bind IP NetBird, **không bao giờ** 0.0.0.0/public.
- `secret_key` (live `settings.yml`) **không commit**.
- `SEARXNG_URL` set ở **cả hai** `.env` (Jarvis + Friday); không commit.
- `search.formats` phải gồm `json`; `limiter: false` (nếu sau này mở ra ngoài mesh thì phải dựng lại
  auth + bật limiter có cấu hình cho phép API).

## Revisit if

- 429 quá nhiều dù đã tối ưu engine mix → chuyển sang Tavily (escape-hatch, đổi 1 env var).
- Cần search từ client **ngoài mesh** (không phải phone) → lúc đó mới cân nhắc expose + auth.
- Hermes thêm cơ chế provider-fallback → có thể cắm SearXNG primary + managed API dự phòng.
