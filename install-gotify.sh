 #!/bin/bash

set -e

echo "开始安装青龙面板 (s390x架构)"

# 安装依赖
sudo apt update
sudo apt install -y git curl wget python3 make gcc g++ build-essential

# 编译安装Node.js
cd ~
wget https://nodejs.org/dist/v18.20.4/node-v18.20.4.tar.gz
tar -xzf node-v18.20.4.tar.gz
cd node-v18.20.4
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install

# 安装npm和PM2
curl -L https://www.npmjs.com/install.sh | sh
npm install -g pm2

# 安装青龙面板
mkdir -p ~/ql
cd ~/ql
git clone https://github.com/whyour/qinglong.git
cd qinglong
npm config set registry https://registry.npmmirror.com
npm install --production

# 启动服务
pm2 start ~/ql/qinglong/package.json --name qinglong
pm2 save

echo "安装完成！访问 http://服务器IP:5700"