FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV PYTHONUNBUFFERED=1
ENV ROOT_PASSWORD=ELMINYAWE
ENV LANG=en_US.UTF-8

# ================================================================
# 1) CRITICAL FIX: Install & update CA certificates FIRST
# ================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates openssl \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ================================================================
# 2) Base packages (FIXED: libncurses-dev instead of libncursesw5-dev)
# ================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git build-essential cmake libssl-dev \
    libtool libev-dev libc-ares-dev libmbedtls-dev \
    libsodium-dev libpcre2-dev automake pkg-config \
    nginx supervisor openssh-server net-tools jq \
    iproute2 iputils-ping dnsutils htop vim nano \
    libwebsockets-dev libjson-c-dev zlib1g-dev \
    unzip libbz2-dev libncurses-dev libffi-dev \
    libreadline-dev libsqlite3-dev liblzma-dev \
    gnupg lsb-release software-properties-common \
    locales tzdata cron bash-completion man-db \
    less file passwd openssh-client sqlite3 \
    tk-dev libxml2-dev libxmlsec1-dev xz-utils \
    shadowsocks-libev \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ================================================================
# 3) SSH Setup — hardened & complete
# ================================================================
RUN mkdir -p /var/run/sshd /run/sshd && \
    sed -i 's/^#*\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*\s*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*\s*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#*\s*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*\s*X11Forwarding.*/X11Forwarding yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*\s*PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config && \
    sed -i 's/^#*\s*AcceptEnv.*/AcceptEnv LANG LC_*/' /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# ================================================================
# 4) Self-signed SSL certificate — RSA-4096 (stronger)
# ================================================================
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=ELMINYAWE/CN=localhost" && \
    chmod 600 /etc/nginx/ssl/key.pem && \
    chmod 644 /etc/nginx/ssl/cert.pem

# ================================================================
# 5) pyenv + Python 3.13 — FIXED with fallback
# ================================================================
ENV PYENV_ROOT=/root/.pyenv
ENV PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"

RUN set -e; \
    if curl -fsSL https://pyenv.run | bash; then \
        echo "[OK] pyenv installed via pyenv.run"; \
    else \
        echo "[WARN] pyenv.run failed, installing manually..."; \
        git clone https://github.com/pyenv/pyenv.git /root/.pyenv && \
        git clone https://github.com/pyenv/pyenv-virtualenv.git /root/.pyenv/plugins/pyenv-virtualenv && \
        git clone https://github.com/pyenv/pyenv-update.git /root/.pyenv/plugins/pyenv-update; \
    fi && \
    eval "$(pyenv init -)" && \
    pyenv install 3.13.0 && \
    pyenv global 3.13.0 && \
    pip install --upgrade pip flask requests psutil

# ================================================================
# 6) ttyd — prebuilt binary (much faster & reliable)
# ================================================================
RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in \
        amd64) t=x86_64;; \
        arm64) t=aarch64;; \
        *) t="$arch";; \
    esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# ================================================================
# 7) Xray-core — FIXED: use -fsSL instead of insecure -Lk
# ================================================================
RUN XRAY_VERSION="v26.3.27" && \
    cd /tmp && \
    curl -fsSL -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" && \
    unzip -o xray.zip -d /usr/local/bin/ && \
    mv /usr/local/bin/xray /usr/local/bin/xray-binary 2>/dev/null || true && \
    mv /usr/local/bin/Xray-linux-64/xray /usr/local/bin/xray 2>/dev/null || true && \
    chmod +x /usr/local/bin/xray && \
    mkdir -p /usr/local/share/xray /usr/local/etc/xray /var/log/xray /etc/xray /usr/share/xray && \
    curl -fsSL -o /usr/local/share/xray/geoip.dat "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" && \
    curl -fsSL -o /usr/local/share/xray/geosite.dat "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" && \
    mv /usr/local/share/xray/dlc.dat /usr/local/share/xray/geosite.dat 2>/dev/null || true && \
    ln -sf /usr/local/share/xray/geoip.dat /usr/share/xray/geoip.dat && \
    ln -sf /usr/local/share/xray/geosite.dat /usr/share/xray/geosite.dat && \
    rm -rf /tmp/xray.zip /tmp/Xray-linux-64*

# ================================================================
# 8) 3proxy
# ================================================================
RUN git clone https://github.com/z3APA3A/3proxy.git /tmp/3proxy && \
    cd /tmp/3proxy && \
    make -f Makefile.Linux && \
    mkdir -p /usr/local/3proxy/bin && \
    cp bin/3proxy /usr/local/3proxy/bin/ && \
    cp bin/3proxy_proxy /usr/local/3proxy/bin/proxy 2>/dev/null || true && \
    cp bin/3proxy_socks /usr/local/3proxy/bin/socks 2>/dev/null || true && \
    rm -rf /tmp/3proxy

