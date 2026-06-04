# Web backends (SearXNG + Firecrawl) trên VM riêng, public qua Cloudflare Tunnel

**Status:** active
**Created:** 2026-06-04
**Owner:** liamlee

## Goal

Hermes (Jarvis + Friday) có **cả `web_search` lẫn `web_extract`** qua backend self-host trên **một VM
riêng ngoài NetBird**, expose ra internet bằng **Cloudflare Tunnel**, bảo vệ bằng **auth tầng app** (Basic
auth cho SearXNG, Bearer cho Firecrawl) — vì client Hermes không gửi được header nên Cloudflare Access
không dùng được trên endpoint máy. Done tổng thể: hỏi Jarvis và Friday một câu cần search → trả lời có
nguồn từ SearXNG; đưa 1 URL → đọc được nội dung qua Firecrawl; VM không mở inbound port; gọi backend không
kèm credential → 401.

## Background

ADR [`web-backends-public-vm.md`](../../design-docs/web-backends-public-vm.md) (Context/Decision/
Alternatives/Consequences/Revisit). Sự thật cốt lõi (đọc source `plugins/web/`):
(a) `searxng` chỉ search; `web_extract` self-host ⇒ **`firecrawl`** (Hermes không có `crawl4ai`).
(b) `searxng/provider.py` chỉ nhận `SEARXNG_URL`, không header — **nhưng httpx hiểu `user:pass@host`**.
(c) `firecrawl/provider.py` gửi `Authorization: Bearer` + nhận `FIRECRAWL_API_URL` self-host.
(d) ⇒ **Cloudflare Access phá client-máy** (cần browser/header) → auth phải ở tầng app bằng credential
Hermes gửi được. (e) Firecrawl self-host `USE_DB_AUTHENTICATION=false` = **không tự check key** → bearer
enforcement nằm ở **Caddy**, không ở Firecrawl.

Supersedes phần vận chuyển của [search-backend-searxng.md](../../design-docs/search-backend-searxng.md)
(NetBird → public VM). Engine-mix chống-429, `limiter:false`, `formats:[json]` giữ nguyên.

## Tasks

> 📦 Amendment 2026-06-04: W3–W6 gộp thành **1 folder deploy duy nhất** `tz-web-backends/` (clone lên VM
> → `docker compose up`), KHÔNG tách `searxng/`+`firecrawl/`+`nginx/`+`cloudflared/` rời. Firecrawl dùng
> **image GHCR** (`ghcr.io/firecrawl/{firecrawl,playwright-service,nuq-postgres}`) — KHÔNG build source.
> **Repo files của W3–W6 đã viết xong + `docker compose config` pass**; còn lại = deploy + verify TRÊN VM.
> Folder cũ `searxng/` (NetBird) đã xoá (untracked, bị thay thế; live secret_key discard — regen trên VM).
> Cấu trúc: `tz-web-backends/{docker-compose.yml, .env.example, .gitignore, README.md, searxng/
> settings.yml.example, nginx/templates/web.conf.template, nginx/.htpasswd.example}`. cloudflared =
> token mode (ingress trên dashboard, không file repo). Chống đụng tên: chỉ `tz-*` trên net chung
> `tz-edge`; nội bộ Firecrawl/valkey ở net private (`backend`/`searxng-net`).

- [ ] W1 — ADR + exec plan
  - Done when: ADR `docs/design-docs/web-backends-public-vm.md` + plan này tồn tại, link nhau; ADR cũ
    `search-backend-searxng.md` được annotate "superseded-in-part".

- [ ] W2 — VM prerequisites
  - Done when: VM (≥4GB RAM, ≥2 vCPU, ≥20GB đĩa) chạy `docker` + `docker compose` (v2) và `cloudflared`
    cài đặt; ghi spec + OS vào README. **Firewall mặc định deny inbound** (chỉ SSH nếu cần, tốt nhất qua
    Cloudflare/NetBird admin).
  - Verify: `docker compose version`, `cloudflared --version` chạy trên VM.

