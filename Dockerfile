# ═══════════════════════════════════════════════════════════════
# ELMINYAWE SERVER - ULTIMATE EDITION v2.1 (FIXED)
# ═══════════════════════════════════════════════════════════════
FROM ubuntu:24.04

# ─── ARGUMENTS ───
ARG ROOT_PASSWORD=ELMINYAWE
ARG API_PORT=5001
ARG TTYD_PORT=8081
ARG PUFFER_PORT=8080
ARG SSH_PORT=22
ARG SFTP_PORT=5657
ARG V2RAY_PORT=10086
ARG SS_PORT=8388
ARG WG_PORT=51820
ARG SOCKS_PORT=1080
ARG HTTP_PROXY_PORT=8118
ARG LOG_LEVEL=INFO

# ─── ENVIRONMENT ───
ENV DEBIAN_FRONTEND=noninteractive \
    ROOT_PASSWORD=${ROOT_PASSWORD} \
    API_PORT=${API_PORT} \
    TTYD_PORT=${TTYD_PORT} \
    PUFFER_PORT=${PUFFER_PORT} \
    SSH_PORT=${SSH_PORT} \
    SFTP_PORT=${SFTP_PORT} \
    V2RAY_PORT=${V2RAY_PORT} \
    SS_PORT=${SS_PORT} \
    WG_PORT=${WG_PORT} \
    SOCKS_PORT=${SOCKS_PORT} \
    HTTP_PROXY_PORT=${HTTP_PROXY_PORT} \
    LOG_LEVEL=${LOG_LEVEL} \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONUNBUFFERED=1 \
    FORCE_COLOR=1 \
    TERM=xterm-256color

ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# ═══════════════════════════════════════════════════════════════
# STAGE 1: BASE SYSTEM
# ═══════════════════════════════════════════════════════════════
RUN apt-get update -y || (sleep 5 && apt-get update -y) && \
    apt-get install -y --no-install-recommends \
    openssh-server sudo curl wget git vim nano htop tmux \
    zip unzip tar rsync net-tools iproute2 iputils-ping dnsutils \
    build-essential cmake pkg-config \
    python3 python3-pip python3-venv python3-dev \
    ca-certificates gnupg lsb-release \
    software-properties-common \
    locales tzdata \
    cron bash-completion man-db jq less file passwd \
    openssh-client sqlite3 \
    make libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncurses-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    supervisor nginx \
    wireguard-tools iptables ipset \
    socat netcat-openbsd proxychains4 \
    fonts-liberation libappindicator3-1 libasound2t64 \
    libatk-bridge2.0-0 libnspr4 libnss3 libxss1 \
    xdg-utils libgbm1 libu2f-udev \
    rsyslog logrotate && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# ═══════════════════════════════════════════════════════════════
# STAGE 2: PYTHON
# ═══════════════════════════════════════════════════════════════
RUN curl -fsSL https://pyenv.run | bash && \
    pyenv install 3.13 && pyenv global 3.13 && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    bcrypt flask requests gunicorn psutil speedtest-cli \
    cryptography pyOpenSSL

# ═══════════════════════════════════════════════════════════════
# STAGE 3: SERVICES
# ═══════════════════════════════════════════════════════════════

# ttyd
RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in amd64) t=x86_64;; arm64) t=aarch64;; *) t="$arch";; esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# Cloudflared
RUN curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared

# Xray
RUN bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Shadowsocks
RUN apt-get update && apt-get install -y --no-install-recommends shadowsocks-libev && \
    rm -rf /var/lib/apt/lists/*

# 3proxy (FIXED: create symlink to /usr/local/bin)
RUN cd /tmp && \
    git clone --depth 1 https://github.com/z3APA3A/3proxy.git && \
    cd 3proxy && \
    make -f Makefile.Linux && \
    make -f Makefile.Linux install && \
    ln -sf /usr/local/3proxy/bin/3proxy /usr/local/bin/3proxy && \
    rm -rf /tmp/3proxy

# PufferPanel
RUN curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | os=ubuntu dist=noble bash && \
    apt-get install -y pufferpanel && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/lib/pufferpanel/email /var/lib/pufferpanel/servers /etc/pufferpanel && \
    echo '{}' > /var/lib/pufferpanel/email/emails.json

# ═══════════════════════════════════════════════════════════════
# STAGE 4: CONFIG FILES
# ═══════════════════════════════════════════════════════════════

# PufferPanel Config
RUN cat > /etc/pufferpanel/config.json <<'PPJSON'
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
PPJSON
RUN cp /etc/pufferpanel/config.json /var/lib/pufferpanel/config.json

# Xray Config
RUN mkdir -p /var/log/xray /etc/xray && cat > /etc/xray/config.json <<'XJSON'
{
  "log": { "loglevel": "warning", "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log" },
  "inbounds": [
    { "port": 10086, "protocol": "vmess", "settings": { "clients": [{ "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "alterId": 0 }] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/v2ray" } } },
    { "port": 10087, "protocol": "vless", "settings": { "clients": [{ "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901" }], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "port": 10088, "protocol": "trojan", "settings": { "clients": [{ "password": "ELMINYAWE" }] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } }
  ],
  "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
XJSON

# Shadowsocks Config
RUN mkdir -p /etc/shadowsocks-libev && cat > /etc/shadowsocks-libev/config.json <<'SSJSON'
{
  "server": "0.0.0.0",
  "server_port": 8388,
  "password": "ELMINYAWE",
  "method": "aes-256-gcm",
  "timeout": 300,
  "fast_open": false
}
SSJSON

# 3proxy Config
RUN mkdir -p /etc/3proxy && cat > /etc/3proxy/3proxy.cfg <<'P3CFG'
auth none
allow *
proxy -p1080 -a
socks -p8118 -a
flush
P3CFG

# SSH Config
RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?Port.*/Port 22/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 10/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 3/' /etc/ssh/sshd_config && \
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config && \
    echo "GatewayPorts yes" >> /etc/ssh/sshd_config

# Nginx Config (FIXED: escaped $ for nginx variables, no port 80 conflict)
RUN cat > /etc/nginx/nginx.conf <<'NGINX'
user root;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;
events { worker_connections: 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    keepalive_timeout 65;

    server {
        listen 9090;
        server_name _;
        location / {
            proxy_pass http://127.0.0.1:8080;
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
            proxy_set_header Host $host;
        }
        location /vless {
            proxy_pass http://127.0.0.1:10087;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
        }
        location /trojan {
            proxy_pass http://127.0.0.1:10088;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
        }
    }
}
NGINX
RUN mkdir -p /var/log/nginx /run/nginx

# ═══════════════════════════════════════════════════════════════
# STAGE 5: API APP
# ═══════════════════════════════════════════════════════════════
RUN mkdir -p /app /var/log/services

RUN cat > /app/api.py <<'APIPY'
import os, json, psutil, subprocess, time
from datetime import datetime
from flask import Flask, jsonify

app = Flask(__name__)

cf_urls = {}

def read_cf_url(logfile):
    try:
        with open(logfile, 'r') as f:
            lines = f.readlines()
            for line in reversed(lines):
                if 'trycloudflare.com' in line:
                    import re
                    m = re.search(r'https://[a-z0-9\-]+\.trycloudflare\.com', line)
                    if m:
                        return m.group(0)
    except:
        pass
    return "Waiting..."

@app.route('/')
def index():
    return jsonify({"name": "ELMINYAWE API", "version": "2.1", "status": "running"})

@app.route('/health')
def health():
    return jsonify({"status": "ok", "timestamp": datetime.utcnow().isoformat()})

@app.route('/services')
def services():
    s = []
    for p in psutil.process_iter(['pid', 'name', 'status']):
        try:
            s.append(p.info)
        except:
            pass
    return jsonify({"services": s[:50]})

@app.route('/system')
def system():
    return jsonify({
        "cpu_percent": psutil.cpu_percent(interval=0.5),
        "memory": dict(psutil.virtual_memory()._asdict()),
        "disk": dict(psutil.disk_usage('/')._asdict()),
        "boot_time": datetime.fromtimestamp(psutil.boot_time()).isoformat()
    })

@app.route('/proxy-info')
def proxy_info():
    return jsonify({
        "vmess": {"protocol": "VMess", "port": 443, "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "path": "/v2ray", "tls": True},
        "vless": {"protocol": "VLESS", "port": 443, "uuid": "b2c3d4e5-f6a7-8901-bcde-f12345678901", "path": "/vless", "tls": True},
        "trojan": {"protocol": "Trojan", "port": 443, "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE"), "path": "/trojan", "tls": True},
        "shadowsocks": {"protocol": "Shadowsocks", "port": 8388, "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE"), "method": "aes-256-gcm"},
        "socks5": {"protocol": "SOCKS5", "port": 1080, "auth": "none"},
        "http_proxy": {"protocol": "HTTP", "port": 8118, "auth": "none"}
    })