# ================================================================
# 9) badvpn-udpgw
# ================================================================
RUN git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn && \
    cd /tmp/badvpn && mkdir build && cd build && \
    cmake .. -DBUILD_UDPGW=1 && make -j$(nproc) && \
    cp udpgw/badvpn-udpgw /usr/local/bin/ && \
    rm -rf /tmp/badvpn

# ================================================================
# 10) cloudflared — FIXED: use -fsSL
# ================================================================
RUN curl -fsSL --output /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" && \
    chmod +x /usr/local/bin/cloudflared

# ================================================================
# 11) PufferPanel
# ================================================================
RUN curl -fsSL https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | bash && \
    apt-get install -y --no-install-recommends pufferpanel && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/lib/pufferpanel/email /var/lib/pufferpanel/servers /etc/pufferpanel /var/log/pufferpanel && \
    echo '{}' > /var/lib/pufferpanel/email/emails.json

RUN cat > /etc/pufferpanel/config.json << 'PPEOF'
{
    "panel": {
        "web": {
            "listen": "0.0.0.0:8080",
            "files": "/var/www/pufferpanel"
        },
        "database": {
            "dialect": "sqlite3",
            "url": "file:/var/lib/pufferpanel/pufferpanel.db?cache=shared&mode=rwc"
        }
    },
    "daemon": {
        "sftp": {
            "port": 5657
        }
    }
}
PPEOF
RUN cp /etc/pufferpanel/config.json /var/lib/pufferpanel/config.json

# ================================================================
# 12) Config directories
# ================================================================
RUN mkdir -p /etc/3proxy /app /var/log/supervisor /tmp/cf