- [ ] W3 — Docker network chung `tz-edge` + SearXNG bỏ publish port
  - Done when: tạo external network `tz-edge`; `searxng/docker-compose.yml` **gỡ** bind
    `100.97.17.10:8888:8080` (không publish port host nào), join `tz-edge`, đổi container name
    `hermes-searxng`→`tz-searxng`, `hermes-searxng-valkey`→`tz-searxng-valkey`, project `name:` →
    `tz-searxng`; `SEARXNG_BASE_URL` → `https://search.timezlab.org/`. Giữ `settings.yml.example`
    (`limiter:false`, `formats:[html,json]`, engine-mix). README cập nhật (không còn NetBird-only).
  - Files: `tz-web-backends/{docker-compose.yml, searxng/settings.yml.example, README.md}` (live
    `searxng/settings.yml` regenerate trên VM)
  - Verify (trên VM): từ 1 container cùng net, `curl 'http://tz-searxng:8080/search?q=test&format=json'`
    có results; từ host `curl 127.0.0.1` → **không có port nào** (refused).

- [ ] W4 — Firecrawl self-host compose
  - Done when: `firecrawl/docker-compose.yml` chạy stack (`tz-firecrawl-api`, `-worker`, `-playwright`,
    `-redis`, `-rabbitmq`, `-nuq-postgres`) dùng image `ghcr.io/firecrawl/firecrawl` +
    `ghcr.io/firecrawl/playwright-service`; env `USE_DB_AUTHENTICATION=false`, `PORT=3002`,
    `HOST=0.0.0.0`, `PLAYWRIGHT_MICROSERVICE_URL`, `BULL_AUTH_KEY`; join `tz-edge`; **không publish
    host port** (nginx gọi `http://tz-firecrawl-api:3002`). `.env.example` commit (placeholder), live
    `.env` gitignore.
  - Files: `firecrawl/docker-compose.yml`, `firecrawl/.env.example`, `firecrawl/README.md`
  - Verify (trên VM, từ container cùng net): `curl -XPOST http://tz-firecrawl-api:3002/v1/scrape
    -H 'Content-Type: application/json' -d '{"url":"https://example.com"}'` trả markdown/HTML.

- [ ] W5 — nginx (container `tz-nginx`, KHÔNG publish port, vhost theo Host) + auth
  - Done when: `nginx/` (compose + conf), container `tz-nginx`, chỉ `expose: [80]` TRONG net
    `tz-edge`, **không** `ports:` ra host. `server_name search.timezlab.org` → `auth_basic` +
    `.htpasswd` (bcrypt; password thật KHÔNG trong repo) → `proxy_pass http://tz-searxng:8080`.
    `server_name crawl.timezlab.org` → `map $http_authorization` khớp `Bearer <key>` (else
    `return 401`) → `proxy_pass http://tz-firecrawl-api:3002`. Default server (Host lạ) → 444.
    `.htpasswd` + key ngoài repo (`.htpasswd` gitignore, có `.htpasswd.example`).
  - Files: `nginx/docker-compose.yml`, `nginx/nginx.conf` (hoặc `conf.d/web.conf`), `nginx/.htpasswd.example`
  - Verify (trên VM, từ container cùng net, vd `docker run --rm --network tz-edge curlimages/curl`):
    `curl -H 'Host: search.timezlab.org' -u u:p 'http://tz-nginx/search?q=x&format=json'` → JSON;
    thiếu `-u` → 401. `crawl.timezlab.org` + `Authorization: Bearer <key>` → scrape; thiếu → 401.
    `docker ps` xác nhận `tz-nginx` **không** có PORTS map ra host.

- [ ] W6 — Cloudflare Tunnel (token mode, ingress trên dashboard)
  - Done when: container `tz-cloudflared` join `tz-edge`, `tunnel --no-autoupdate run` với
    `TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}`; **trên dashboard CF** (Zero Trust → Tunnels → Public
    Hostname): `search.timezlab.org` **và** `crawl.timezlab.org` → Service `http://tz-nginx:80` (DNS
    record CF tự tạo). **KHÔNG Cloudflare Access trên 2 host này.** Token ở `.env` VM (không commit).
  - Files: trong `tz-web-backends/docker-compose.yml` (service `tz-cloudflared`) + `.env.example`
    (`CLOUDFLARE_TUNNEL_TOKEN`). Ingress = dashboard (ghi lại trong README, không có file repo).
  - Verify: từ máy ngoài, `https://search.timezlab.org/search?q=x&format=json` với Basic-auth → JSON;
    `https://crawl.timezlab.org/v1/scrape` với Bearer → kết quả. Scan port VM từ ngoài → **không
    inbound nào open**; `docker ps` toàn stack → **không container nào** có cột PORTS map ra host.

