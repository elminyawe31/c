FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV PYTHONUNBUFFERED=1
ENV LANG=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates openssl \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

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
    shadowsocks-libev speedtest-cli \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /run/sshd && \
    sed -i 's/^#\s*\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\s*\(PasswordAuthentication\).*/\1 yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\s*\(ChallengeResponseAuthentication\).*/\1 no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\s*\(UsePAM\).*/\1 yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\s*\(X11Forwarding\).*/\1 yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\s*\(PrintMotd\).*/\1 no/' /etc/ssh/sshd_config && \
    sed -i 's/^#\s*\(AcceptEnv\).*/\1 LANG LC_*/' /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=ELMINYAWE/CN=localhost" && \
    chmod 600 /etc/nginx/ssl/key.pem && \
    chmod 644 /etc/nginx/ssl/cert.pem

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
    pip install --upgrade pip flask requests psutil speedtest-cli

RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in \
        amd64) t=x86_64;; \
        arm64) t=aarch64;; \
        *) t="$arch";; \
    esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# ===== FIX: Xray installation =====
RUN XRAY_VERSION="v26.3.27" && \
    cd /tmp && \
    curl -fsSL -o xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" && \
    mkdir -p /tmp/xray-extract && \
    unzip -o xray.zip -d /tmp/xray-extract/ && \
    mv /tmp/xray-extract/xray /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    mkdir -p /usr/local/share/xray /usr/local/etc/xray /var/log/xray /etc/xray /usr/share/xray && \
    curl -fsSL -o /usr/local/share/xray/geoip.dat "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" && \
    curl -fsSL -o /usr/local/share/xray/geosite.dat "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" && \
    mv /usr/local/share/xray/dlc.dat /usr/local/share/xray/geosite.dat 2>/dev/null || true && \
    ln -sf /usr/local/share/xray/geoip.dat /usr/share/xray/geoip.dat && \
    ln -sf /usr/local/share/xray/geosite.dat /usr/share/xray/geosite.dat && \
    rm -rf /tmp/xray.zip /tmp/xray-extract

RUN git clone https://github.com/z3APA3A/3proxy.git /tmp/3proxy && \
    cd /tmp/3proxy && \
    make -f Makefile.Linux && \
    mkdir -p /usr/local/3proxy/bin && \
    cp bin/3proxy /usr/local/3proxy/bin/ && \
    cp bin/3proxy_proxy /usr/local/3proxy/bin/proxy 2>/dev/null || true && \
    cp bin/3proxy_socks /usr/local/3proxy/bin/socks 2>/dev/null || true && \
    rm -rf /tmp/3proxy

RUN git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn && \
    cd /tmp/badvpn && mkdir build && cd build && \
    cmake .. -DBUILD_UDPGW=1 && make -j$(nproc) && \
    cp udpgw/badvpn-udpgw /usr/local/bin/ && \
    rm -rf /tmp/badvpn

RUN curl -fsSL --output /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" && \
    chmod +x /usr/local/bin/cloudflared

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

RUN mkdir -p /etc/3proxy /app /var/log/supervisor /tmp/cf

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
                    "serverNames": ["www.microsoft.com"],
                    "privateKey": "__REALITY_PRIVATE_KEY__",
                    "shortIds": ["abcd12", "ef34"]
                }
            }
        }
    ],
    "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
XRAYEOF

RUN cat > /etc/shadowsocks-libev/config.json << 'SSEOF'
{
    "server": "0.0.0.0", "server_port": 8388,
    "password": "ELMINYAWE", "method": "aes-256-gcm",
    "timeout": 300, "fast_open": true
}
SSEOF

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

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

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

    server {
        listen 80 default_server;
        server_name _;
        return 301 https://$host$request_uri;
    }
}
NGEOF

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
        with open("/tmp/cf_" + prefix + ".log") as fh:
            for line in fh:
                m = re.search(r'(https?://[a-z0-9-]+\.trycloudflare\.com)', line)
                if m:
                    return m.group(1)
    except Exception:
        pass
    return None

def get_reality_keys():
    try:
        with open("/etc/xray/reality_keys.json") as fh:
            return json.load(fh)
    except Exception:
        return {}

@app.route("/")
def index():
    return jsonify({"name": "ELMINYAWE SERVER", "version": "v3.1-fixed", "status": "running"})

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
        try:
            procs.append(p.info)
        except Exception:
            pass
    procs.sort(key=lambda x: x.get('memory_percent', 0), reverse=True)
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
    for svc in ["ttyd", "api", "v2ray", "vless", "trojan", "nginx"]:
        u = read_cf_url(svc)
        if u:
            cf_urls[svc] = u
    reality = get_reality_keys()
    if domain:
        links = {
            "ttyd": "https://ttyd." + domain,
            "api": "https://api." + domain,
            "vmess": "https://vmess." + domain,
            "vless": "https://vless." + domain,
            "trojan": "https://trojan." + domain,
            "panel": "https://panel." + domain
        }
    else:
        links = cf_urls
    return jsonify({
        "server": "ELMINYAWE",
        "version": "v3.1-fixed",
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
        return jsonify({"download_mbps": round(dl, 2), "upload_mbps": round(ul, 2)})
    except Exception as e:
        return jsonify({"error": str(e)})

@app.route("/subscription")
def subscription():
    domain = os.environ.get("CUSTOM_DOMAIN", "trycloudflare.com")
    vless_link = "vless://" + UUID_VLESS + "@" + domain + ":443?security=tls&type=ws&path=/vless&sni=" + domain + "#ELMINYAWE-VLESS"
    vmess_link = "vmess://" + UUID_VMESS + "@" + domain + ":443?security=tls&type=ws&path=/v2ray&sni=" + domain + "#ELMINYAWE-VMESS"
    trojan_link = "trojan://" + PASS_TROJAN + "@" + domain + ":443?security=tls&type=ws&path=/trojan&sni=" + domain + "#ELMINYAWE-TROJAN"
    return jsonify({"vless": vless_link, "vmess": vmess_link, "trojan": trojan_link})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False)
APIEOF

RUN cat > /usr/local/bin/show-info.sh << 'SIEOF'
#!/bin/bash
while true; do
    clear
    echo "=============================================="
    echo "  ELMINYAWE SERVER v3.1-fixed"
    echo "=============================================="
    echo ""
    echo "[SSH] Port: 22"
    echo "[PufferPanel] Port: 8080"
    echo "[TTYD] Port: 8081"
    echo "[API] Port: 5001"
    echo "[Nginx] Ports: 80, 443, 9090"
    echo "[SOCKS5] Port: 1080"
    echo "[HTTP Proxy] Port: 8118"
    echo "[Shadowsocks] Port: 8388"
    echo "[Xray WS] Ports: 10086(vmess), 10087(vless), 10088(trojan)"
    echo "[Xray Reality] Port: 8443"
    echo "[BadVPN UDPGW] Port: 7300 (127.0.0.1)"
    echo ""
    echo "--- System Info ---"
    uptime
    echo ""
    free -h 2>/dev/null || echo "free not available"
    echo ""
    df -h / 2>/dev/null || echo "df not available"
    echo ""
    echo "--- Active Services ---"
    ss -tlnp 2>/dev/null | grep -E ':(22|80|443|1080|8080|8081|8118|8388|8443|9090|5001|5657|10086|10087|10088)' || netstat -tlnp 2>/dev/null | grep -E ':(22|80|443|1080|8080|8081|8118|8388|8443|9090|5001|5657|10086|10087|10088)' || echo "No ss/netstat"
    echo ""
    echo "--- Cloudflare URLs ---"
    for svc in ttyd api v2ray vless trojan nginx; do
        if [ -f /tmp/cf_${svc}.log ]; then
            url=$(grep -oP 'https?://[a-z0-9-]+\.trycloudflare\.com' /tmp/cf_${svc}.log | tail -1)
            [ -n "$url" ] && echo "[$svc] $url"
        fi
    done
    echo ""
    echo "--- Xray Reality Keys ---"
    if [ -f /etc/xray/reality_keys.json ]; then
        cat /etc/xray/reality_keys.json
    else
        echo "Keys not generated yet."
    fi
    echo ""
    echo "--- API Endpoints ---"
    echo "http://:5001/         -> Server Info"
    echo "http://:5001/health   -> Health Check"
    echo "http://:5001/system   -> System Stats"
    echo "http://:5001/services -> Running Services"
    echo "http://:5001/proxy-info -> Proxy Info"
    echo "http://:5001/inf      -> Full Info"
    echo "http://:5001/speedtest -> Speed Test"
    echo "http://:5001/subscription -> Subscription Links"
    echo ""
    sleep 30
done
SIEOF
RUN chmod +x /usr/local/bin/show-info.sh

RUN cat > /usr/local/bin/service-monitor.sh << 'SMEOF'
#!/bin/bash
LOG="/var/log/supervisor/service-monitor.log"
mkdir -p /var/log/supervisor
echo "[$(date)] Service Monitor Started" >> $LOG

while true; do
    for svc in ssh nginx xray shadowsocks-libev 3proxy ttyd cloudflared badvpn-udpgw pufferpanel flask-api; do
        if ! pgrep -f "$svc" > /dev/null 2>&1; then
            echo "[$(date)] WARNING: $svc is not running!" >> $LOG
        fi
    done
    sleep 60
done
SMEOF
RUN chmod +x /usr/local/bin/service-monitor.sh

RUN cat > /usr/local/bin/setup-admin.sh << 'SAEOF'
#!/bin/bash
if [ -z "$ROOT_PASSWORD" ]; then
    ROOT_PASSWORD="ELMINYAWE"
fi
echo "root:$ROOT_PASSWORD" | chpasswd
echo "[OK] Root password set."
if command -v pufferpanel > /dev/null 2>&1; then
    pufferpanel user add --name admin --email admin@elminyawe.local --password "$ROOT_PASSWORD" --admin || true
    echo "[OK] PufferPanel admin created."
fi
SAEOF
RUN chmod +x /usr/local/bin/setup-admin.sh

RUN cat > /usr/local/bin/cf-tunnels.sh << 'CFEOF'
#!/bin/bash
mkdir -p /tmp/cf
LOG_DIR="/tmp/cf"

start_tunnel() {
    local name=$1
    local port=$2
    local logfile="${LOG_DIR}/cf_${name}.log"
    echo "[$(date)] Starting Cloudflare tunnel: $name -> localhost:$port"
    nohup cloudflared tunnel run --url "http://localhost:${port}" > "$logfile" 2>&1 &
}

start_tunnel "ttyd" 8081
start_tunnel "api" 5001
start_tunnel "v2ray" 10086
start_tunnel "vless" 10087
start_tunnel "trojan" 10088
start_tunnel "nginx" 9090

sleep 10
echo "[OK] All Cloudflare tunnels started."
echo "[INFO] Waiting for URLs..."
for svc in ttyd api v2ray vless trojan nginx; do
    logfile="${LOG_DIR}/cf_${svc}.log"
    for i in $(seq 1 30); do
        if [ -f "$logfile" ]; then
            url=$(grep -oP 'https?://[a-z0-9-]+\.trycloudflare\.com' "$logfile" | head -1)
            if [ -n "$url" ]; then
                echo "[$svc] $url"
                break
            fi
        fi
        sleep 2
    done
done
CFEOF
RUN chmod +x /usr/local/bin/cf-tunnels.sh

RUN cat > /etc/supervisor/conf.d/services.conf << 'SCEOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
priority=10

[program:nginx]
command=/usr/sbin/nginx -g 'daemon off;'
autostart=true
autorestart=true
priority=20

[program:xray]
command=/usr/local/bin/xray -config /etc/xray/config.json
autostart=true
autorestart=true
priority=30

[program:shadowsocks-libev]
command=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
autostart=true
autorestart=true
priority=30

[program:3proxy]
command=/usr/local/3proxy/bin/3proxy /etc/3proxy/3proxy.cfg
autostart=true
autorestart=true
priority=30

[program:ttyd]
command=/usr/local/bin/ttyd -p 8081 -c root:%(ENV_ROOT_PASSWORD)s /bin/bash
autostart=true
autorestart=true
priority=40

[program:cloudflared]
command=/usr/local/bin/cf-tunnels.sh
autostart=true
autorestart=false
startsecs=0
priority=50

[program:badvpn-udpgw]
command=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
autostart=true
autorestart=true
priority=30

[program:pufferpanel]
command=/usr/bin/pufferpanel run
autostart=true
autorestart=true
priority=40

[program:flask-api]
command=python3 /app/api.py
autostart=true
autorestart=true
priority=40
directory=/app

[program:show-info]
command=/usr/local/bin/show-info.sh
autostart=true
autorestart=true
priority=60
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:service-monitor]
command=/usr/local/bin/service-monitor.sh
autostart=true
autorestart=true
priority=70
SCEOF

