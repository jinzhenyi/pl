#!/bin/bash

# 网页服务器自动部署脚本
# 端口：6666
# 功能：显示"你好，世界"、"Hello, World"和实时时间
# GitHub: https://raw.githubusercontent.com/yourusername/your-repo/main/deploy-web-server.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 变量配置
PORT="6666"
WEB_DIR="/var/www/html-6666"
SERVICE_NAME="web-server-6666"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查root权限
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "正在使用root权限运行"
    else
        log_info "需要sudo权限执行某些操作"
    fi
}

# 安装必要依赖
install_dependencies() {
    log_info "检查并安装必要依赖..."
    
    # 检查是否已安装Python3
    if ! command -v python3 &> /dev/null; then
        log_info "安装Python3..."
        sudo apt update
        sudo apt install -y python3
    fi
    
    # 检查是否已安装curl
    if ! command -v curl &> /dev/null; then
        log_info "安装curl..."
        sudo apt install -y curl
    fi
    
    log_success "依赖检查完成"
}

# 创建网页目录
create_web_directory() {
    log_info "创建网页目录: $WEB_DIR"
    
    sudo mkdir -p "$WEB_DIR"
    sudo chown -R $USER:$USER "$WEB_DIR"
    sudo chmod -R 755 "$WEB_DIR"
    
    log_success "网页目录创建完成"
}

# 生成HTML页面
generate_html_page() {
    log_info "生成HTML页面..."
    
    cat > "$WEB_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>欢迎页面 - 端口6666</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: #333;
        }
        
        .container {
            background: rgba(255, 255, 255, 0.95);
            padding: 3rem;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            text-align: center;
            max-width: 600px;
            width: 90%;
            backdrop-filter: blur(10px);
        }
        
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            background: linear-gradient(45deg, #ff6b6b, #4ecdc4);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .chinese {
            font-size: 2.5rem;
            color: #2c3e50;
            margin-bottom: 1.5rem;
            font-weight: bold;
        }
        
        .english {
            font-size: 2rem;
            color: #34495e;
            margin-bottom: 2rem;
            font-style: italic;
        }
        
        .time-container {
            background: linear-gradient(45deg, #3498db, #9b59b6);
            color: white;
            padding: 1.5rem;
            border-radius: 15px;
            margin: 2rem 0;
            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.2);
        }
        
        #current-time {
            font-size: 2.2rem;
            font-weight: bold;
            letter-spacing: 2px;
        }
        
        .date {
            font-size: 1.2rem;
            margin-top: 0.5rem;
            opacity: 0.9;
        }
        
        .info {
            margin-top: 2rem;
            padding: 1rem;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 4px solid #3498db;
        }
        
        .server-info {
            font-size: 0.9rem;
            color: #7f8c8d;
            margin-top: 1rem;
        }
        
        .animated-text {
            animation: fadeIn 2s ease-in;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 2rem;
                margin: 1rem;
            }
            
            h1 { font-size: 2.2rem; }
            .chinese { font-size: 1.8rem; }
            .english { font-size: 1.5rem; }
            #current-time { font-size: 1.8rem; }
        }
    </style>
</head>
<body>
    <div class="container animated-text">
        <h1>🚀 欢迎访问</h1>
        <div class="chinese">你好，世界！</div>
        <div class="english">Hello, World!</div>
        
        <div class="time-container">
            <div id="current-time">加载中...</div>
            <div class="date" id="current-date"></div>
        </div>
        
        <div class="info">
            <p>这是一个运行在 <strong>端口 6666</strong> 的网页服务器</p>
            <p>页面自动显示当前服务器时间</p>
        </div>
        
        <div class="server-info">
            服务器架构: <span id="server-arch">s390x</span> | 
            部署时间: <span id="deploy-time"></span>
        </div>
    </div>

    <script>
        function updateTime() {
            const now = new Date();
            
            // 格式化时间
            const timeString = now.toLocaleTimeString('zh-CN', { 
                hour12: false,
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit'
            });
            
            const dateString = now.toLocaleDateString('zh-CN', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                weekday: 'long'
            });
            
            // 更新页面元素
            document.getElementById('current-time').textContent = timeString;
            document.getElementById('current-date').textContent = dateString;
            
            // 更新部署时间（首次运行）
            if (!document.getElementById('deploy-time').textContent) {
                document.getElementById('deploy-time').textContent = now.toLocaleString('zh-CN');
            }
        }
        
        // 每秒更新时间
        setInterval(updateTime, 1000);
        updateTime(); // 立即执行一次
        
        // 检测服务器架构（简化版）
        const userAgent = navigator.userAgent;
        if (userAgent.includes('s390x') || userAgent.includes('linux')) {
            document.getElementById('server-arch').textContent = 's390x/Linux';
        }
    </script>
</body>
</html>
EOF

    log_success "HTML页面生成完成"
}

