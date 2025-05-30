#!/bin/bash

# Xray VLESS-Reality + SOCKS5 一键安装脚本
# 作者: bone2853
# GitHub: https://github.com/bone2853/xray-reality-socks5-installer

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
XRAY_VERSION="v1.8.3"
CONFIG_DIR="/etc/xray"
LOG_DIR="/var/log/xray"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统
check_system() {
    print_info "检查系统环境..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        print_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    # 检查系统类型
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        print_info "检测到Debian/Ubuntu系统"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        print_info "检测到CentOS/RHEL系统"
    else
        print_error "不支持的操作系统"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    print_info "安装依赖包..."
    
    if [[ "$OS" == "debian" ]]; then
        apt update -y
        apt install -y curl wget unzip systemd
    elif [[ "$OS" == "centos" ]]; then
        yum update -y
        yum install -y curl wget unzip systemd
    fi
    
    print_success "依赖包安装完成"
}

# 下载和安装Xray
install_xray() {
    print_info "下载并安装Xray $XRAY_VERSION..."
    
    # 创建目录
    mkdir -p "$CONFIG_DIR/bin"
    mkdir -p "$CONFIG_DIR/conf"
    mkdir -p "$LOG_DIR"
    
    # 下载Xray
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="64" ;;
        aarch64) ARCH="arm64-v8a" ;;
        *) print_error "不支持的架构: $ARCH"; exit 1 ;;
    esac
    
    DOWNLOAD_URL="https://github.com/xtls/xray-core/releases/download/$XRAY_VERSION/xray-linux-$ARCH.zip"
    
    print_info "正在从 $DOWNLOAD_URL 下载 Xray..."
    cd /tmp # 操作目录切换到 /tmp
    if ! wget -qO xray.zip "$DOWNLOAD_URL"; then
        print_error "Xray 下载失败！请检查网络或URL。"
        exit 1
    fi
    
    print_info "正在解压 Xray..."
    # -o: overwrite files without prompting. -q: quiet mode.
    if ! unzip -qo xray.zip; then 
        print_error "Xray 解压失败！"
        rm -f xray.zip # 清理下载的zip
        exit 1
    fi
    
    print_info "正在安装 Xray 可执行文件和数据文件..."
    # 确保源文件存在再移动
    if [ ! -f "xray" ]; then
        print_error "解压后的 xray 可执行文件未在 /tmp 找到！"
        rm -f xray.zip geoip.dat geosite.dat # 清理下载和可能解压的文件
        exit 1
    fi
    mv xray "$CONFIG_DIR/bin/"

    if [ ! -f "geoip.dat" ]; then
        print_error "解压后的 geoip.dat 文件未在 /tmp 找到！Xray的 geoip 功能将无法使用。"
        # 由于 geoip:private 规则的存在，这个文件很重要
        rm -f xray.zip geosite.dat # 清理下载和可能解压的文件
        exit 1 
    fi
    mv geoip.dat "$CONFIG_DIR/bin/"

    if [ ! -f "geosite.dat" ]; then
        print_warning "解压后的 geosite.dat 文件未在 /tmp 找到。这可能影响 geosite 相关规则。"
        # 对于当前脚本生成的配置，geosite.dat 不是强制性的，所以只给警告
    else
        mv geosite.dat "$CONFIG_DIR/bin/"
    fi
    
    chmod +x "$CONFIG_DIR/bin/xray"
    
    # 清理下载的zip文件
    rm -f xray.zip
        
    print_success "Xray 安装完成"
}