RUN cat >> /etc/supervisor/conf.d/services.conf << 'CFSC'

[program:setup-admin]
command=/usr/local/bin/setup-admin.sh
autostart=true
autorestart=false
startsecs=0
priority=5
CFSC

RUN cat > /usr/local/bin/entrypoint.sh << 'EPEOF'
#!/bin/bash
set -e

echo "=========================================="
echo "  ELMINYAWE SERVER v3.1-fixed"
echo "  Starting initialization..."
echo "=========================================="

if [ -z "$ROOT_PASSWORD" ]; then
    export ROOT_PASSWORD="ELMINYAWE"
    echo "[WARN] ROOT_PASSWORD not set. Using default: ELMINYAWE"
else
    echo "[OK] ROOT_PASSWORD is set."
fi

echo "[*] Setting up root password..."
echo "root:$ROOT_PASSWORD" | chpasswd

echo "[*] Generating Xray Reality keys..."
REALITY_KEYS=$(/usr/local/bin/xray x25519 2>/dev/null || echo "")
if [ -n "$REALITY_KEYS" ]; then
    PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key:" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key:" | awk '{print $3}')
    if [ -n "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ]; then
        echo "{\"private_key\":\"$PRIVATE_KEY\",\"public_key\":\"$PUBLIC_KEY\"}" > /etc/xray/reality_keys.json
        echo "[OK] Reality keys generated."
        # FIX: use # as sed delimiter instead of | to avoid escaping issues
        sed -i "s#__REALITY_PRIVATE_KEY__#$PRIVATE_KEY#g" /etc/xray/config.json
        echo "[OK] Injected Reality private key into Xray config."
    else
        echo "[WARN] Could not parse Reality keys."
    fi
else
    echo "[WARN] xray x25519 failed."
fi

echo "[*] Setting up 3proxy config..."
cat > /etc/3proxy/3proxy.cfg << EOF
# 3proxy config - NO daemon mode (managed by supervisor)
# FIX: removed 'daemon' line

log /var/log/3proxy.log D
rotate 30

# HTTP proxy on 8118 (no auth for nginx upstream)
proxy -p8118 -n -a

# SOCKS5 on 1080
socks -p1080 -n -a

# Allow all
allow *
EOF

echo "[*] Starting services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
EPEOF
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 80 443 1080 8080 8081 8118 8388 8443 9090 5001 5657 10086 10087 10088

WORKDIR /app
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