# ================================================================
# 13) Xray config template
# ================================================================
RUN cat > /etc/xray/config.json << 'XRAYEOF'
{
    "log": { "access": "/dev/stdout", "error": "/dev/stderr", "loglevel": "warning" },
    "inbounds": [
        {
            "port": 10086, "protocol": "vmess",
            "settings": { "clients": [{ "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "alterId": 0 }] },
            "streamSettings": { "network": "ws", "wsSettings": { "path": "/v2ray" } }
        },
        {
            "port": 10087, "protocol": "vless",
            "settings": { "clients": [{ "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901" }], "decryption": "none" },
            "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
        },
        {
            "port": 10088, "protocol": "trojan",
            "settings": { "clients": [{ "password": "ELMINYAWE" }] },
            "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } }
        },
        {
            "listen": "0.0.0.0", "port": 8443, "protocol": "vless",
            "settings": { "clients": [{ "id": "c3d4e5f6-a7b8-9012-cdef-123456789012", "flow": "xtls-rprx-vision" }], "decryption": "none" },
            "streamSettings": {
                "network": "tcp", "security": "reality",
                "realitySettings": {
                    "dest": "www.microsoft.com:443",
                    "serverNames": ["www.eand.com.eg", "eandbusiness.com.eg"],
                    "privateKey": "__REALITY_PRIVATE_KEY__",
                    "shortIds": ["abcd12", "ef34"]
                }
            }
        }
    ],
    "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
XRAYEOF

# ================================================================
# 14) Shadowsocks config
# ================================================================
RUN cat > /etc/shadowsocks-libev/config.json << 'SSEOF'
{
    "server": "0.0.0.0", "server_port": 8388,
    "password": "ELMINYAWE", "method": "aes-256-gcm",
    "timeout": 300, "fast_open": true
}
SSEOF

# ================================================================
# 15) Nginx — ENHANCED SSL/TLS (TLS 1.2/1.3, HTTP/2, strong ciphers)
# ================================================================
RUN cat > /etc/nginx/nginx.conf << 'NGEOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL hardening
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # TTYD / API / Proxy websockets on 9090
    server {
        listen 9090;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /v2ray {
            proxy_pass http://127.0.0.1:10086;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400;
        }

        location /vless {
            proxy_pass http://127.0.0.1:10087;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400;
        }

        location /trojan {
            proxy_pass http://127.0.0.1:10088;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400;
        }
    }

    # HTTPS 443 — SSL/TLS proxy to 3proxy HTTP
    server {
        listen 443 ssl http2 default_server;
        server_name _;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        location / {
            proxy_pass http://127.0.0.1:8118;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 300s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;
        }
    }

    # HTTP 80 -> redirect to HTTPS 443
    server {
        listen 80 default_server;
        server_name _;
        return 301 https://$host$request_uri;
    }
}
NGEOF

# ================================================================
# 16) Flask API
# ================================================================
RUN cat > /app/api.py << 'APIEOF'
import os, json, psutil, time, socket, subprocess, re
from flask import Flask, jsonify

app = Flask(__name__)

UUID_VMESS = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
UUID_VLESS = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
UUID_REALITY = "c3d4e5f6-a7b8-9012-cdef-123456789012"
PASS_TROJAN = "ELMINYAWE"
PASS_SS = "ELMINYAWE"

def read_cf_url(prefix):
    try:
        with open(f"/tmp/cf_{prefix}.log") as f:
            for line in f:
                m = re.search(r'(https?://[a-z0-9-]+\.trycloudflare\.com)', line)
                if m: return m.group(1)
    except:
        pass
    return None

def get_reality_keys():
    try:
        with open("/etc/xray/reality_keys.json") as f:
            return json.load(f)
    except:
        return {}

@app.route("/")
def index():
    return jsonify({"name": "ELMINYAWE SERVER", "version": "v3.0-ssl", "status": "running"})

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/system")
def system():
    boot = psutil.boot_time()
    return jsonify({
        "cpu_percent": psutil.cpu_percent(interval=1),
        "ram": psutil.virtual_memory()._asdict(),
        "disk": psutil.disk_usage('/')._asdict(),
        "boot_time": boot,
        "uptime": time.time() - boot
    })

@app.route("/services")
def services():
    procs = []
    for p in psutil.process_iter(['pid','name','cpu_percent','memory_percent']):
        try: procs.append(p.info)
        except: pass
    procs.sort(key=lambda x: x.get('memory_percent',0), reverse=True)
    return jsonify(procs[:50])

@app.route("/proxy-info")
def proxy_info():
    return jsonify({
        "ssh": {"host": "0.0.0.0", "port": 22, "user": "root"},
        "https_proxy": {"host": "0.0.0.0", "port": 443, "type": "tls", "backend": 8118},
        "http_redirect": {"host": "0.0.0.0", "port": 80, "type": "redirect"},
        "socks5": {"host": "0.0.0.0", "port": 1080},
        "http": {"host": "0.0.0.0", "port": 8118},
        "shadowsocks": {"port": 8388, "method": "aes-256-gcm", "password": PASS_SS}
    })

@app.route("/inf")
def inf():
    domain = os.environ.get("CUSTOM_DOMAIN")
    cf_urls = {}
    for svc in ["ttyd","api","v2ray","vless","trojan","nginx"]:
        u = read_cf_url(svc)
        if u: cf_urls[svc] = u
    reality = get_reality_keys()
    if domain:
        links = {
            "ttyd": f"https://ttyd.{domain}",
            "api": f"https://api.{domain}",
            "vmess": f"https://vmess.{domain}",
            "vless": f"https://vless.{domain}",
            "trojan": f"https://trojan.{domain}",
            "panel": f"https://panel.{domain}"
        }
    else:
        links = cf_urls
    return jsonify({
        "server": "ELMINYAWE",
        "version": "v3.0-ssl",
        "custom_domain": domain,
        "cloudflare_urls": cf_urls,
        "links": links,
        "uuids": {"vmess": UUID_VMESS, "vless": UUID_VLESS, "reality": UUID_REALITY},
        "passwords": {"trojan": PASS_TROJAN, "shadowsocks": PASS_SS},
        "sni": domain or "trycloudflare.com",
        "reality": reality,
        "system": {
            "cpu": psutil.cpu_percent(),
            "ram": dict(psutil.virtual_memory()._asdict()),
            "disk": dict(psutil.disk_usage('/')._asdict())
        }
    })

@app.route("/speedtest")
def speedtest():
    try:
        import speedtest as st
        s = st.Speedtest()
        s.get_best_server()
        dl = s.download() / 1_000_000
        ul = s.upload() / 1_000_000
        return jsonify({"download_mbps": round(dl,2), "upload_mbps": round(ul,2)})
    except Exception as e:
        return jsonify({"error": str(e)})

@app.route("/subscription")
def subscription():
    domain = os.environ.get("CUSTOM_DOMAIN", "trycloudflare.com")
    vless_link = f"vless://{UUID_VLESS}@{domain}:443?security=tls&type=ws&path=/vless&sni={domain}#ELMINYAWE-VLESS"
    vmess_link = f"vmess://{UUID_VMESS}@{domain}:443?security=tls&type=ws&path=/v2ray&sni={domain}#ELMINYAWE-VMESS"
    trojan_link = f"trojan://{PASS_TROJAN}@{domain}:443?security=tls&type=ws&path=/trojan&sni={domain}#ELMINYAWE-TROJAN"
    return jsonify({"vless": vless_link, "vmess": vmess_link, "trojan": trojan_link})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False)
APIEOF

# ================================================================
# 17) Helper scripts
# ================================================================
RUN cat > /usr/local/bin/show-info.sh << 'SIEOF'
#!/bin/bash
while true; do
    clear
    echo "╔════════════════════════════════════════════════════╗"
    echo "║      ELMINYAWE SERVER v3.0-ssl                     ║"
    echo "╠════════════════════════════════════════════════════╣"
    echo "│ SSH:          Port 22 (root)                       │"
    echo "│ HTTPS Proxy:  Port 443 -> 8118  [TLS 1.2/1.3]      │"
    echo "│ HTTP:         Port 80  -> 443 redirect             │"
    echo "│ TTYD:         Port 8081                            │"
    echo "│ API:          Port 5001                            │"
    echo "│ VMess:        Port 10086                           │"
    echo "│ VLESS:        Port 10087                           │"
    echo "│ Trojan:       Port 10088                           │"
    echo "│ SS:           Port 8388                            │"
    echo "│ SOCKS5:       Port 1080                            │"
    echo "│ HTTP Proxy:   Port 8118                            │"
    echo "│ Panel:        Port 8080 (via Nginx 9090)           │"
    echo "│ UDPGW:        Port 7300                            │"
    echo "│ Reality:      Port 8443                            │"
    echo "╚════════════════════════════════════════════════════╝"
    echo ""
    echo "Cloudflare URLs:"
    for f in /tmp/cf_*.log; do [ -f "$f" ] && echo "  $(basename $f): $(grep -oP 'https?://[^\s]+\.trycloudflare\.com' "$f" | tail -1)"; done
    echo ""
    echo "Reality Keys:"
    cat /etc/xray/reality_keys.json 2>/dev/null || echo "  Not generated yet"
    echo ""
    echo "System: $(date)"
    free -h | grep Mem | awk '{print "RAM: " $3 "/" $2}'
    uptime | awk '{print "Load: " $(NF-2), $(NF-1), $NF}'
    sleep 5
done
SIEOF
RUN chmod +x /usr/local/bin/show-info.sh

RUN cat > /usr/local/bin/service-monitor.sh << 'SMEEOF'
#!/bin/bash
while true; do
    for svc in sshd ttyd xray ss-server 3proxy nginx pufferpanel badvpn-udpgw; do
        if ! pgrep -x "$svc" > /dev/null 2>&1 && ! pgrep -f "$svc" > /dev/null 2>&1; then
            echo "[$(date)] WARNING: $svc not running"
        fi
    done
    sleep 10
done
SMEEOF
RUN chmod +x /usr/local/bin/service-monitor.sh

RUN cat > /usr/local/bin/setup-admin.sh << 'SAEOF'
#!/bin/bash
sleep 15
echo "[+] Setting up PufferPanel admin..."
/usr/bin/pufferpanel user add --name admin --email admin@elminyawe.local --password "${ROOT_PASSWORD:-ELMINYAWE}" --admin 2>/dev/null || true
SAEOF
RUN chmod +x /usr/local/bin/setup-admin.sh

# ================================================================
# 18) Supervisor config
# ================================================================
RUN mkdir -p /etc/supervisor/conf.d
RUN cat > /etc/supervisor/conf.d/services.conf << 'SCEOF'
[supervisord]
nodaemon=true
user=root
logfile=/dev/null
logfile_maxbytes=0
pidfile=/tmp/supervisord.pid

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:ttyd]
command=/usr/local/bin/ttyd -p 8081 -c root:%(ENV_ROOT_PASSWORD)s /bin/bash
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:api]
command=/root/.pyenv/shims/python /app/api.py
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:xray]
command=/usr/local/bin/xray run -config /etc/xray/config.json
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:shadowsocks]
command=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:3proxy]
command=/usr/local/3proxy/bin/3proxy /etc/3proxy/3proxy.cfg
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:pufferpanel]
command=/usr/bin/pufferpanel run
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=/usr/sbin/nginx -g 'daemon off;'
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:udpgw]
command=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 --max-connections-for-client 10
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:show-info]
command=/usr/local/bin/show-info.sh
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:service-monitor]
command=/usr/local/bin/service-monitor.sh
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:setup-admin]
command=/usr/local/bin/setup-admin.sh
autostart=false
autorestart=false
startsecs=0
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SCEOF

