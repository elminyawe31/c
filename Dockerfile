FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    ROOT_PASSWORD=ELMINYAWE \
    SSH_USER=yaso \
    SSH_PASSWORD=ELMINYAWE \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    PYTHONUNBUFFERED=1

# ── Base packages ─────────────────────────────────────────────────────────────
RUN apt-get update -y || (sleep 5 && apt-get update -y) && \
    apt-get install -y --no-install-recommends \
    openssh-server sudo curl wget git vim nano htop tmux \
    zip unzip tar rsync net-tools iproute2 iputils-ping dnsutils \
    build-essential python3 python3-pip ca-certificates openssl gnupg lsb-release \
    software-properties-common locales tzdata cron bash-completion man-db \
    jq less file passwd openssh-client sqlite3 \
    make libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    nginx supervisor libtool libev-dev libc-ares-dev libmbedtls-dev \
    libsodium-dev libpcre2-dev automake pkg-config \
    libwebsockets-dev libjson-c-dev zlib1g-dev \
    && locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# ── Python (pyenv) ──────────────────────────────────────────────────────────
ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

RUN curl -fsSL https://pyenv.run | bash && \
    eval "$(pyenv init -)" && \
    pyenv install 3.13 && pyenv global 3.13 && \
    pip install --upgrade pip flask requests psutil

# ── TTYD ────────────────────────────────────────────────────────────────────
RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in amd64) t=x86_64;; arm64) t=aarch64;; *) t="$arch";; esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# ── Cloudflared ─────────────────────────────────────────────────────────────
RUN curl -fsSL --output /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" && \
    chmod +x /usr/local/bin/cloudflared

# ── SSH Server ──────────────────────────────────────────────────────────────
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

# ── SSL/TLS (Nginx) ─────────────────────────────────────────────────────────
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=ELMINYAWE/CN=localhost" && \
    chmod 600 /etc/nginx/ssl/key.pem && \
    chmod 644 /etc/nginx/ssl/cert.pem

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

# ── 3proxy (SOCKS5 + HTTP Proxy) ────────────────────────────────────────────
RUN git clone https://github.com/z3APA3A/3proxy.git /tmp/3proxy && \
    cd /tmp/3proxy && make -f Makefile.Linux && \
    mkdir -p /usr/local/3proxy/bin && \
    cp bin/3proxy /usr/local/3proxy/bin/ && \
    cp bin/3proxy_proxy /usr/local/3proxy/bin/proxy 2>/dev/null || true && \
    cp bin/3proxy_socks /usr/local/3proxy/bin/socks 2>/dev/null || true && \
    rm -rf /tmp/3proxy && \
    mkdir -p /etc/3proxy /var/log/supervisor /tmp/cf

# ── Flask API ───────────────────────────────────────────────────────────────
RUN mkdir -p /app

RUN cat > /app/api.py << 'APIEOF'
import os, json, psutil, time, socket, subprocess, re
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({"name": "ELMINYAWE SERVER", "version": "v3.2-ssh-yaso", "status": "running"})

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
        "ssh": {"host": "0.0.0.0", "port": 22, "user": "yaso", "note": "TCP port 22 required"},
        "https_proxy": {"host": "0.0.0.0", "port": 443, "type": "tls", "backend": 8118},
        "http_redirect": {"host": "0.0.0.0", "port": 80, "type": "redirect"},
        "socks5": {"host": "0.0.0.0", "port": 1080, "note": "SOCKS5 proxy"},
        "http": {"host": "0.0.0.0", "port": 8118}
    })