- [ ] W7 — Defense-in-depth: WAF rate-limit + (tùy chọn) admin host
  - Done when: Cloudflare WAF rate-limit rule trên `search.*`/`crawl.*` (chặn brute-force Basic-auth/
    bearer) + (tùy chọn) geo-block ngoài VN. (Tùy chọn) host `admin.timezlab.org` có Cloudflare Access
    (email SSO) cho SearXNG prefs / Firecrawl playground — **Hermes không dùng host này**.
  - Verify: spam request không kèm cred → bị rate-limit; Hermes (trong ngưỡng) không bị chặn.

- [ ] W8 — Hermes config + env (config-as-code, cả 2 profile)
  - Done when: `hermes/home/config.yaml` + `hermes/profiles/friday/config.yaml` có
    `web: {search_backend: searxng, extract_backend: firecrawl}`. `hermes/.env.example` đổi
    `SEARXNG_URL` sang dạng `https://<user>:<pass>@search.timezlab.org`, thêm
    `FIRECRAWL_API_URL=https://crawl.timezlab.org` + `FIRECRAWL_API_KEY=<bearer>`; ghi rõ đặt ở **cả**
    `~/.hermes/.env` (Jarvis) và `~/.hermes/profiles/friday/.env` (Friday). Friday `disabled_toolsets`
    vẫn chặn terminal/code_execution/file/browser/memory/device.
  - Files: `hermes/home/config.yaml`, `hermes/profiles/friday/config.yaml`, `hermes/.env.example`
  - ⚠️ Firecrawl SDK lazy-import; trên Termux `allow_lazy_installs:false` → `pip install firecrawl-py`
    tay vào venv Hermes (nếu Hermes vẫn chạy trên phone). Nếu Hermes chạy docker home thì lazy ok.

- [ ] W9 — Verify end-to-end + docs freshness
  - Done when: trong group, Friday @mention câu hỏi cần search → trả lời có nguồn; DM Jarvis 1 URL →
    đọc nội dung (web_extract); `hermes -p friday tools` xác nhận không có tool nhạy cảm. Grep docs/code
    không còn ref "SearXNG chỉ NetBird / `100.97.17.10:8888`" ngoài chỗ lịch sử có chủ đích; memory
    `hermes-gateway.md` cập nhật (Firecrawl extract + auth public-VM).
  - Verify: 2 bot trả lời search + 1 bot đọc URL; scan port VM clean; pre-commit hook pass.

## Decisions log

- 2026-06-04 — Chọn **SearXNG + Firecrawl** (không Crawl4AI: Hermes không có provider, API không tương
  thích; không crw lần này: AGPL + mới). Backends rời NetBird → VM riêng + Cloudflare Tunnel. Auth tầng
  app: Basic auth (SearXNG, qua `user:pass@` URL) + Bearer (Firecrawl, qua SDK). Cloudflare Access chỉ
  cho host người-dùng. Nguồn: đọc `plugins/web/{searxng,firecrawl}/provider.py`.
- 2026-06-04 — Reverse proxy = **nginx**, route theo `server_name` (Host); Bearer check bằng
  `map $http_authorization`. (Cân nhắc Caddy/Traefik → chọn nginx: quen + nhẹ; TLS đã ở Cloudflare
  nên không cần auto-HTTPS của Caddy.)
- 2026-06-04 — **KHÔNG service nào publish port ra host** (kể cả localhost). cloudflared chạy như
  **container `tz-cloudflared` trong net `tz-edge`**, gọi `http://tz-nginx:80` qua docker DNS →
  cloudflared là đường vào duy nhất, VM zero inbound port.
- 2026-06-04 — Namespace container/network = **`tz-`** (org timezlab), KHÔNG prefix consumer "hermes":
  VM là host dùng chung, tái sử dụng cho service khác → tên theo org tránh đụng container có sẵn. Tên
  trần (`nginx`/`searxng`) dễ trùng nên loại. (Đảo prefix `hermes-` của ADR SearXNG cũ — context khác:
  hồi đó deploy riêng cho hermes trên home server.)

## Open questions

- Hermes chạy ở đâu khi xong (phone Termux như hiện tại, hay pivot sang docker home)? Không đổi thiết kế
  VM backend (Hermes gọi URL public theo cả 2 cách) nhưng đổi bước cài `firecrawl-py` (W8) và nơi đặt
  `.env`. Quyết định ở pivot riêng, không chặn plan này.
- VM cụ thể: provider/OS/IP — điền vào W2 khi có.