# 创建Python HTTP服务器脚本
create_server_script() {
    log_info "创建服务器启动脚本..."
    
    cat > "$WEB_DIR/start_server.py" << 'EOF'
#!/usr/bin/env python3
"""
简单的HTTP服务器 - 端口6666
自动提供当前目录的网页文件
"""

import http.server
import socketserver
import socket
import sys
from datetime import datetime
import os

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        """自定义日志格式"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        client_ip = self.client_address[0]
        print(f"[{timestamp}] {client_ip} - {format % args}")
    
    def end_headers(self):
        """添加额外的响应头"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

def get_local_ip():
    """获取本地IP地址"""
    try:
        # 创建一个临时socket来获取本地IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except:
        return "127.0.0.1"

def main():
    PORT = 6666
    
    # 切换到网页目录
    web_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(web_dir)
    
    # 设置处理器
    handler = MyHTTPRequestHandler
    
    # 允许地址重用
    socketserver.TCPServer.allow_reuse_address = True
    
    try:
        with socketserver.TCPServer(("", PORT), handler) as httpd:
            local_ip = get_local_ip()
            print("=" * 60)
            print(f"🚀 网页服务器已启动!")
            print(f"📍 本地访问: http://localhost:{PORT}")
            print(f"🌐 网络访问: http://{local_ip}:{PORT}")
            print(f"📁 服务目录: {web_dir}")
            print(f"⏰ 启动时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print("=" * 60)
            print("按 Ctrl+C 停止服务器")
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print("\n\n🛑 服务器已停止")
    except OSError as e:
        if e.errno == 98:  # Address already in use
            print(f"❌ 错误: 端口 {PORT} 已被占用")
            print("请检查是否已有服务器在运行，或选择其他端口")
        else:
            print(f"❌ 服务器启动错误: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 未知错误: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    chmod +x "$WEB_DIR/start_server.py"
    log_success "服务器脚本创建完成"
}

# 创建systemd服务（可选）
create_systemd_service() {
    log_info "创建systemd服务..."
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    sudo bash -c "cat > \"$service_file\"" << EOF
[Unit]
Description=Web Server on Port 6666
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WEB_DIR
ExecStart=/usr/bin/python3 $WEB_DIR/start_server.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    log_success "systemd服务创建完成"
}

# 启动服务器
start_server() {
    log_info "启动网页服务器..."
    
    # 检查端口是否被占用
    if netstat -tuln | grep ":6666 " > /dev/null; then
        log_warning "端口6666已被占用，尝试停止现有服务..."
        sudo pkill -f "python3.*6666" || true
        sleep 2
    fi
    
    # 启动服务器（后台运行）
    cd "$WEB_DIR"
    nohup python3 start_server.py > server.log 2>&1 &
    local server_pid=$!
    
    sleep 2
    
    # 检查服务器是否启动成功
    if ps -p $server_pid > /dev/null; then
        log_success "服务器启动成功！PID: $server_pid"
        echo "服务器日志: $WEB_DIR/server.log"
    else
        log_error "服务器启动失败，请检查日志"
        return 1
    fi
    
    # 测试访问
    log_info "测试服务器访问..."
    if curl -s http://localhost:6666 > /dev/null; then
        log_success "服务器测试访问成功"
    else
        log_warning "服务器测试访问失败，但进程仍在运行"
    fi
}

# 显示访问信息
show_access_info() {
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}')
    
    echo
    echo -e "${GREEN}🎉 网页服务器部署完成！${NC}"
    echo "=========================================="
    echo -e "📝 ${BLUE}访问信息:${NC}"
    echo -e "   本地: ${GREEN}http://localhost:6666${NC}"
    echo -e "   网络: ${GREEN}http://${local_ip}:6666${NC}"
    echo -e "   目录: ${YELLOW}${WEB_DIR}${NC}"
    echo "=========================================="
    echo -e "🛠️  ${BLUE}管理命令:${NC}"
    echo -e "   查看日志: ${YELLOW}tail -f ${WEB_DIR}/server.log${NC}"
    echo -e "   停止服务: ${YELLOW}pkill -f 'python3.*6666'${NC}"
    echo -e "   重启服务: ${YELLOW}cd ${WEB_DIR} && python3 start_server.py${NC}"
    echo "=========================================="
}

# 主部署函数
main_deployment() {
    log_info "开始部署网页服务器..."
    
    check_root
    install_dependencies
    create_web_directory
    generate_html_page
    create_server_script
    start_server
    show_access_info
    
    log_success "网页服务器部署完成！"
}

# 一键更新函数（从GitHub拉取并重新部署）
update_from_github() {
    log_info "从GitHub拉取最新版本并部署..."
    
    # 这里可以添加从GitHub拉取代码的逻辑
    # 例如：git clone 或 wget 最新版本
    
    log_success "更新完成（当前为本地版本）"
}

# 显示帮助信息
show_help() {
    echo "网页服务器部署脚本"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -d, --deploy   部署网页服务器（默认）"
    echo "  -u, --update   从GitHub更新并重新部署"
    echo "  -i, --info     显示访问信息"
    echo "  -s, --stop     停止服务器"
}

# 停止服务器
stop_server() {
    log_info "停止网页服务器..."
    sudo pkill -f "python3.*start_server.py" || true
    log_success "服务器已停止"
}

# 参数处理
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -u|--update)
        update_from_github
        exit 0
        ;;
    -i|--info)
        show_access_info
        exit 0
        ;;
    -s|--stop)
        stop_server
        exit 0
        ;;
    -d|--deploy|"")
        main_deployment
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac