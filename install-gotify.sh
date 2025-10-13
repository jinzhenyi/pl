#!/bin/bash

# Gotify Server 一键安装脚本 for s390x Ubuntu
# 作者: [jinzhenyi]
# GitHub: [https：//github.jinzhenyi.pl]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 输出彩色信息
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统架构
check_architecture() {
    local arch=$(uname -m)
    if [ "$arch" != "s390x" ]; then
        log_warn "检测到系统架构: $arch"
        log_warn "本脚本主要针对 s390x 架构测试，其他架构可能存在问题"
    else
        log_info "系统架构: s390x"
    fi
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户或 sudo 运行此脚本"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."
    apt update
    apt install -y curl wget git docker.io docker-compose ufw
}

# 安装Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装"
        return
    fi

    log_info "安装 Docker..."
    
    # 安装Docker依赖
    apt update
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

    # 添加Docker官方GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 添加Docker仓库
    echo "deb [arch=s390x signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io

    # 启动Docker服务
    systemctl start docker
    systemctl enable docker

    log_info "Docker 安装完成"
}

# 生成随机密码
generate_password() {
    local password=$(openssl rand -base64 16 2>/dev/null || date +%s | sha256sum | base64 | head -c 16)
    echo "$password"
}

# 创建Gotify配置
setup_gotify() {
    local install_dir="/opt/gotify"
    local password=$(generate_password)
    
    log_info "创建安装目录: $install_dir"
    mkdir -p "$install_dir"
    cd "$install_dir"

    # 创建 docker-compose.yml
    log_info "创建 Docker Compose 配置..."
    cat > docker-compose.yml << EOF
version: '3'

services:
  gotify:
    image: gotify/server
    container_name: gotify
    ports:
      - "80:80"
    environment:
      - GOTIFY_DEFAULTUSER_PASS=${password}
    volumes:
      - gotify-data:/app/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  gotify-data:
EOF

    # 创建环境文件
    echo "GOTIFY_PASSWORD=${password}" > .env
    chmod 600 .env

    log_info "Gotify 配置创建完成"
}

# 配置防火墙
setup_firewall() {
    if command -v ufw &> /dev/null; then
        log_info "配置防火墙..."
        ufw allow ssh
        ufw allow 80/tcp
        echo "y" | ufw enable
        log_info "防火墙已配置，开放端口: 22(SSH), 80(HTTP)"
    else
        log_warn "未找到 ufw，跳过防火墙配置"
    fi
}

# 启动Gotify服务
start_gotify() {
    log_info "启动 Gotify 服务..."
    cd /opt/gotify
    
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker ps | grep -q gotify; then
        log_info "Gotify 服务启动成功"
    else
        log_error "Gotify 服务启动失败"
        exit 1
    fi
}

# 显示安装信息
show_installation_info() {
    local password
    password=$(grep GOTIFY_PASSWORD /opt/gotify/.env | cut -d '=' -f2)
    local server_ip=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
    
    echo
    log_info "=== Gotify 安装完成 ==="
    echo
    echo -e "${GREEN}访问地址:${NC} http://${server_ip}"
    echo -e "${GREEN}用户名:${NC} admin"
    echo -e "${GREEN}密码:${NC} ${password}"
    echo
    echo -e "${YELLOW}重要提示:${NC}"
    echo "1. 请立即登录并更改默认密码"
    echo "2. 密码文件保存在: /opt/gotify/.env"
    echo "3. 查看日志: docker logs gotify"
    echo "4. 停止服务: cd /opt/gotify && docker-compose down"
    echo "5. 重启服务: cd /opt/gotify && docker-compose restart"
    echo
}

# 主函数
main() {
    log_info "开始安装 Gotify Server..."
    
    check_root
    check_architecture
    install_dependencies
    install_docker
    setup_gotify
    setup_firewall
    start_gotify
    show_installation_info
    
    log_info "安装完成！"
}

# 显示使用说明
usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --version  显示版本信息"
    echo
    echo "示例:"
    echo "  curl -sSL https://raw.githubusercontent.com/yourusername/yourrepo/main/install-gotify.sh | bash"
    echo "  或"
    echo "  wget -qO- https://raw.githubusercontent.com/yourusername/yourrepo/main/install-gotify.sh | bash"
}

# 参数处理
case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
    -v|--version)
        echo "Gotify 一键安装脚本 v1.0"
        exit 0
        ;;
    *)
        main
        ;;
esac