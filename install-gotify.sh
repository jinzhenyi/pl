#!/bin/bash

# 青龙面板s390x架构安装脚本
# 无需Docker，从源码编译Node.js

set -e

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# 检查系统架构
check_architecture() {
    local arch=$(uname -m)
    if [ "$arch" != "s390x" ]; then
        log_warn "检测到系统架构: $arch"
        log_warn "本脚本专为s390x架构优化，其他架构可能不兼容"
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
        --shared
    
    # 编译安装
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
        log_info "Node.js 安装成功"
    else
        log_error "Node.js 安装失败"
        exit 1
    fi
}

# 安装npm
install_npm() {
    log_info "安装npm..."
    
    # 安装npm
    curl -L https://www.npmjs.com/install.sh | sh
    
    if command -v npm &> /dev/null; then
        log_info "npm 安装成功"
    else
        log_error "npm 安装失败"
        exit 1
    fi
}

# 安装PM2
install_pm2() {
    log_info "安装PM2..."
    
    sudo npm install -g pm2
    
    if command -v pm2 &> /dev/null; then
        log_info "PM2 安装成功"
    else
        log_error "PM2 安装失败"
        exit 1
    fi
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
    
    log_info "服务启动完成"
}

# 显示安装结果
show_result() {
    log_info "========== 安装完成 =========="
    log_info "青龙面板访问地址: http://服务器IP:5700"
    log_info "安装目录: $HOME/ql"
    log_info "数据目录: $HOME/ql/data"
    log_info "使用 pm2 status 查看服务状态"
}

# 主安装函数
main() {
    log_info "开始安装青龙面板 (s390x架构)"
    
    # 检查架构
    check_architecture
    
    # 安装依赖
    install_dependencies
    
    # 安装Node.js
    install_nodejs
    
    # 安装npm
    install_npm
    
    # 安装PM2
    install_pm2
    
    # 安装青龙面板
    install_qinglong
    
    # 配置服务
    setup_service
    
    # 显示结果
    show_result
    
    log_info "安装完成!"
}

# 直接运行主函数，无需交互
main