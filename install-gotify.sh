#!/bin/bash

# Gotify Server 源码编译安装脚本 for s390x Ubuntu
set -e

echo "正在通过源码编译安装 Gotify Server..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 用户或 sudo 运行此脚本"
    exit 1
fi

# 安装依赖
log_info "安装系统依赖..."
apt update
apt install -y wget curl git build-essential sqlite3

# 安装 Go 语言
install_go() {
    if command -v go &> /dev/null; then
        log_info "Go 已安装: $(go version)"
        return
    fi

    log_info "安装 Go 语言环境..."
    
    # 下载 Go for s390x
    GO_VERSION="1.21.0"
    wget https://golang.org/dl/go${GO_VERSION}.linux-s390x.tar.gz
    
    # 删除旧版本并安装新版本
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go${GO_VERSION}.linux-s390x.tar.gz
    rm go${GO_VERSION}.linux-s390x.tar.gz
    
    # 设置环境变量
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    echo 'export GOPATH=$HOME/go' >> /etc/profile
    source /etc/profile
    
    # 验证安装
    if command -v go &> /dev/null; then
        log_info "Go 安装成功: $(go version)"
    else
        log_error "Go 安装失败"
        exit 1
    fi
}

install_go

# 创建专用用户
if ! id "gotify" &>/dev/null; then
    log_info "创建 gotify 用户..."
    useradd -r -s /bin/false -d /opt/gotify -m gotify
fi

# 编译 Gotify
log_info "下载并编译 Gotify..."
sudo -u gotify bash << 'EOF'
cd /opt/gotify

# 设置Go环境
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/opt/gotify/go

# 克隆源码
git clone https://github.com/gotify/server.git src
cd src

# 编译
go build -o ../gotify-server

cd ..
EOF

# 创建配置
log_info "创建配置文件..."
cat > /opt/gotify/config.yml << 'EOF'
server:
  listenaddr: ""  # 监听所有地址
  port: 80
  ssl:
    enabled: false
    redirecttohttps: false

database: 
  dialect: sqlite3
  connection: /opt/gotify/data/gotify.db

defaultuser:
  name: admin
  pass: {{GOTIFY_PASSWORD}}
EOF

# 生成随机密码
PASSWORD=$(date +%s | sha256sum | base64 | head -c 16)
sed -i "s/{{GOTIFY_PASSWORD}}/${PASSWORD}/g" /opt/gotify/config.yml

# 创建数据目录
mkdir -p /opt/gotify/data
chown -R gotify:gotify /opt/gotify

# 创建系统服务
log_info "创建系统服务..."
cat > /etc/systemd/system/gotify.service << EOF
[Unit]
Description=Gotify Server
After=network.target

[Service]
Type=simple
User=gotify
Group=gotify
WorkingDirectory=/opt/gotify
ExecStart=/opt/gotify/gotify-server -c /opt/gotify/config.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
log_info "启动 Gotify 服务..."
systemctl daemon-reload
systemctl enable gotify
systemctl start gotify

# 等待服务启动
sleep 5

# 检查服务状态
if systemctl is-active --quiet gotify; then
    log_info "Gotify 服务启动成功"
else
    log_error "Gotify 服务启动失败"
    journalctl -u gotify -n 20 --no-pager
    exit 1
fi

# 显示安装信息
IP=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
echo
log_info "=== 安装完成 ==="
echo
echo -e "${GREEN}访问地址:${NC} http://${IP}"
echo -e "${GREEN}用户名:${NC} admin"
echo -e "${GREEN}密码:${NC} ${PASSWORD}"
echo
echo -e "${YELLOW}管理命令:${NC}"
echo "启动: systemctl start gotify"
echo "停止: systemctl stop gotify"
echo "状态: systemctl status gotify"
echo "日志: journalctl -u gotify -f"
echo
echo -e "${YELLOW}重要提示:${NC}"
echo "1. 请立即登录并更改默认密码"
echo "2. 配置文件: /opt/gotify/config.yml"
echo "3. 数据目录: /opt/gotify/data/"
echo