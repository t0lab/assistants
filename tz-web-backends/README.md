# tz-web-backends

Web **search (SearXNG)** + **extract (Firecrawl)** self-host cho Hermes, đặt trên **một VM dùng chung**
ngoài NetBird, public qua **Cloudflare Tunnel**, auth ở **tz-nginx** (Basic auth cho SearXNG, Bearer cho
Firecrawl). **Không service nào publish port ra host** — cloudflared là đường vào duy nhất.

Quyết định + lý do: ADR [`../docs/design-docs/web-backends-public-vm.md`](../docs/design-docs/web-backends-public-vm.md).
Tiến độ/việc: [`../docs/exec-plans/active/web-backends-public-vm.md`](../docs/exec-plans/active/web-backends-public-vm.md).

## Kiến trúc

```
Hermes ─ SEARXNG_URL=https://hermes:<pass>@search.timezlab.org  (Basic) ─┐
       ─ FIRECRAWL_API_URL=https://crawl.timezlab.org +Bearer ───────────┤  Cloudflare (WAF) + Tunnel
                                                                          ▼
VM (KHÔNG publish port nào):  docker net tz-edge
  tz-cloudflared ─► http://tz-nginx:80  (Host giữ nguyên)
  tz-nginx ┬─ server_name search.* → Basic auth (.htpasswd) → http://tz-searxng:8080
           └─ server_name crawl.*  → map Bearer (else 401)  → http://tz-firecrawl-api:3002
  (private) searxng-net: tz-searxng ↔ searxng-valkey
  (private) backend:     tz-firecrawl-api ↔ redis / rabbitmq / nuq-postgres / playwright
```

Chỉ tên `tz-*` lên mạng chung `tz-edge`; service nội bộ ở mạng private → tái dùng VM cho stack khác
không đụng tên.

## Yêu cầu VM

- Docker + `docker compose` v2; `openssl` (sinh secret). Khuyến nghị **≥8GB RAM / 4 vCPU** (Firecrawl
  api+playwright nặng); 4GB chạy được nhưng chật.
- **Firewall deny inbound** (cloudflared chỉ cần outbound). Cloudflare account + domain `timezlab.org`.

## Deploy (clone-and-up)

```bash
git clone <repo> && cd <repo>/tz-web-backends

# 1) Mạng chung (1 lần / VM)
docker network create tz-edge

# 2) Secrets
cp .env.example .env
#   FIRECRAWL_BEARER = openssl rand -hex 32   (== FIRECRAWL_API_KEY của Hermes)
#   POSTGRES_PASSWORD, BULL_AUTH_KEY = openssl rand -hex 16
nano .env

# 3) SearXNG secret_key
cp searxng/settings.yml.example searxng/settings.yml
sed -i "s/__SECRET_KEY__/$(openssl rand -hex 32)/" searxng/settings.yml

# 4) Basic auth cho SearXNG (user 'hermes')
docker run --rm httpd:alpine htpasswd -nbB hermes '<password-mạnh>' > nginx/.htpasswd

# 5) Cloudflare Tunnel (token mode — ingress cấu hình trên DASHBOARD)
#   Dashboard → Zero Trust → Networks → Tunnels → Create tunnel (tên tz-web) → copy TOKEN
#   → dán vào CLOUDFLARE_TUNNEL_TOKEN trong .env.
#   Trong tunnel đó, thêm Public Hostname:
#     search.timezlab.org → Service: HTTP → URL: tz-nginx:80
#     crawl.timezlab.org  → Service: HTTP → URL: tz-nginx:80
#   (cloudflared ở net tz-edge nên resolve được tz-nginx; DNS record CF tự tạo khi add hostname.)

# 6) Lên
docker compose up -d
docker compose ps          # tz-* đều up; rabbitmq healthy; KHÔNG cột PORTS nào map ra host
```

## Verify

```bash
# Trong mạng (trước khi qua Cloudflare). ⚠️ PHẢI gửi Host header đúng — nginx route theo server_name;
# thiếu Host → trúng default_server → 444. (cloudflared giữ nguyên Host nên thật sự không cần ở prod.)
docker run --rm --network tz-edge curlimages/curl -s -H 'Host: search.timezlab.org' \
  -u hermes:<password> 'http://tz-nginx/search?q=test&format=json' | head -c 300       # JSON results
docker run --rm --network tz-edge curlimages/curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: search.timezlab.org' 'http://tz-nginx/search?q=test&format=json'           # 401 (thiếu auth)
docker run --rm --network tz-edge curlimages/curl -s -XPOST -H 'Host: crawl.timezlab.org' \
  -H "Authorization: Bearer <FIRECRAWL_BEARER>" -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com"}' 'http://tz-nginx/v1/scrape' | head -c 300         # success+markdown

# Public (qua Cloudflare):
curl -s -u hermes:<password> 'https://search.timezlab.org/search?q=test&format=json' | head -c 300
curl -s -XPOST 'https://crawl.timezlab.org/v1/scrape' \
  -H "Authorization: Bearer <FIRECRAWL_BEARER>" -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com"}' | head -c 300

# An toàn: scan VM từ ngoài → KHÔNG inbound port nào open.
```

## Nối vào Hermes

Trong **cả** `~/.hermes/.env` (Jarvis) và `~/.hermes/profiles/friday/.env` (Friday):

```
SEARXNG_URL=https://hermes:<password>@search.timezlab.org
FIRECRAWL_API_URL=https://crawl.timezlab.org
FIRECRAWL_API_KEY=<FIRECRAWL_BEARER>     # TRÙNG với nginx
```

`config.yaml` đã có `web: {search_backend: searxng, extract_backend: firecrawl}`. Bật toolset `web`
per-platform (`hermes tools`). Nếu Hermes chạy trên Termux (`allow_lazy_installs:false`):
`pip install firecrawl-py` vào venv Hermes.

## Vận hành

```bash
docker compose ps
docker logs tz-searxng --tail 30          # lỗi engine onion (ahmia/torch) vô hại
docker compose restart tz-searxng         # nạp lại settings.yml
docker logs tz-firecrawl-api --tail 50
docker compose pull && docker compose up -d   # nâng cấp image
```

Gặp 429 ở SearXNG: sửa `disabled:` trong `searxng/settings.yml` → restart tz-searxng; đồng bộ lại
`settings.yml.example`. Đổi sang managed API (Tavily): đổi env Hermes (`SEARXNG_URL`→`TAVILY_API_KEY`),
switching cost ≈ 0.
