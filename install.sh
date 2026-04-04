#!/usr/bin/env bash

cd /root

# 定义组件版本
ARGO_VERSION="2026.3.0"
TTYD_VERSION="1.7.7"
SUPERCRONIC_VERSION="0.2.44"

# 1. 下载 Cloudflared (用于内网穿透)
curl -sSL -o /usr/local/bin/cf https://github.com/cloudflare/cloudflared/releases/download/$ARGO_VERSION/cloudflared-linux-amd64
chmod +x /usr/local/bin/cf

# 2. 下载 ttyd (Web 终端)
curl -sSL -o /usr/local/bin/td https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/ttyd.x86_64
chmod +x /usr/local/bin/td

# 3. 下载 Supercronic (用于定时保活任务)
curl -sSL -o /usr/local/bin/sc https://github.com/aptible/supercronic/releases/download/v$SUPERCRONIC_VERSION/supercronic-linux-amd64
chmod +x /usr/local/bin/sc

# --- 配置 Supervisor 服务 ---

# ttyd 启动配置 (使用环境变量中的 USER 和 PASS 进行鉴权)
cat > /etc/supervisor/conf.d/td.conf <<EOF
[program:td]
command=td -p 80 -W -c %(ENV_USER)s:%(ENV_PASS)s bash
autostart=true
autorestart=true
stdout_logfile = /dev/null
stderr_logfile = /dev/null
EOF

# Cloudflared 启动配置
cat > /etc/supervisor/conf.d/cf.conf <<EOF
[program:cf]
command=cf tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token %(ENV_T)s
autostart=true
autorestart=true
stdout_logfile = /dev/null
stderr_logfile = /dev/null
EOF

# --- 保活脚本与 Crontab ---
cat > /usr/local/bin/keepalive.sh <<'EOF'
#!/bin/bash
# 随机休眠防止检测
sleep $((RANDOM % 300))
status=$(curl -o /dev/null -s -w "%{http_code}" $E/status)
echo `date "+%Y-%m-%d %H:%M:%S"` - Status: $status > /tmp/keepalive.log
EOF
chmod +x /usr/local/bin/keepalive.sh

cat > /etc/my-crontab <<EOF
*/5 * * * * /usr/local/bin/keepalive.sh
EOF

# Supercronic 启动配置
cat > /etc/supervisor/conf.d/sc.conf <<EOF
[program:sc]
directory=/etc
command=sc my-crontab
autostart=%(ENV_ENABLE_SC)s
autorestart=true
stdout_logfile = /dev/null
stderr_logfile = /dev/null
EOF