# ================================================================
# 19) Cloudflare Tunnel scripts
# ================================================================
RUN cat > /usr/local/bin/cf-tunnels.sh << 'CFEOF'
#!/bin/bash
if [ -n "$CF_TUNNEL_TOKEN" ]; then
    echo "[CF] Using Cloudflare Tunnel token..."
    exec cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN"
else
    echo "[CF] Starting temporary tunnels..."
    cloudflared tunnel --no-autoupdate --url http://localhost:8081 > /tmp/cf_ttyd.log 2>&1 &
    cloudflared tunnel --no-autoupdate --url http://localhost:5001 > /tmp/cf_api.log 2>&1 &
    cloudflared tunnel --no-autoupdate --url http://localhost:10086 > /tmp/cf_v2ray.log 2>&1 &
    cloudflared tunnel --no-autoupdate --url http://localhost:10087 > /tmp/cf_vless.log 2>&1 &
    cloudflared tunnel --no-autoupdate --url http://localhost:10088 > /tmp/cf_trojan.log 2>&1 &
    cloudflared tunnel --no-autoupdate --url http://localhost:9090 > /tmp/cf_nginx.log 2>&1 &
    wait
fi
CFEOF
RUN chmod +x /usr/local/bin/cf-tunnels.sh

RUN cat >> /etc/supervisor/conf.d/services.conf << 'CFSC'

