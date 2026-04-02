#!/bin/bash

# 打印炫酷的启动 Logo
echo "========================================================"
echo "🚀 光储大师 (Quote Master) MVP 生产环境一键部署引擎启动 🚀"
echo "========================================================"

# 1. 询问你的域名
read -p "🌐 请输入您已解析到本服务器的域名 (例如: api.yourdomain.com): " DOMAIN_NAME
read -p "📧 请输入您的管理员邮箱 (用于申请 HTTPS 证书): " ADMIN_EMAIL

# 2. 获取当前用户和路径
APP_DIR=$(pwd)
CURRENT_USER=$(whoami)

echo "📦 正在更新系统并安装底层依赖 (Nginx, Certbot, Python3-venv)..."
sudo apt update
sudo apt install -y python3-pip python3-venv nginx certbot python3-certbot-nginx

echo "🐍 正在创建 Python 虚拟环境并安装核心库..."
python3 -m venv venv
$APP_DIR/venv/bin/pip install --upgrade pip
$APP_DIR/venv/bin/pip install -r requirements.txt

echo "⚙️ 正在配置 Systemd 守护进程 (让 FastAPI 在后台死心塌地运行)..."
sudo bash -c "cat <<EOF > /etc/systemd/system/pv_ess.service
[Unit]
Description=Quote Master FastAPI Backend
After=network.target

[Service]
User=$CURRENT_USER
Group=www-data
WorkingDirectory=$APP_DIR
Environment=\"PATH=$APP_DIR/venv/bin\"
# 使用 Uvicorn 启动，并开启 2 个 Worker 抗并发
ExecStart=$APP_DIR/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 2

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl start pv_ess
sudo systemctl enable pv_ess

echo "🛡️ 正在配置 Nginx 反向代理..."
sudo bash -c "cat <<EOF > /etc/nginx/sites-available/pv_ess
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }
}
EOF"

sudo ln -sf /etc/nginx/sites-available/pv_ess /etc/nginx/sites-enabled/
# 删除 Nginx 默认的霸道欢迎页
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

echo "🔐 正在呼叫 Let's Encrypt 为您的域名签发最高级别的 HTTPS 证书..."
sudo certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos -m $ADMIN_EMAIL

echo "========================================================"
echo "🎉 部署大功告成！光储大师后端已在云端霸气上线！"
echo "👉 请在浏览器中访问: https://$DOMAIN_NAME/docs"
echo "========================================================"