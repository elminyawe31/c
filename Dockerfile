# ═══════════════════════════════════════════════════════════════
#  ELMINYAWE SERVER - ULTIMATE EDITION v2.0
#  Advanced Docker Container with VPN, Proxy & Game Panel
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

# ─── ENVIRONMENT VARIABLES ───
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

# ─── COLOR CODES FOR LOGS ───
ENV C_RESET="\033[0m" \
    C_RED="\033[1;31m" \
    C_GREEN="\033[1;32m" \
    C_YELLOW="\033[1;33m" \
    C_BLUE="\033[1;34m" \
    C_MAGENTA="\033[1;35m" \
    C_CYAN="\033[1;36m" \
    C_WHITE="\033[1;37m" \
    C_BOLD="\033[1m"

# ═══════════════════════════════════════════════════════════════
#  STAGE 1: BASE SYSTEM SETUP
# ═══════════════════════════════════════════════════════════════
RUN echo -e "${C_CYAN}[STAGE 1/7] Updating system & installing base packages...${C_RESET}" && \
    apt-get update -y || (sleep 5 && apt-get update -y) && \
    apt-get install -y --no-install-recommends \
    # System essentials
    openssh-server sudo curl wget git vim nano htop tmux \
    zip unzip tar rsync net-tools iproute2 iputils-ping dnsutils \
    # Build tools
    build-essential cmake pkg-config \
    # Python ecosystem
    python3 python3-pip python3-venv python3-dev \
    # Certificates & crypto
    ca-certificates gnupg lsb-release \
    software-properties-common \
    # Locale & timezone
    locales tzdata \
    # Utilities
    cron bash-completion man-db jq less file passwd \
    openssh-client sqlite3 \
    # Libraries
    make libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    # Process management
    supervisor nginx \
    # VPN dependencies
    wireguard-tools wireguard iptables ipset \
    # Network tools
    socat netcat-openbsd proxychains4 \
    # Chrome/FlareSolverr deps (optional)
    fonts-liberation libappindicator3-1 libasound2 \
    libatk-bridge2.0-0 libnspr4 libnss3 libxss1 \
    xdg-utils libgbm1 libu2f-udev \
    # Logging
    rsyslog logrotate && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/* && \
    echo -e "${C_GREEN}[✓] Base packages installed${C_RESET}"

# ═══════════════════════════════════════════════════════════════
#  STAGE 2: PYTHON ENVIRONMENT
# ═══════════════════════════════════════════════════════════════
RUN echo -e "${C_CYAN}[STAGE 2/7] Setting up Python environment...${C_RESET}" && \
    curl -fsSL https://pyenv.run | bash && \
    echo -e "${C_GREEN}[✓] pyenv installed${C_RESET}"

ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

RUN pyenv install 3.13 && pyenv global 3.13 && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    bcrypt flask requests gunicorn psutil speedtest-cli \
    cryptography pyOpenSSL && \
    echo -e "${C_GREEN}[✓] Python 3.13 + packages installed${C_RESET}"

# ═══════════════════════════════════════════════════════════════
#  STAGE 3: INSTALL SERVICES
# ═══════════════════════════════════════════════════════════════

# ─── ttyd (Web Terminal) ───
RUN echo -e "${C_CYAN}[STAGE 3/7] Installing ttyd...${C_RESET}" && \
    arch="$(dpkg --print-architecture)" && \
    case "$arch" in amd64) t=x86_64;; arm64) t=aarch64;; *) t="$arch";; esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${t}" \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd && \
    echo -e "${C_GREEN}[✓] ttyd installed${C_RESET}"

# ─── Cloudflared ───
RUN echo -e "${C_CYAN}Installing Cloudflared...${C_RESET}" && \
    curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared && \
    echo -e "${C_GREEN}[✓] Cloudflared installed${C_RESET}"

# ─── Xray (V2Ray) ───
RUN echo -e "${C_CYAN}Installing Xray...${C_RESET}" && \
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install && \
    echo -e "${C_GREEN}[✓] Xray installed${C_RESET}"

# ─── Shadowsocks-libev ───
RUN echo -e "${C_CYAN}Installing Shadowsocks...${C_RESET}" && \
    apt-get update && apt-get install -y --no-install-recommends shadowsocks-libev && \
    rm -rf /var/lib/apt/lists/* && \
    echo -e "${C_GREEN}[✓] Shadowsocks installed${C_RESET}"

# ─── 3proxy (SOCKS5 + HTTP Proxy) ───
RUN echo -e "${C_CYAN}Installing 3proxy...${C_RESET}" && \
    cd /tmp && \
    git clone --depth 1 https://github.com/z3APA3A/3proxy.git && \
    cd 3proxy && \
    make -f Makefile.Linux && \
    make -f Makefile.Linux install && \
    rm -rf /tmp/3proxy && \
    echo -e "${C_GREEN}[✓] 3proxy installed${C_RESET}"

# ─── PufferPanel ───
RUN echo -e "${C_CYAN}Installing PufferPanel...${C_RESET}" && \
    curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | os=ubuntu dist=noble bash && \
    apt-get install -y pufferpanel && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/lib/pufferpanel/email /var/lib/pufferpanel/servers /etc/pufferpanel && \
    echo '{}' > /var/lib/pufferpanel/email/emails.json && \
    echo -e "${C_GREEN}[✓] PufferPanel installed${C_RESET}"

# ═══════════════════════════════════════════════════════════════
#  STAGE 4: CONFIGURATION FILES
# ═══════════════════════════════════════════════════════════════
RUN echo -e "${C_CYAN}[STAGE 4/7] Creating configuration files...${C_RESET}"

# ─── PufferPanel Config ───
COPY <<EOF /etc/pufferpanel/config.json
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
EOF
RUN cp /etc/pufferpanel/config.json /var/lib/pufferpanel/config.json

# ─── Xray Config (VMess + VLESS + Trojan) ───
COPY <<EOF /etc/xray/config.json
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "tag": "vmess-ws",
      "port": 10086,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            "alterId": 0,
            "security": "auto"
          }
        ],
        "disableInsecureEncryption": false
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/v2ray"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "tag": "vless-ws",
      "port": 10087,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "tag": "trojan-ws",
      "port": 10088,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "ELMINYAWE"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
RUN mkdir -p /var/log/xray

# ─── Shadowsocks Config ───
COPY <<EOF /etc/shadowsocks-libev/config.json
{
    "server": "0.0.0.0",
    "server_port": 8388,
    "password": "ELMINYAWE",
    "timeout": 300,
    "method": "aes-256-gcm",
    "fast_open": true,
    "reuse_port": true,
    "no_delay": true
}
EOF

# ─── 3proxy Config (SOCKS5 + HTTP Proxy) ───
COPY <<EOF /etc/3proxy/3proxy.cfg
# 3proxy configuration
auth none
allow *

# SOCKS5 Proxy
socks -p1080

# HTTP Proxy
proxy -p8118

# Admin interface (optional)
# admin -p8082
EOF
RUN mkdir -p /etc/3proxy

# ─── SSH Config ───
RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?Port.*/Port 22/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 10/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 3/' /etc/ssh/sshd_config && \
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config && \
    echo "GatewayPorts yes" >> /etc/ssh/sshd_config

