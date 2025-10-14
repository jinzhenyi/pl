#!/bin/bash

# Docker自动安装脚本 for s390x架构
# GitHub: https://github.com/yourusername/your-repo

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统架构
check_architecture() {
    local arch
    arch=$(uname -m)
    if [ "$arch" != "s390x" ]; then
        log_warning "检测到系统架构: $arch"
        log_warning "本脚本专为s390x架构优化，其他架构可能不兼容"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "检测到s390x架构，继续安装..."
    fi
}

# 检查root权限
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "不建议使用root用户直接运行Docker"
        log_warning "建议使用普通用户运行，脚本会自动配置sudo权限"
    fi
}

# 更新系统
update_system() {
    log_info "开始更新系统包..."
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    log_success "系统更新完成"
}

# 安装基础依赖
install_dependencies() {
    log_info "安装Docker依赖包..."
    
    sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        git \
        wget \
        ufw
    
    log_success "依赖包安装完成"
}

# 添加Docker仓库
setup_docker_repo() {
    log_info "设置Docker官方仓库..."
    
    # 创建目录
    sudo mkdir -p /etc/apt/keyrings
    
    # 下载并添加GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # 添加仓库
    echo "deb [arch=s390x signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包列表
    sudo apt update
    log_success "Docker仓库设置完成"
}

# 安装Docker引擎
install_docker_engine() {
    log_info "安装Docker引擎..."
    
    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    log_success "Docker引擎安装完成"
}

# 配置Docker服务
setup_docker_service() {
    log_info "配置Docker服务..."
    
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo systemctl status docker --no-pager
    
    log_success "Docker服务配置完成"
}

# 配置用户权限
setup_user_permissions() {
    log_info "配置用户权限..."
    
    local current_user
    current_user=$(whoami)
    
    if [ "$current_user" != "root" ]; then
        sudo usermod -aG docker "$current_user"
        log_success "用户 $current_user 已添加到docker组"
    else
        log_warning "当前为root用户，跳过用户组配置"
    fi
}

# 安装Docker Compose
install_docker_compose() {
    log_info "安装Docker Compose..."
    
    # 获取最新版本
    local compose_version
    compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    log_info "下载Docker Compose $compose_version"
    
    sudo curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose 安装完成"
}

# 验证安装
verify_installation() {
    log_info "验证Docker安装..."
    
    echo -e "\n${BLUE}=== Docker版本信息 ===${NC}"
    docker --version
    docker-compose --version
    
    echo -e "\n${BLUE}=== Docker系统信息 ===${NC}"
    sudo docker info | grep -E "Server Version|Operating System|Architecture|Total Memory"
    
    echo -e "\n${BLUE}=== 测试Docker运行 ===${NC}"
    sudo docker run --rm hello-world | grep -A 10 "Hello from Docker"
    
    log_success "验证完成"
}

# 显示使用说明
show_usage() {
    echo -e "\n${GREEN}=== Docker安装完成 ===${NC}"
    echo -e "请执行以下命令使组权限生效:"
    echo -e "  ${YELLOW}newgrp docker${NC} 或重新登录"
    echo -e "\n常用命令:"
    echo -e "  ${YELLOW}docker ps${NC}           # 查看容器"
    echo -e "  ${YELLOW}docker images${NC}       # 查看镜像"
    echo -e "  ${YELLOW}docker --help${NC}       # 查看帮助"
    echo -e "  ${YELLOW}sudo systemctl status docker${NC}  # 查看服务状态"
}

# 主函数
main() {
    echo -e "${GREEN}"
    cat << "EOF"
  ____             _             
 |  _ \  ___   ___| | _____ _ __ 
 | | | |/ _ \ / __| |/ / _ \ '__|
 | |_| | (_) | (__|   <  __/ |   
 |____/ \___/ \___|_|\_\___|_|   
 s390x架构自动安装脚本
EOF
    echo -e "${NC}"
    
    # 执行安装步骤
    check_architecture
    check_root
    update_system
    install_dependencies
    setup_docker_repo
    install_docker_engine
    setup_docker_service
    setup_user_permissions
    install_docker_compose
    verify_installation
    show_usage
}

# 脚本入口
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0"
    echo "自动安装Docker和依赖 (s390x架构)"
    exit 0
fi

main