@app.route('/speedtest')
def speedtest():
    try:
        import speedtest
        s = speedtest.Speedtest()
        s.get_best_server()
        download = s.download() / (1024**2)
        upload = s.upload() / (1024**2)
        ping = s.results.ping
        return jsonify({
            "download_mbps": round(download, 2),
            "upload_mbps": round(upload, 2),
            "ping_ms": round(ping, 2),
            "timestamp": datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)
APIPY

# ═══════════════════════════════════════════════════════════════
# STAGE 6: SCRIPTS
# ═══════════════════════════════════════════════════════════════

RUN cat > /usr/local/bin/setup-admin.sh <<'ADMINSH'
#!/usr/bin/env bash
set -e
echo "root:${ROOT_PASSWORD}" | chpasswd
for i in {1..60}; do
    if sqlite3 /var/lib/pufferpanel/pufferpanel.db ".tables" 2>/dev/null | grep -q "users"; then
        break
    fi
    sleep 2
done
python3 << 'PYEOF'
import sqlite3, bcrypt, os
db_path = '/var/lib/pufferpanel/pufferpanel.db'
try:
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute("SELECT id FROM users WHERE email='ELMINYAWE@localhost.com'")
    user_row = c.fetchone()
    if not user_row:
        hashed = bcrypt.hashpw(b'ELMINYAWE', bcrypt.gensalt(10)).decode()
        c.execute("INSERT INTO users (username, email, password) VALUES (?, ?, ?)",
                  ('ELMINYAWE', 'ELMINYAWE@localhost.com', hashed))
        conn.commit()
        c.execute("SELECT id FROM users WHERE email='ELMINYAWE@localhost.com'")
        user_row = c.fetchone()
        print("Admin User created.")
    else:
        print("Admin User already exists.")
    user_id = user_row[0]
    c.execute("SELECT 1 FROM permissions WHERE user_id=?", (user_id,))
    if not c.fetchone():
        c.execute("""
        INSERT INTO permissions (
            user_id, admin, view_server, create_server, view_nodes, edit_nodes,
            deploy_nodes, view_templates, edit_templates, edit_users, view_users,
            edit_server_admin, delete_server, panel_settings, edit_server_data,
            edit_server_users, install_server, update_server, view_server_console,
            send_server_console, stop_server, start_server, view_server_stats,
            view_server_files, sftp_server, put_server_files
        ) VALUES (?, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
        """, (user_id,))
        conn.commit()
        print("Admin permissions granted!")
    else:
        c.execute("UPDATE permissions SET admin=1 WHERE user_id=?", (user_id,))
        conn.commit()
        print("Admin permissions updated.")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
PYEOF
ADMINSH
RUN chmod +x /usr/local/bin/setup-admin.sh

RUN cat > /usr/local/bin/service-monitor.sh <<'MONSH'
#!/usr/bin/env bash
while true; do
    echo ""
    echo "=== SERVICE HEALTH MONITOR ==="
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S UTC')"
    for svc in "SSH:22" "ttyd:8081" "API:5001" "PufferPanel:8080" "Nginx:9090" "VMess:10086" "VLESS:10087" "Trojan:10088" "Shadowsocks:8388" "SOCKS5:1080" "HTTP:8118"; do
        name="${svc%%:*}"
        port="${svc##*:}"
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            echo "  $name: RUNNING"
        else
            echo "  $name: STOPPED"
        fi
    done
    sleep 30
done
MONSH
RUN chmod +x /usr/local/bin/service-monitor.sh

RUN cat > /usr/local/bin/show-info.sh <<'INFOSH'
#!/usr/bin/env bash
get_cf_url() {
    local logfile="$1"
    if [ -f "$logfile" ]; then
        grep -o 'https://[a-z0-9\-]*\.trycloudflare\.com' "$logfile" 2>/dev/null | tail -n 1
    fi
}
while true; do
    sleep 15
    TTYD_URL=$(get_cf_url /tmp/cf_ttyd.log)
    API_URL=$(get_cf_url /tmp/cf_api.log)
    V2RAY_URL=$(get_cf_url /tmp/cf_v2ray.log)
    VLESS_URL=$(get_cf_url /tmp/cf_vless.log)
    TROJAN_URL=$(get_cf_url /tmp/cf_trojan.log)
    NGINX_URL=$(get_cf_url /tmp/cf_nginx.log)
    echo ""
    echo "=================================================="
    echo "  ELMINYAWE SERVER v2.1 - RUNNING"
    echo "=================================================="
    echo "  WEB TERMINAL: ${TTYD_URL:-Waiting...}"
    echo "  User: root | Pass: ${ROOT_PASSWORD}"
    echo "--------------------------------------------------"
    echo "  API: ${API_URL:-Waiting...}"
    echo "  Local: http://localhost:5001"
    echo "--------------------------------------------------"
    echo "  PufferPanel: http://localhost:8080"
    echo "  Nginx Proxy: ${NGINX_URL:-Waiting...}"
    echo "  Email: ELMINYAWE@localhost.com | Pass: ELMINYAWE"
    echo "--------------------------------------------------"
    echo "  SSH: ssh -p 22 root@<host>"
    echo "  SFTP: port 5657"
    echo "--------------------------------------------------"
    echo "  VMess: ${V2RAY_URL:-Waiting...} | UUID: a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    echo "  VLESS: ${VLESS_URL:-Waiting...} | UUID: b2c3d4e5-f6a7-8901-bcde-f12345678901"
    echo "  Trojan: ${TROJAN_URL:-Waiting...} | Pass: ${ROOT_PASSWORD}"
    echo "  Shadowsocks: port 8388 | aes-256-gcm"
    echo "  SOCKS5: port 1080 | HTTP Proxy: port 8118"
    echo "=================================================="
    sleep 35
done
INFOSH
RUN chmod +x /usr/local/bin/show-info.sh

# ═══════════════════════════════════════════════════════════════
# STAGE 7: SUPERVISOR
# ═══════════════════════════════════════════════════════════════
RUN mkdir -p /var/log/services /var/log/xray /var/log/nginx /var/log/supervisor /app /run/sshd

RUN cat > /etc/supervisor/conf.d/services.conf <<'SVCONF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/run/supervisord.pid

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
priority=10

[program:ttyd]
command=/usr/local/bin/ttyd --port 8081 --writable --credential "root:%(ENV_ROOT_PASSWORD)s" /bin/bash -l
autostart=true
autorestart=true
priority=20

[program:api]
command=bash -c 'export PATH="/root/.pyenv/bin:/root/.pyenv/shims:$PATH" && eval "$(pyenv init -)" && python3 /app/api.py'
autostart=true
autorestart=true
priority=20

[program:xray]
command=/usr/local/bin/xray run -config /etc/xray/config.json
autostart=true
autorestart=true
priority=20

[program:shadowsocks]
command=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
autostart=true
autorestart=true
priority=20

[program:3proxy]
command=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
autostart=true
autorestart=true
priority=20

[program:pufferpanel]
command=bash -c 'cd /var/lib/pufferpanel && unset PORT && pufferpanel run'
autostart=true
autorestart=true
priority=30

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
priority=30

[program:admin-setup]
command=bash -c 'sleep 10 && /usr/local/bin/setup-admin.sh'
autostart=true
autorestart=false
startretries=1
priority=40

[program:service-monitor]
command=/usr/local/bin/service-monitor.sh
autostart=true
autorestart=true
priority=50

[program:show-info]
command=/usr/local/bin/show-info.sh
autostart=true
autorestart=true
priority=50

[program:cf-ttyd]
command=bash -c 'while true; do /usr/local/bin/cloudflared tunnel --url http://localhost:8081 >> /tmp/cf_ttyd.log 2>&1; sleep 5; done'
autostart=true
autorestart=true
priority=60

[program:cf-api]
command=bash -c 'while true; do /usr/local/bin/cloudflared tunnel --url http://localhost:5001 >> /tmp/cf_api.log 2>&1; sleep 5; done'
autostart=true
autorestart=true
priority=60

[program:cf-v2ray]
command=bash -c 'while true; do /usr/local/bin/cloudflared tunnel --url http://localhost:10086 >> /tmp/cf_v2ray.log 2>&1; sleep 5; done'
autostart=true
autorestart=true
priority=60

[program:cf-vless]
command=bash -c 'while true; do /usr/local/bin/cloudflared tunnel --url http://localhost:10087 >> /tmp/cf_vless.log 2>&1; sleep 5; done'
autostart=true
autorestart=true
priority=60

[program:cf-trojan]
command=bash -c 'while true; do /usr/local/bin/cloudflared tunnel --url http://localhost:10088 >> /tmp/cf_trojan.log 2>&1; sleep 5; done'
autostart=true
autorestart=true
priority=60

[program:cf-nginx]
command=bash -c 'while true; do /usr/local/bin/cloudflared tunnel --url http://localhost:9090 >> /tmp/cf_nginx.log 2>&1; sleep 5; done'
autostart=true
autorestart=true
priority=60
SVCONF

# ═══════════════════════════════════════════════════════════════
# STAGE 8: ENTRYPOINT
# ═══════════════════════════════════════════════════════════════
RUN cat > /entrypoint.sh <<'ENTRY'
#!/usr/bin/env bash
set -e
echo "root:${ROOT_PASSWORD}" | chpasswd
export PYENV_ROOT="/root/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
eval "$(pyenv init -)"
/usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
ENTRY
RUN chmod +x /entrypoint.sh

EXPOSE 8080 8081 5001 22 5657 10086 10087 10088 8388 1080 8118 9090

CMD ["/entrypoint.sh"]
