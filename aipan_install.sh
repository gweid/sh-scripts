#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 设置文件下载基础URL（替换为你的对象存储地址）
BASE_URL="https://r2cf.aipan.me/deploy"

# 打印带颜色的消息
print_message() {
    echo -e "${2}${1}${NC}"
}

# 检查必要的命令
check_requirements() {
    print_message "Checking requirements..." "${YELLOW}"
    
    if ! command -v curl &> /dev/null; then
        print_message "Installing curl..." "${YELLOW}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl
        else
            print_message "Error: Please install curl manually" "${RED}"
            exit 1
        fi
    fi

    if ! command -v docker &> /dev/null; then
        print_message "Installing Docker..." "${YELLOW}"
        curl -fsSL https://get.docker.com | sh
        sudo systemctl start docker
        sudo systemctl enable docker
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_message "Installing Docker Compose..." "${YELLOW}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# 下载必要文件
download_files() {
    print_message "Downloading necessary files..." "${YELLOW}"
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # 下载必要文件
    curl -O "${BASE_URL}/docker-compose.yml"
    curl -O "${BASE_URL}/install.sh"
    curl -O "${BASE_URL}/update.sh"
    curl -O "${BASE_URL}/ecosystem.config.js"

    # 检查文件是否下载成功
    for file in docker-compose.yml install.sh update.sh ecosystem.config.js; do
        if [ ! -f "$file" ]; then
            print_message "Error: Failed to download $file" "${RED}"
            cleanup
            exit 1
        fi
    done

    # 设置执行权限
    chmod +x install.sh update.sh

    print_message "Files downloaded successfully!" "${GREEN}"
}

# 配置环境
setup_environment() {
    print_message "\nSetting up environment..." "${YELLOW}"
    
    # 创建安装目录
    INSTALL_DIR="/opt/aipan-netdisk-search"
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp -r ./* "$INSTALL_DIR/"
    cd "$INSTALL_DIR"

    # 创建环境变量文件
    cat > .env << EOL
HOST=0.0.0.0
PORT=3000
EOL

    print_message "Environment setup completed!" "${GREEN}"
}

# 启动服务
start_service() {
    print_message "\nStarting service..." "${YELLOW}"
    
    cd "$INSTALL_DIR"
    sudo docker-compose pull
    sudo docker-compose up -d

    print_message "\nService started successfully!" "${GREEN}"
    print_message "You can access the application at: http://localhost:3000" "${GREEN}"
    print_message "\nUseful commands:" "${YELLOW}"
    print_message "- View logs: sudo docker-compose logs -f" "${YELLOW}"
    print_message "- Stop service: sudo docker-compose down" "${YELLOW}"
    print_message "- Update service: sudo ./update.sh" "${YELLOW}"
}

# 清理临时文件
cleanup() {
    if [ -n "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 主流程
main() {
    print_message "Welcome to AiPan Netdisk Search Quick Install" "${GREEN}"
    
    # 检查是否为 root 用户
    if [ "$EUID" -ne 0 ]; then
        print_message "Please run as root or with sudo" "${RED}"
        exit 1
    fi

    check_requirements
    download_files
    setup_environment
    start_service
    cleanup

    print_message "\nInstallation completed successfully!" "${GREEN}"
}

# 错误处理
set -e
trap 'print_message "\nAn error occurred. Installation failed." "${RED}"; cleanup' ERR

# 运行主流程
main