[program:cloudflared]
command=/usr/local/bin/cf-tunnels.sh
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
CFSC

# ================================================================
# 20) Entrypoint — generates Reality keys & starts supervisord
# ================================================================
RUN cat > /usr/local/bin/entrypoint.sh << 'EPEOF'
#!/bin/bash
set -e

# Set root password
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "[+] Root password set from ROOT_PASSWORD env"
else
    echo "root:ELMINYAWE" | chpasswd
    echo "[!] Using default root password: ELMINYAWE"
fi

# Generate 3proxy config
PROXY_USER="${PROXY_USER:-admin}"
PROXY_PASS="${PROXY_PASS:-ELMINYAWE}"

cat > /etc/3proxy/3proxy.cfg << EOF
daemon
maxconn 1000
nserver 1.1.1.1
nserver 8.8.8.8
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
auth strong
users ${PROXY_USER}:CL:${PROXY_PASS}
allow ${PROXY_USER}

# SOCKS5 (open)
socks -p1080

# HTTP Proxy (auth required)
proxy -p8118
EOF

echo "[+] 3proxy HTTP proxy user: ${PROXY_USER}"
echo "[+] 3proxy HTTP proxy pass: ${PROXY_PASS}"

# Generate Reality x25519 keys
if [ ! -f /etc/xray/reality_keys.json ]; then
    echo "[+] Generating Reality x25519 keys..."
    KEYOUT=$(/usr/local/bin/xray x25519)
    PRIVATE_KEY=$(echo "$KEYOUT" | grep "Private key:" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$KEYOUT" | grep "Public key:" | awk '{print $3}')
    echo "{\"privateKey\":\"$PRIVATE_KEY\",\"publicKey\":\"$PUBLIC_KEY\"}" > /etc/xray/reality_keys.json
    echo "[+] Reality Public Key: $PUBLIC_KEY"
    echo "[+] Reality Private Key: $PRIVATE_KEY"
else
    echo "[+] Using existing Reality keys"
    PRIVATE_KEY=$(cat /etc/xray/reality_keys.json | python3 -c "import sys,json; print(json.load(sys.stdin)['privateKey'])")
fi

# Inject private key into xray config
sed -i "s|__REALITY_PRIVATE_KEY__|$PRIVATE_KEY|g" /etc/xray/config.json

# Initialize PufferPanel database if not exists
if [ ! -f /var/lib/pufferpanel/pufferpanel.db ]; then
    echo "[+] Initializing PufferPanel database..."
    cd /var/lib/pufferpanel
    /usr/bin/pufferpanel migrate 2>/dev/null || true
fi

# Start admin setup in background
(/usr/local/bin/setup-admin.sh) &

echo "[+] Starting ELMINYAWE SERVER v3.0-ssl..."
echo "[+] SSH:        Port 22 (root)"
echo "[+] HTTPS:      Port 443 [SSL/TLS] -> 8118"
echo "[+] HTTP:       Port 80  (redirect -> 443)"
echo "[+] TTYD:       Port 8081 | API: Port 5001"
echo "[+] VMess:      10086 | VLESS: 10087 | Trojan: 10088 | SS: 8388"
echo "[+] SOCKS5:     1080 | HTTP: 8118 | Panel: 8080 | UDPGW: 7300 | Reality: 8443"

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
EPEOF
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 80 443 1080 8443 7300 8080 8081 8118 8388 9090 5001 5657 10086 10087 10088

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
