#!/bin/bash

# 青龙面板s390x架构安装脚本
# GitHub: https://github.com/your-repo/install-qinglong-s390x

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
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
        log_warn "本脚本专为s390x架构优化，其他架构可能不兼容"
        read -p "是否继续? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_info "检测到s390x架构，继续安装..."
    fi
}

# 安装系统依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y \
        git \
        curl \
        wget \
        python3 \
        python3-pip \
        make \
        gcc \
        g++ \
        build-essential \
        sqlite3 \
        libsqlite3-dev \
        openssl \
        libssl-dev
}

# 编译安装Node.js
install_nodejs() {
    log_info "开始编译安装Node.js..."
    
    local node_version="18.20.4"
    local install_dir="/usr/local"
    
    # 创建临时目录
    cd ~
    mkdir -p temp_node_build
    cd temp_node_build
    
    # 下载Node.js源码
    log_info "下载Node.js v${node_version} 源码..."
    wget -O node-v${node_version}.tar.gz \
        https://nodejs.org/dist/v${node_version}/node-v${node_version}.tar.gz
    
    # 解压
    tar -xzf node-v${node_version}.tar.gz
    cd node-v${node_version}
    
    # 配置编译选项
    log_info "配置编译参数..."
    ./configure \
        --prefix=${install_dir} \
        --with-intl=full-icu \
        --shared \
        --without-npm
    
    # 编译安装（使用所有可用的CPU核心）
    local core_count=$(nproc)
    log_info "开始编译Node.js（使用${core_count}个CPU核心）..."
    make -j${core_count}
    
    log_info "安装Node.js..."
    sudo make install
    
    # 清理临时文件
    cd ~
    rm -rf temp_node_build
    
    # 验证安装
    if command -v node &> /dev/null; then
        log_info "Node.js 安装成功: $(node -v)"
    else
        log_error "Node.js 安装失败"
        exit 1
    fi
}

# 安装npm和PM2
install_npm_pm2() {
    log_info "安装npm和PM2..."
    
    # 安装npm
    curl -L https://www.npmjs.com/install.sh | sh
    
    # 安装PM2
    sudo npm install -g pm2
    log_info "PM2 安装成功: $(pm2 -v)"
}

# 安装青龙面板
install_qinglong() {
    log_info "安装青龙面板..."
    
    local ql_dir="$HOME/ql"
    
    # 创建目录
    mkdir -p ${ql_dir}
    cd ${ql_dir}
    
    # 克隆青龙面板
    if [ ! -d "qinglong" ]; then
        git clone https://github.com/whyour/qinglong.git
    else
        log_info "青龙面板已存在，跳过克隆"
    fi
    
    cd qinglong
    
    # 安装依赖
    log_info "安装青龙面板依赖..."
    npm config set registry https://registry.npmmirror.com
    npm install --production
    
    # 创建数据目录
    mkdir -p ${ql_dir}/data
    
    # 创建配置文件
    cat > ${ql_dir}/config.yaml << 'EOF'
# 青龙面板配置文件
scripts:
  type: database
  database:
    dialect: sqlite
    storage: ../data/db.sqlite

logs:
  level: info

server:
  port: 5700
  host: 0.0.0.0
EOF

    log_info "青龙面板安装完成"
}

# 配置和启动服务
setup_service() {
    log_info "配置和启动服务..."
    
    local ql_dir="$HOME/ql"
    
    # 创建启动脚本
    cat > ${ql_dir}/start-qinglong.sh << 'EOF'
#!/bin/bash
cd ~/ql/qinglong
npm start
EOF

    chmod +x ${ql_dir}/start-qinglong.sh
    
    # 使用PM2启动
    pm2 start ${ql_dir}/start-qinglong.sh --name qinglong
    
    # 保存PM2配置
    pm2 save
    
    # 设置开机自启
    if command -v systemctl &> /dev/null; then
        pm2 startup
    fi
    
    log_info "服务启动完成"
}

# 显示安装结果
show_result() {
    local server_ip=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    echo
    log_info "========== 安装完成 =========="
    log_info "青龙面板访问地址: http://${server_ip}:5700"
    log_info "安装目录: $HOME/ql"
    log_info "数据目录: $HOME/ql/data"
    log_info "PM2管理命令:"
    echo "  pm2 status qinglong    # 查看状态"
    echo "  pm2 stop qinglong      # 停止服务"
    echo "  pm2 restart qinglong   # 重启服务"
    echo "  pm2 logs qinglong      # 查看日志"
    echo
    log_warn "首次访问需要完成初始化设置"
    log_warn "如果无法访问，请检查防火墙设置:"
    echo "  sudo ufw allow 5700"
}

# 主安装函数
main() {
    log_info "开始安装青龙面板 (s390x架构)"
    log_info "当前时间: $(date)"
    
    # 检查架构
    check_architecture
    
    # 安装依赖
    install_dependencies
    
    # 安装Node.js
    install_nodejs
    
    # 安装npm和PM2
    install_npm_pm2
    
    # 安装青龙面板
    install_qinglong
    
    # 配置服务
    setup_service
    
    # 显示结果
    show_result
    
    log_info "安装完成!"
}

# 显示警告信息 
cho
log_warn "此脚本将在s390x架构服务器上安装青龙面板"
log_warn "安装过程可能需要30分钟到2小时"
log_warn "请确保网络连接稳定"
echo

read -p "是否继续安装? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    main
else
    log_info "安装已取消"
    exit 0
fi