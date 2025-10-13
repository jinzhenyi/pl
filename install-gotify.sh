#!/bin/bash

# Gotify 编译修复脚本
set -e

echo "修复 Gotify 编译问题..."

# 停止服务
systemctl stop gotify 2>/dev/null || true

# 清理旧文件
cd /opt/gotify
rm -rf src go gotify-server

# 重新设置环境
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/opt/gotify/go

# 创建目录结构
mkdir -p go/src go/bin go/pkg
chown -R gotify:gotify /opt/gotify

# 使用 gotify 用户编译
sudo -u gotify bash << 'EOF'
cd /opt/gotify
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/opt/gotify/go

# 克隆源码
git clone https://github.com/gotify/server.git src
cd src

# 显示Go环境
echo "Go 版本: $(go version)"
echo "GOPATH: $GOPATH"
echo "当前目录: $(pwd)"

# 下载依赖
echo "下载依赖..."
go mod download

# 编译
echo "开始编译..."
go build -v -o ../gotify-server

# 检查结果
if [ -f "../gotify-server" ]; then
    echo "编译成功！"
    ls -la ../gotify-server
else
    echo "编译失败！"
    exit 1
fi
EOF

# 设置权限
chmod +x /opt/gotify/gotify-server
chown gotify:gotify /opt/gotify/gotify-server

# 测试运行
echo "测试运行..."
sudo -u gotify /opt/gotify/gotify-server -c /opt/gotify/config.yml --help

# 启动服务
systemctl daemon-reload
systemctl start gotify
systemctl status gotify

echo "修复完成！"