@app.route("/inf")
def inf():
    domain = os.environ.get("CUSTOM_DOMAIN")
    cf_urls = {}
    for svc in ["ttyd", "api", "nginx"]:
        try:
            with open("/tmp/cf_" + svc + ".log") as fh:
                for line in fh:
                    m = re.search(r'(https?://[a-z0-9-]+\.trycloudflare\.com)', line)
                    if m:
                        cf_urls[svc] = m.group(1)
                        break
        except Exception:
            pass
    if domain:
        links = {
            "ttyd": "https://ttyd." + domain,
            "api": "https://api." + domain,
            "panel": "https://panel." + domain
        }
    else:
        links = cf_urls
    return jsonify({
        "server": "ELMINYAWE",
        "version": "v3.2-ssh-yaso",
        "custom_domain": domain,
        "cloudflare_urls": cf_urls,
        "links": links,
        "ssh_user": "yaso",
        "ssh_password": "ELMINYAWE",
        "system": {
            "cpu": psutil.cpu_percent(),
            "ram": dict(psutil.virtual_memory()._asdict()),
            "disk": dict(psutil.disk_usage('/')._asdict())
        }
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False)
APIEOF

# ── Helper scripts ──────────────────────────────────────────────────────────
RUN cat > /usr/local/bin/show-info.sh << 'SIEOF'
#!/bin/bash
export TERM=xterm
while true; do
    clear
    echo "=============================================="
    echo " ELMINYAWE SERVER v3.2 (SSH:yaso + HTTPS + SOCKS5)"
    echo "=============================================="
    echo ""
    echo "[SSH]         Port: 22  |  User: yaso  |  Pass: ELMINYAWE"
    echo "[NOTE]        >>> Add TCP Port 22 in Railway Dashboard for SSH access <<<"
    echo ""
    echo "[TTYD]        Port: 8081"
    echo "[API]         Port: 5001"
    echo "[Nginx]       Ports: 80, 443, 9090"
    echo "[SOCKS5]      Port: 1080  |  >>> Add TCP Port 1080 for SOCKS5 proxy <<<"
    echo "[HTTP Proxy]  Port: 8118"
    echo ""
    echo "--- System Info ---"
    uptime
    echo ""
    free -h 2>/dev/null || echo "free not available"
    echo ""
    df -h / 2>/dev/null || echo "df not available"
    echo ""
    echo "--- Active Services ---"
    ss -tlnp 2>/dev/null | grep -E ':(22|80|443|1080|8080|8081|8118|9090|5001)' || \
    netstat -tlnp 2>/dev/null | grep -E ':(22|80|443|1080|8080|8081|8118|9090|5001)' || \
    echo "No ss/netstat"
    echo ""
    echo "--- Cloudflare URLs ---"
    for svc in ttyd api nginx; do
        if [ -f /tmp/cf_${svc}.log ]; then
            url=$(grep -oP 'https?://[a-z0-9-]+\.trycloudflare\.com' /tmp/cf_${svc}.log | tail -1)
            [ -n "$url" ] && echo "[$svc] $url"
        fi
    done
    echo ""
    echo "--- API Endpoints ---"
    echo "http://:5001/         -> Server Info"
    echo "http://:5001/health   -> Health Check"
    echo "http://:5001/system   -> System Stats"
    echo "http://:5001/services -> Running Services"
    echo "http://:5001/proxy-info -> Proxy Info"
    echo "http://:5001/inf      -> Full Info"
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
    for svc in ssh nginx 3proxy ttyd cloudflared flask-api; do
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
USER=${SSH_USER:-yaso}
PASS=${SSH_PASSWORD:-ELMINYAWE}
ROOT_PASS=${ROOT_PASSWORD:-ELMINYAWE}

echo "[*] Setting up root password..."
echo "root:$ROOT_PASS" | chpasswd

echo "[*] Creating user '$USER' with full root privileges..."
id "$USER" &>/dev/null || useradd -m -s /bin/bash "$USER"
echo "$USER:$PASS" | chpasswd
usermod -aG sudo "$USER"
echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER
chmod 440 /etc/sudoers.d/$USER

echo "[OK] User '$USER' created with password '$PASS'"
echo "[OK] User '$USER' added to sudoers (NOPASSWD)"
echo "[OK] Root password set."
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
start_tunnel "nginx" 9090

sleep 10
echo "[OK] All Cloudflare tunnels started."
echo "[INFO] Waiting for URLs..."
for svc in ttyd api nginx; do
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

# ── Supervisor config ───────────────────────────────────────────────────────
RUN cat > /etc/supervisor/conf.d/services.conf << 'SCEOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:setup-admin]
command=/usr/local/bin/setup-admin.sh
autostart=true
autorestart=false
startsecs=0
priority=5

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

# ── Entrypoint ──────────────────────────────────────────────────────────────
RUN cat > /usr/local/bin/entrypoint.sh << 'EPEOF'
#!/bin/bash
set -e

echo "=========================================="
echo " ELMINYAWE SERVER v3.2"
echo " SSH:yaso | HTTPS | SOCKS5"
echo "=========================================="

USER=${SSH_USER:-yaso}
PASS=${SSH_PASSWORD:-ELMINYAWE}
ROOT_PASS=${ROOT_PASSWORD:-ELMINYAWE}

if [ -z "$ROOT_PASSWORD" ]; then
    export ROOT_PASSWORD="ELMINYAWE"
    echo "[WARN] ROOT_PASSWORD not set. Using default: ELMINYAWE"
else
    echo "[OK] ROOT_PASSWORD is set."
fi

echo ""
echo "=========================================="
echo "  IMPORTANT SETUP NOTES"
echo "=========================================="
echo ""
echo "  [SSH ACCESS]"
echo "    User: $USER"
echo "    Pass: $PASS"
echo "    Port: 22"
echo "    >>> YOU MUST ADD TCP PORT 22 IN RAILWAY DASHBOARD <<<"
echo "    >>> Go to: Settings -> Networking -> Public Networking -> TCP:22 <<<"
echo ""
echo "  [SOCKS5 PROXY]"
echo "    Port: 1080"
echo "    >>> YOU MUST ADD TCP PORT 1080 FOR SOCKS5 TO WORK <<<"
echo "    >>> Go to: Settings -> Networking -> Public Networking -> TCP:1080 <<<"
echo ""
echo "  [HTTPS PROXY]"
echo "    Port: 443  (Use Domain/HTTPS in Railway)"
echo ""
echo "  [ROOT ACCESS]"
echo "    User: root  |  Pass: $ROOT_PASS"
echo "    System runs fully as root internally."
echo "    User '$USER' has sudo NOPASSWD privileges."
echo ""
echo "=========================================="
echo ""

echo "[*] Setting up users and passwords..."
echo "root:$ROOT_PASS" | chpasswd

id "$USER" &>/dev/null || useradd -m -s /bin/bash "$USER"
echo "$USER:$PASS" | chpasswd
usermod -aG sudo "$USER"
echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER
chmod 440 /etc/sudoers.d/$USER

echo "[OK] User '$USER' created with sudo privileges."
echo "[OK] Root password configured."

echo "[*] Setting up 3proxy config..."
cat > /etc/3proxy/3proxy.cfg << EOF
log /var/log/3proxy.log D
rotate 30

proxy -p8118 -n -a
socks -p1080 -n -a

allow *
EOF

echo "[*] Starting services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
EPEOF
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22 80 443 1080 8080 8081 8118 9090 5001

WORKDIR /app
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