# 生成配置
generate_config() {
    print_info "生成配置文件..."
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ipinfo.io/ip || curl -s ifconfig.me)
    
    # 生成随机参数
    VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
    VLESS_PORT=$((RANDOM % 10000 + 20000))
    
    # SOCKS5 固定端口，随机用户名和密码（安全性更好）
    SOCKS_PORT=24368
    SOCKS_USER="user_$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)"
    SOCKS_PASS="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)"
    
    # 生成Reality密钥对
    cd $CONFIG_DIR/bin
    REALITY_KEYS=$(./xray x25519)
    PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key:" | cut -d' ' -f3)
    PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key:" | cut -d' ' -f3)
    
    # 创建主配置文件
    cat > $CONFIG_DIR/config.json << EOF
{
  "log": {
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "socks-in",
      "port": $SOCKS_PORT,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$SOCKS_USER",
            "pass": "$SOCKS_PASS"
          }
        ],
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["socks-in"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
EOF

    # 创建VLESS-Reality配置文件
    cat > $CONFIG_DIR/conf/vless-reality.json << EOF
{
  "inbounds": [
    {
      "tag": "vless-reality-$VLESS_PORT",
      "port": $VLESS_PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$VLESS_UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.cloudflare.com:443",
          "serverNames": ["www.cloudflare.com"],
          "publicKey": "$PUBLIC_KEY",
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [""]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ]
}
EOF

    # 保存配置信息
    cat > $CONFIG_DIR/install-info.txt << EOF
=== Xray VLESS-Reality + SOCKS5 安装信息 ===

服务器IP: $SERVER_IP
安装时间: $(date)

=== VLESS-Reality 配置 ===
端口: $VLESS_PORT
UUID: $VLESS_UUID
公钥: $PUBLIC_KEY
SNI: www.cloudflare.com
Flow: xtls-rprx-vision

VLESS URL:
vless://$VLESS_UUID@$SERVER_IP:$VLESS_PORT?encryption=none&security=reality&flow=xtls-rprx-vision&type=tcp&sni=www.cloudflare.com&pbk=$PUBLIC_KEY&fp=chrome#dafei-Reality-$SERVER_IP

=== SOCKS5 代理配置 ===
IP: $SERVER_IP
端口: $SOCKS_PORT
用户名: $SOCKS_USER
密码: $SOCKS_PASS

=== 指纹浏览器设置 ===
代理类型: SOCKS5
代理IP: $SERVER_IP
代理端口: $SOCKS_PORT
用户名: $SOCKS_USER
密码: $SOCKS_PASS

=== 文件位置 ===
配置目录: $CONFIG_DIR
日志目录: $LOG_DIR
启动命令: systemctl start xray
停止命令: systemctl stop xray
重启命令: systemctl restart xray
查看状态: systemctl status xray
查看日志: tail -f $LOG_DIR/access.log

安全稳定住宅IP服务器推荐_lisa主机: https://lisahost.com/aff.php?aff=4911


EOF

    print_success "配置文件生成完成"
}

# 创建systemd服务
create_service() {
    print_info "创建systemd服务..."
    
    cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls/xray-core
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=$CONFIG_DIR/bin/xray run -config $CONFIG_DIR/config.json -confdir $CONFIG_DIR/conf
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray
    
    print_success "systemd服务创建完成"
}

# 配置防火墙
configure_firewall() {
    print_info "配置防火墙..."
    
    # 读取端口信息
    VLESS_PORT=$(grep '"port"' $CONFIG_DIR/conf/vless-reality.json | head -1 | grep -o '[0-9]*')
    SOCKS_PORT=$(grep '"port"' $CONFIG_DIR/config.json | head -1 | grep -o '[0-9]*')
    
    # 开放端口
    if command -v ufw >/dev/null 2>&1; then
        ufw allow $VLESS_PORT/tcp
        ufw allow $SOCKS_PORT/tcp
        print_info "UFW防火墙规则已添加"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=$VLESS_PORT/tcp
        firewall-cmd --permanent --add-port=$SOCKS_PORT/tcp
        firewall-cmd --reload
        print_info "Firewalld防火墙规则已添加"
    fi
    
    print_success "防火墙配置完成"
}

# 启动服务
start_service() {
    print_info "启动Xray服务..."
    
    systemctl start xray
    sleep 3
    
    if systemctl is-active --quiet xray; then
        print_success "Xray服务启动成功"
    else
        print_error "Xray服务启动失败"
        print_error "请查看日志: journalctl -u xray -f"
        exit 1
    fi
}

# 显示安装结果
show_result() {
    clear
    print_success "=========================================="
    print_success "  Xray VLESS-Reality + SOCKS5 安装完成!"
    print_success "=========================================="
    echo
    
    # 显示配置信息
    cat $CONFIG_DIR/install-info.txt
    
    echo
    print_warning "请保存以上信息，特别是SOCKS5的用户名和密码！"
    print_info "配置信息已保存到: $CONFIG_DIR/install-info.txt"
    echo
    print_info "管理命令:"
    print_info "  启动服务: systemctl start xray"
    print_info "  停止服务: systemctl stop xray"
    print_info "  重启服务: systemctl restart xray"
    print_info "  查看状态: systemctl status xray"
    print_info "  查看日志: tail -f $LOG_DIR/access.log"
}

# 主函数
main() {
    clear
    echo -e "${BLUE}"
    echo "========================================"
    echo "  Xray VLESS-Reality + SOCKS5 安装器"
    echo "  GitHub: github.com/bone2853"
    echo "========================================"
    echo -e "${NC}"
    
    check_system
    install_dependencies
    install_xray
    generate_config
    create_service
    configure_firewall
    start_service
    show_result
}

# 执行主函数
main 