# ─── Nginx Config (Reverse Proxy) ───
COPY <<EOF /etc/nginx/nginx.conf
user root;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log warn;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    server {
        listen 9090;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        location /terminal/ {
            proxy_pass http://127.0.0.1:8081/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_read_timeout 86400;
        }

        location /api/ {
            proxy_pass http://127.0.0.1:5001/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://127.0.0.1:5001/health;
            access_log off;
        }
    }
}
EOF

# ═══════════════════════════════════════════════════════════════
#  STAGE 5: APPLICATION CODE
# ═══════════════════════════════════════════════════════════════
RUN echo -e "${C_CYAN}[STAGE 5/7] Creating application code...${C_RESET}"
RUN mkdir -p /app /var/log/services

# ─── Flask API ───
COPY <<EOF /app/api.py
#!/usr/bin/env python3
"""ELMINYAWE Server API - Advanced Status & Control Panel"""

from flask import Flask, jsonify, request
import os
import socket
import psutil
import json
from datetime import datetime

app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False

# ─── Helpers ───
def get_system_stats():
    """Get current system statistics"""
    try:
        cpu = psutil.cpu_percent(interval=0.5)
        mem = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        net = psutil.net_io_counters()

        return {
            "cpu_percent": cpu,
            "memory": {
                "total_gb": round(mem.total / (1024**3), 2),
                "used_gb": round(mem.used / (1024**3), 2),
                "free_gb": round(mem.free / (1024**3), 2),
                "percent": mem.percent
            },
            "disk": {
                "total_gb": round(disk.total / (1024**3), 2),
                "used_gb": round(disk.used / (1024**3), 2),
                "free_gb": round(disk.free / (1024**3), 2),
                "percent": round((disk.used / disk.total) * 100, 1)
            },
            "network": {
                "bytes_sent_mb": round(net.bytes_sent / (1024**2), 2),
                "bytes_recv_mb": round(net.bytes_recv / (1024**2), 2)
            },
            "uptime_seconds": int(psutil.boot_time()),
            "hostname": socket.gethostname(),
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        return {"error": str(e)}

def get_service_status():
    """Check status of all services"""
    services = {
        "ssh": {"port": 22, "name": "SSH Server"},
        "ttyd": {"port": 8081, "name": "Web Terminal"},
        "api": {"port": 5001, "name": "Flask API"},
        "pufferpanel": {"port": 8080, "name": "PufferPanel"},
        "nginx": {"port": 9090, "name": "Nginx Proxy"},
        "xray": {"port": 10086, "name": "V2Ray/Xray"},
        "shadowsocks": {"port": 8388, "name": "Shadowsocks"},
        "socks5": {"port": 1080, "name": "SOCKS5 Proxy"},
        "http_proxy": {"port": 8118, "name": "HTTP Proxy"}
    }

    status = {}
    for key, info in services.items():
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('127.0.0.1', info['port']))
            sock.close()
            status[key] = {
                "name": info['name'],
                "port": info['port'],
                "status": "running" if result == 0 else "stopped",
                "emoji": "🟢" if result == 0 else "🔴"
            }
        except Exception as e:
            status[key] = {"name": info['name'], "port": info['port'], "status": f"error: {e}", "emoji": "⚠️"}

    return status

def get_cloudflare_urls():
    """Read Cloudflare tunnel URLs from log files"""
    import re
    urls = {}
    log_files = {
        "ttyd": "/tmp/cf_ttyd.log",
        "api": "/tmp/cf_api.log",
        "v2ray": "/tmp/cf_v2ray.log",
        "nginx": "/tmp/cf_nginx.log",
        "vless": "/tmp/cf_vless.log",
        "trojan": "/tmp/cf_trojan.log"
    }

    for name, path in log_files.items():
        try:
            with open(path, 'r') as f:
                content = f.read()
                match = re.search(r'https://[a-z0-9\-]+\.trycloudflare\.com', content)
                urls[name] = match.group(0) if match else "Waiting..."
        except:
            urls[name] = "Not available"

    return urls

# ─── Routes ───
@app.route('/')
def home():
    """Main status page"""
    return jsonify({
        "service": "ELMINYAWE SERVER v2.0",
        "status": "operational",
        "timestamp": datetime.utcnow().isoformat(),
        "hostname": socket.gethostname(),
        "system": get_system_stats(),
        "services": get_service_status(),
        "cloudflare_tunnels": get_cloudflare_urls()
    })

@app.route('/health')
def health():
    """Simple health check"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/services')
def services():
    """Detailed service status"""
    return jsonify(get_service_status())

@app.route('/system')
def system():
    """System statistics"""
    return jsonify(get_system_stats())

@app.route('/proxy-info')
def proxy_info():
    """VPN/Proxy configuration for clients"""
    cf_urls = get_cloudflare_urls()

    return jsonify({
        "ssh_tunnel": {
            "protocol": "SSH",
            "description": "Connect via SSH to create SOCKS5 proxy",
            "host": os.environ.get("RAILWAY_TCP_PROXY_DOMAIN", "Use Railway TCP Proxy"),
            "port": os.environ.get("RAILWAY_TCP_PROXY_PORT", "22"),
            "username": "root",
            "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE"),
            "local_socks5_port": 1080,
            "netmod_settings": {
                "protocol": "SSH",
                "host": "<Railway TCP Proxy Host>",
                "port": "<Railway TCP Proxy Port>",
                "username": "root",
                "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE")
            }
        },
        "vmess": {
            "protocol": "VMess",
            "description": "VMess over WebSocket with TLS",
            "cloudflare_url": cf_urls.get("v2ray", "Waiting..."),
            "port": 443,
            "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            "alterId": 0,
            "security": "auto",
            "network": "ws",
            "path": "/v2ray",
            "tls": True,
            "sni": cf_urls.get("v2ray", "").replace("https://", "") if cf_urls.get("v2ray", "").startswith("https://") else "",
            "netmod_settings": {
                "protocol": "VMess",
                "address": cf_urls.get("v2ray", ""),
                "port": 443,
                "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                "network": "WebSocket",
                "path": "/v2ray",
                "tls": True
            }
        },
        "vless": {
            "protocol": "VLESS",
            "description": "VLESS over WebSocket with TLS",
            "cloudflare_url": cf_urls.get("vless", "Waiting..."),
            "port": 443,
            "uuid": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
            "network": "ws",
            "path": "/vless",
            "tls": True,
            "netmod_settings": {
                "protocol": "VLESS",
                "address": cf_urls.get("vless", ""),
                "port": 443,
                "uuid": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
                "network": "WebSocket",
                "path": "/vless",
                "tls": True
            }
        },
        "trojan": {
            "protocol": "Trojan",
            "description": "Trojan over WebSocket with TLS",
            "cloudflare_url": cf_urls.get("trojan", "Waiting..."),
            "port": 443,
            "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE"),
            "network": "ws",
            "path": "/trojan",
            "tls": True,
            "netmod_settings": {
                "protocol": "Trojan",
                "address": cf_urls.get("trojan", ""),
                "port": 443,
                "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE"),
                "network": "WebSocket",
                "path": "/trojan",
                "tls": True
            }
        },
        "shadowsocks": {
            "protocol": "Shadowsocks",
            "description": "Shadowsocks proxy",
            "port": 8388,
            "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE"),
            "method": "aes-256-gcm",
            "netmod_settings": {
                "protocol": "Shadowsocks",
                "port": 8388,
                "password": os.environ.get("ROOT_PASSWORD", "ELMINYAWE"),
                "method": "aes-256-gcm"
            }
        },
        "socks5": {
            "protocol": "SOCKS5",
            "description": "Direct SOCKS5 proxy (no encryption)",
            "port": 1080,
            "auth": "none",
            "netmod_settings": {
                "protocol": "SOCKS5",
                "port": 1080
            }
        },
        "http_proxy": {
            "protocol": "HTTP",
            "description": "HTTP proxy (no encryption)",
            "port": 8118,
            "auth": "none"
        }
    })

@app.route('/speedtest')
def speedtest():
    """Run network speed test"""
    try:
        import speedtest
        s = speedtest.Speedtest()
        s.get_best_server()
        download = s.download() / (1024**2)  # Mbps
        upload = s.upload() / (1024**2)      # Mbps
        ping = s.results.ping

        return jsonify({
            "download_mbps": round(download, 2),
            "upload_mbps": round(upload, 2),
            "ping_ms": round(ping, 2),
            "server": s.results.server.get("name", "Unknown"),
            "timestamp": datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e), "message": "Speedtest failed. Try again later."})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)
EOF

# ═══════════════════════════════════════════════════════════════
#  STAGE 6: SCRIPTS
# ═══════════════════════════════════════════════════════════════
RUN echo -e "${C_CYAN}[STAGE 6/7] Creating utility scripts...${C_RESET}"

# ─── Admin Setup Script ───
COPY <<'EOF' /usr/local/bin/setup-admin.sh
#!/usr/bin/env bash
set -e

echo -e "\033[1;36m[ADMIN] Setting up root password...\033[0m"
echo "root:${ROOT_PASSWORD}" | chpasswd

echo -e "\033[1;36m[ADMIN] Waiting for PufferPanel database...\033[0m"
for i in {1..60}; do
    if sqlite3 /var/lib/pufferpanel/pufferpanel.db ".tables" 2>/dev/null | grep -q "users"; then
        echo -e "\033[1;32m[ADMIN] ✓ Database ready\033[0m"
        break
    fi
    sleep 2
done

python3 << 'PYEOF'
import sqlite3, bcrypt, sys, os

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
        print("✅ Admin User created.")
    else:
        print("ℹ️  Admin User already exists.")

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
        print("✅ Admin permissions granted!")
    else:
        c.execute("UPDATE permissions SET admin=1 WHERE user_id=?", (user_id,))
        conn.commit()
        print("✅ Admin permissions updated.")

except Exception as e:
    print(f"❌ Error: {e}")
finally:
    conn.close()
PYEOF

echo -e "\033[1;32m[ADMIN] ✓ Setup complete\033[0m"
EOF
RUN chmod +x /usr/local/bin/setup-admin.sh

# ─── Service Monitor Script ───
COPY <<'EOF' /usr/local/bin/service-monitor.sh
#!/usr/bin/env bash
# Service health monitor with colored logs

C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_CYAN="\033[1;36m"
C_MAGENTA="\033[1;35m"

log_service() {
    local name="$1"
    local port="$2"
    local status

    if nc -z 127.0.0.1 "$port" 2>/dev/null; then
        status="${C_GREEN}RUNNING${C_RESET}"
    else
        status="${C_RED}STOPPED${C_RESET}"
    fi

    printf "  %-20s Port %-5s %b\n" "$name" "$port" "$status"
}

while true; do
    echo ""
    echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║           🖥️  SERVICE HEALTH MONITOR                         ║${C_RESET}"
    echo -e "${C_CYAN}╠══════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "${C_YELLOW}  Time: $(date '+%Y-%m-%d %H:%M:%S UTC')${C_RESET}"
    echo -e "${C_CYAN}╠══════════════════════════════════════════════════════════════╣${C_RESET}"

    log_service "SSH Server" 22
    log_service "Web Terminal" 8081
    log_service "Flask API" 5001
    log_service "PufferPanel" 8080
    log_service "Nginx Proxy" 9090
    log_service "V2Ray VMess" 10086
    log_service "V2Ray VLESS" 10087
    log_service "V2Ray Trojan" 10088
    log_service "Shadowsocks" 8388
    log_service "SOCKS5 Proxy" 1080
    log_service "HTTP Proxy" 8118

    echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RESET}"

    sleep 30
done
EOF
RUN chmod +x /usr/local/bin/service-monitor.sh

# ─── Info Display Script ───
COPY <<'EOF' /usr/local/bin/show-info.sh
#!/usr/bin/env bash
# Enhanced info display with colored output

C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_MAGENTA="\033[1;35m"
C_CYAN="\033[1;36m"
C_WHITE="\033[1;37m"

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
    echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║${C_WHITE}           🚀 ELMINYAWE SERVER v2.0 - ULTIMATE EDITION                        ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${C_RESET}"

    # Web Terminal
    echo -e "${C_GREEN}  🌐 WEB TERMINAL (ttyd)${C_RESET}"
    echo -e "${C_WHITE}     URL  : ${C_YELLOW}${TTYD_URL:-Waiting for Cloudflare...}${C_RESET}"
    echo -e "${C_WHITE}     User : root${C_RESET}"
    echo -e "${C_WHITE}     Pass : ${C_MAGENTA}${ROOT_PASSWORD}${C_RESET}"
    echo -e "${C_CYAN}  ──────────────────────────────────────────────────────────────────────────${C_RESET}"

    # API
    echo -e "${C_GREEN}  📡 API SERVER${C_RESET}"
    echo -e "${C_WHITE}     Cloudflare: ${C_YELLOW}${API_URL:-Waiting...}${C_RESET}"
    echo -e "${C_WHITE}     Local     : http://localhost:5001${C_RESET}"
    echo -e "${C_WHITE}     Endpoints : /health | /services | /system | /proxy-info | /speedtest${C_RESET}"
    echo -e "${C_CYAN}  ──────────────────────────────────────────────────────────────────────────${C_RESET}"

    # PufferPanel
    echo -e "${C_GREEN}  🎮 PufferPanel${C_RESET}"
    echo -e "${C_WHITE}     Local: http://localhost:8080${C_RESET}"
    echo -e "${C_WHITE}     Nginx: ${C_YELLOW}${NGINX_URL:-Waiting...}${C_RESET}"
    echo -e "${C_WHITE}     Email: ELMINYAWE@localhost.com${C_RESET}"
    echo -e "${C_WHITE}     Pass : ${C_MAGENTA}ELMINYAWE${C_RESET}"
    echo -e "${C_CYAN}  ──────────────────────────────────────────────────────────────────────────${C_RESET}"

    # SSH / SFTP
    echo -e "${C_GREEN}  🔒 SSH / SFTP${C_RESET}"
    echo -e "${C_WHITE}     SSH  : ssh -p 22 root@<host>${C_RESET}"
    echo -e "${C_WHITE}     SFTP : port 5657${C_RESET}"
    echo -e "${C_WHITE}     Pass : ${C_MAGENTA}${ROOT_PASSWORD}${C_RESET}"
    echo -e "${C_CYAN}  ──────────────────────────────────────────────────────────────────────────${C_RESET}"

    # VPN Services
    echo -e "${C_GREEN}  🛡️  VPN / PROXY SERVICES${C_RESET}"
    echo -e "${C_CYAN}  ┌────────────────────────────────────────────────────────────────────────┐${C_RESET}"

    echo -e "${C_CYAN}  │${C_YELLOW}  VMess (WebSocket)${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     URL    : ${C_YELLOW}${V2RAY_URL:-Waiting...}${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Port   : 443 (via Cloudflare TLS)${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     UUID   : ${C_MAGENTA}a1b2c3d4-e5f6-7890-abcd-ef1234567890${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Path   : /v2ray${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Network: WebSocket${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     TLS    : ✅ Enabled${C_RESET}"
    echo -e "${C_CYAN}  ├────────────────────────────────────────────────────────────────────────┤${C_RESET}"

    echo -e "${C_CYAN}  │${C_YELLOW}  VLESS (WebSocket)${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     URL    : ${C_YELLOW}${VLESS_URL:-Waiting...}${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Port   : 443 (via Cloudflare TLS)${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     UUID   : ${C_MAGENTA}b2c3d4e5-f6a7-8901-bcde-f12345678901${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Path   : /vless${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     TLS    : ✅ Enabled${C_RESET}"
    echo -e "${C_CYAN}  ├────────────────────────────────────────────────────────────────────────┤${C_RESET}"

    echo -e "${C_CYAN}  │${C_YELLOW}  Trojan (WebSocket)${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     URL    : ${C_YELLOW}${TROJAN_URL:-Waiting...}${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Port   : 443 (via Cloudflare TLS)${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Pass   : ${C_MAGENTA}${ROOT_PASSWORD}${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Path   : /trojan${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     TLS    : ✅ Enabled${C_RESET}"
    echo -e "${C_CYAN}  ├────────────────────────────────────────────────────────────────────────┤${C_RESET}"

    echo -e "${C_CYAN}  │${C_YELLOW}  Shadowsocks${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Port   : 8388${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Pass   : ${C_MAGENTA}${ROOT_PASSWORD}${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Method : aes-256-gcm${C_RESET}"
    echo -e "${C_CYAN}  ├────────────────────────────────────────────────────────────────────────┤${C_RESET}"

    echo -e "${C_CYAN}  │${C_YELLOW}  SOCKS5 Proxy${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Port   : 1080${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Auth   : None${C_RESET}"
    echo -e "${C_CYAN}  ├────────────────────────────────────────────────────────────────────────┤${C_RESET}"

    echo -e "${C_CYAN}  │${C_YELLOW}  HTTP Proxy${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Port   : 8118${C_RESET}"
    echo -e "${C_CYAN}  │${C_WHITE}     Auth   : None${C_RESET}"
    echo -e "${C_CYAN}  └────────────────────────────────────────────────────────────────────────┘${C_RESET}"

    echo -e "${C_CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "${C_BLUE}  💡 Tip: Visit ${C_YELLOW}/proxy-info${C_BLUE} on the API for Netmod-ready configs${C_RESET}"
    echo -e "${C_BLUE}  💡 Tip: Use ${C_YELLOW}/speedtest${C_BLUE} to check network speed${C_RESET}"
    echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${C_RESET}"

    sleep 35
done
EOF
RUN chmod +x /usr/local/bin/show-info.sh

# ═══════════════════════════════════════════════════════════════
#  STAGE 7: SUPERVISOR CONFIGURATION
# ═══════════════════════════════════════════════════════════════
RUN echo -e "${C_CYAN}[STAGE 7/7] Configuring Supervisor...${C_RESET}"

COPY <<EOF /etc/supervisor/conf.d/services.conf
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
stdout_logfile=/var/log/services/sshd.log
stderr_logfile=/var/log/services/sshd.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:nginx]
command=/usr/sbin/nginx -g 'daemon off;'
autostart=true
autorestart=true
priority=20
stdout_logfile=/var/log/services/nginx.log
stderr_logfile=/var/log/services/nginx.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:ttyd]
command=/usr/local/bin/ttyd --port 8081 --writable --credential "root:%(ENV_ROOT_PASSWORD)s" /bin/bash -l
autostart=true
autorestart=true
priority=30
stdout_logfile=/var/log/services/ttyd.log
stderr_logfile=/var/log/services/ttyd.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:api]
command=bash -c 'export PYENV_ROOT=/root/.pyenv && export PATH=/root/.pyenv/bin:/root/.pyenv/shims:$PATH && eval "$(pyenv init -)" && python3 /app/api.py'
autostart=true
autorestart=true
priority=40
stdout_logfile=/var/log/services/api.log
stderr_logfile=/var/log/services/api.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:xray]
command=/usr/local/bin/xray run -config /etc/xray/config.json
autostart=true
autorestart=true
priority=50
stdout_logfile=/var/log/services/xray.log
stderr_logfile=/var/log/services/xray.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:shadowsocks]
command=ss-server -c /etc/shadowsocks-libev/config.json
autostart=true
autorestart=true
priority=60
stdout_logfile=/var/log/services/shadowsocks.log
stderr_logfile=/var/log/services/shadowsocks.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:3proxy]
command=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
autostart=true
autorestart=true
priority=65
stdout_logfile=/var/log/services/3proxy.log
stderr_logfile=/var/log/services/3proxy.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:pufferpanel]
command=bash -c 'cd /var/lib/pufferpanel && unset PORT && pufferpanel run'
autostart=true
autorestart=true
priority=70
stdout_logfile=/var/log/services/pufferpanel.log
stderr_logfile=/var/log/services/pufferpanel.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:admin-setup]
command=bash -c 'sleep 20 && /usr/local/bin/setup-admin.sh'
autostart=true
autorestart=false
priority=80
stdout_logfile=/var/log/services/admin-setup.log
stderr_logfile=/var/log/services/admin-setup.log

[program:service-monitor]
command=/usr/local/bin/service-monitor.sh
autostart=true
autorestart=true
priority=90
stdout_logfile=/var/log/services/monitor.log
stderr_logfile=/var/log/services/monitor.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

[program:show-info]
command=/usr/local/bin/show-info.sh
autostart=true
autorestart=true
priority=100
stdout_logfile=/var/log/services/show-info.log
stderr_logfile=/var/log/services/show-info.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB

; ─── Cloudflare Tunnels ───
[program:cf-ttyd]
command=bash -c 'sleep 15 && echo "[CF] Starting ttyd tunnel..." && /usr/local/bin/cloudflared tunnel --url http://localhost:8081'
autostart=true
autorestart=true
priority=110
stdout_logfile=/tmp/cf_ttyd.log
stderr_logfile=/tmp/cf_ttyd.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB

[program:cf-api]
command=bash -c 'sleep 18 && echo "[CF] Starting API tunnel..." && /usr/local/bin/cloudflared tunnel --url http://localhost:5001'
autostart=true
autorestart=true
priority=111
stdout_logfile=/tmp/cf_api.log
stderr_logfile=/tmp/cf_api.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB

[program:cf-v2ray]
command=bash -c 'sleep 21 && echo "[CF] Starting V2Ray tunnel..." && /usr/local/bin/cloudflared tunnel --url http://localhost:10086'
autostart=true
autorestart=true
priority=112
stdout_logfile=/tmp/cf_v2ray.log
stderr_logfile=/tmp/cf_v2ray.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB

[program:cf-vless]
command=bash -c 'sleep 24 && echo "[CF] Starting VLESS tunnel..." && /usr/local/bin/cloudflared tunnel --url http://localhost:10087'
autostart=true
autorestart=true
priority=113
stdout_logfile=/tmp/cf_vless.log
stderr_logfile=/tmp/cf_vless.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB

[program:cf-trojan]
command=bash -c 'sleep 27 && echo "[CF] Starting Trojan tunnel..." && /usr/local/bin/cloudflared tunnel --url http://localhost:10088'
autostart=true
autorestart=true
priority=114
stdout_logfile=/tmp/cf_trojan.log
stderr_logfile=/tmp/cf_trojan.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB

[program:cf-nginx]
command=bash -c 'sleep 30 && echo "[CF] Starting Nginx tunnel..." && /usr/local/bin/cloudflared tunnel --url http://localhost:9090'
autostart=true
autorestart=true
priority=115
stdout_logfile=/tmp/cf_nginx.log
stderr_logfile=/tmp/cf_nginx.log
stdout_logfile_maxbytes=5MB
stderr_logfile_maxbytes=5MB
EOF

# ═══════════════════════════════════════════════════════════════
#  FINAL SETUP
# ═══════════════════════════════════════════════════════════════
RUN mkdir -p /var/log/services /var/log/xray /var/log/nginx /var/log/supervisor /app /run/sshd && \
    echo -e "${C_GREEN}[✓] All directories created${C_RESET}"

# ─── Main Entrypoint ───
COPY <<'EOF' /entrypoint.sh
#!/usr/bin/env bash
set -e

C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RESET="\033[0m"

echo ""
echo -e "${C_CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_CYAN}║${C_GREEN}           🚀 ELMINYAWE SERVER v2.0 - BOOTING UP...                           ${C_CYAN}║${C_RESET}"
echo -e "${C_CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${C_RESET}"
echo ""

echo -e "${C_YELLOW}[INIT] Setting up environment...${C_RESET}"
echo "root:${ROOT_PASSWORD}" | chpasswd

export PYENV_ROOT="/root/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
eval "$(pyenv init -)"

mkdir -p /run/sshd /var/log/services /var/log/xray /var/log/nginx /var/log/supervisor /app

echo -e "${C_GREEN}[INIT] ✓ Environment ready${C_RESET}"
echo -e "${C_GREEN}[INIT] ✓ Starting Supervisor...${C_RESET}"
echo ""

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
EOF
RUN chmod +x /entrypoint.sh

EXPOSE 5001 8080 8081 22 5657 8388 9090 10086 10087 10088 1080 8118

CMD ["/entrypoint.sh"]
