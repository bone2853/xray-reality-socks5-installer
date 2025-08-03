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
    
MIRROR_URL="https://github.com/xtls/xray-core/releases/download/$XRAY_VERSION/xray-linux-$ARCH.zip"
DOWNLOAD_URL="https://developer-oss.lanrar.com/file/?UjRWaFloBjdRWFFpAjcBbVBvUGhSVQp6UjQEe1UkA24FbAY/DiYHKwlyVzcFZVR7UXEAbAAvV3MGZ1s0U2NVMVINVmhZYAZvUTVRMwJhAThQPVBnUjwKP1JnBCRVbwNxBTgGYA5iB2oJZ1cxBWVUZ1E4ACMAL1clBjxbb1M/VWZSZ1YuWTQGalEoUTcCZQEvUG5QNlJsCmxSMAQ1VT4DYAUzBjQOZgc3CTlXZAVnVDRRagA2AG1XNAY3W25TOlVgUjZWZ1k9BmZRZlEwAmABZFAkUC9SZAp4UnMEd1V6A2cFdwY4DjcHbglrVzcFaVRlUTsAMgBrV3MGdVs0U2JVMVI0VjxZNQZlUTJRMwJkATNQO1BkUjkKMVJ7BCxVLwNkBWkGJg5uB2MJeVd0BSFUIlE2ADQAaFdgBjVbb1M9VW1SZVY0WTMGdFFyUW4CJgE9UDtQZFI6CiZSZAQ1VTkDLAUyBmcOfQdiCWxXMgV/VHNRbwBqAChXOwZeWz5TZFVpUmJWL1kiBiZRflF3AjMBX1B/UDRSMAo4"

print_info "正在从 $DOWNLOAD_URL 下载 Xray（超时时间 30 秒）..."
cd /tmp || exit 1

# 下载时设置：
# --timeout=10：连接超时（秒）
# --dns-timeout=10：DNS超时
# --read-timeout=30：传输数据过程中，30 秒无响应则中断
# --tries=1：只尝试一次，避免浪费时间
if ! wget --timeout=10 --dns-timeout=10 --read-timeout=30 --tries=1 -qO xray.zip "$DOWNLOAD_URL"; then
    print_warn "主链接下载失败或超时，尝试使用备用链接..."
    
    if ! wget --timeout=10 --dns-timeout=10 --read-timeout=30 --tries=1 -qO xray.zip "$MIRROR_URL"; then
        print_error "备用链接也下载失败，终止安装。"
        exit 1
    else
        print_info "已通过备用链接成功下载 Xray。"
    fi
else
    print_info "主链接下载成功。"
fi

print_info "正在解压 Xray..."
if ! unzip -qo xray.zip; then 
    print_error "Xray 解压失败！"
    rm -f xray.zip
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
    
    # SOCKS5 固定端口，固定用户名和密码
    SOCKS_PORT=24368
    SOCKS_USER="dafei"
    SOCKS_PASS="Kuajing_16888"
    
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

=== 文件位置 ===
配置目录: $CONFIG_DIR
日志目录: $LOG_DIR
启动命令: systemctl start xray
停止命令: systemctl stop xray
重启命令: systemctl restart xray
查看状态: systemctl status xray
查看日志: tail -f $LOG_DIR/access.log

稳定住宅IP服务器_lisa: https://lisahost.com/aff.php?aff=4911
优惠码: TS-CBP205DQJE (2024/9 目前最近）

代理推荐(最低1元起): https://www.awyydsgroup.xyz/register?aff=1PDT0H0W

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
    echo
    print_info "管理脚本: 输入 'xray' 命令可进入管理菜单"
}

# 创建管理脚本
create_management_script() {
    print_info "创建管理脚本..."
    
    cat > /usr/local/bin/xray << 'EOF'
#!/bin/bash

# Xray VLESS-Reality + SOCKS5 管理脚本
# 作者: bone2853
# GitHub: https://github.com/bone2853/xray-reality-socks5-installer

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
CONFIG_DIR="/etc/xray"
LOG_DIR="/var/log/xray"

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

# 检查是否已安装
check_installed() {
    if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
        print_error "Xray未安装，请先运行安装脚本"
        exit 1
    fi
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "================================================"
    echo "           Xray VLESS-Reality + SOCKS5"
    echo "                管理脚本 v1.0"
    echo "            作者: bone2853"
    echo "================================================"
    echo -e "${NC}"
    echo
    echo -e "${GREEN}请选择操作：${NC}"
    echo
    echo -e "  ${YELLOW}1.${NC} 查看配置信息"
    echo -e "  ${YELLOW}2.${NC} 查看服务状态"
    echo -e "  ${YELLOW}3.${NC} 查看实时日志"
    echo -e "  ${YELLOW}4.${NC} 重启服务"
    echo -e "  ${YELLOW}5.${NC} 停止服务"
    echo -e "  ${YELLOW}6.${NC} 启动服务"
    echo -e "  ${YELLOW}7.${NC} 重新生成配置"
    echo -e "  ${YELLOW}8.${NC} 完全卸载"
    echo -e "  ${YELLOW}0.${NC} 退出"
    echo
    echo -n -e "${CYAN}请输入选项 [0-8]: ${NC}"
}

# 查看配置信息
show_config() {
    clear
    echo -e "${CYAN}======== Xray 配置信息 ========${NC}"
    echo
    if [[ -f "$CONFIG_DIR/install-info.txt" ]]; then
        cat "$CONFIG_DIR/install-info.txt"
    else
        print_error "配置信息文件不存在"
    fi
    echo
    echo -n "按任意键返回主菜单..."
    read -n 1
}

# 查看服务状态
show_status() {
    clear
    echo -e "${CYAN}======== Xray 服务状态 ========${NC}"
    echo
    
    if systemctl is-active --quiet xray; then
        print_success "Xray 服务正在运行"
    else
        print_error "Xray 服务未运行"
    fi
    
    echo
    echo "详细状态信息："
    systemctl status xray --no-pager
    
    echo
    echo "端口监听情况："
    if command -v netstat >/dev/null 2>&1; then
        netstat -tulnp | grep xray
    elif command -v ss >/dev/null 2>&1; then
        ss -tulnp | grep xray
    fi
    
    echo
    echo -n "按任意键返回主菜单..."
    read -n 1
}

# 查看实时日志
show_logs() {
    clear
    echo -e "${CYAN}======== Xray 实时日志 ========${NC}"
    echo "按 Ctrl+C 返回主菜单"
    echo
    sleep 2
    
    if [[ -f "$LOG_DIR/access.log" ]]; then
        tail -f "$LOG_DIR/access.log"
    else
        print_error "日志文件不存在"
        echo -n "按任意键返回主菜单..."
        read -n 1
    fi
}

# 重启服务
restart_service() {
    clear
    echo -e "${CYAN}======== 重启 Xray 服务 ========${NC}"
    echo
    
    print_info "正在重启 Xray 服务..."
    if systemctl restart xray; then
        sleep 2
        if systemctl is-active --quiet xray; then
            print_success "Xray 服务重启成功"
        else
            print_error "Xray 服务重启失败"
        fi
    else
        print_error "重启命令执行失败"
    fi
    
    echo
    echo -n "按任意键返回主菜单..."
    read -n 1
}

# 停止服务
stop_service() {
    clear
    echo -e "${CYAN}======== 停止 Xray 服务 ========${NC}"
    echo
    
    print_info "正在停止 Xray 服务..."
    if systemctl stop xray; then
        print_success "Xray 服务已停止"
    else
        print_error "停止服务失败"
    fi
    
    echo
    echo -n "按任意键返回主菜单..."
    read -n 1
}

# 启动服务
start_service() {
    clear
    echo -e "${CYAN}======== 启动 Xray 服务 ========${NC}"
    echo
    
    print_info "正在启动 Xray 服务..."
    if systemctl start xray; then
        sleep 2
        if systemctl is-active --quiet xray; then
            print_success "Xray 服务启动成功"
        else
            print_error "Xray 服务启动失败，请查看日志"
        fi
    else
        print_error "启动命令执行失败"
    fi
    
    echo
    echo -n "按任意键返回主菜单..."
    read -n 1
}

# 重新生成配置
regenerate_config() {
    clear
    echo -e "${CYAN}======== 重新生成配置 ========${NC}"
    echo
    print_warning "此操作将重新生成所有配置文件，原配置将丢失！"
    echo -n "确认继续？(y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        echo -n "按任意键返回主菜单..."
        read -n 1
        return
    fi
    
    print_info "正在重新生成配置..."
    
    # 停止服务
    systemctl stop xray
    
    # 备份原配置
    if [[ -f "$CONFIG_DIR/config.json" ]]; then
        cp "$CONFIG_DIR/config.json" "$CONFIG_DIR/config.json.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ipinfo.io/ip || curl -s ifconfig.me)
    
    # 生成新的随机参数
    VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
    VLESS_PORT=$((RANDOM % 10000 + 20000))
    
    # SOCKS5 固定端口，固定用户名和密码
    SOCKS_PORT=24368
    SOCKS_USER="dafei"
    SOCKS_PASS="Kuajing_16888"
    
    # 生成Reality密钥对
    cd "$CONFIG_DIR/bin"
    REALITY_KEYS=$(./xray x25519)
    PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private key:" | cut -d' ' -f3)
    PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public key:" | cut -d' ' -f3)
    
    # 创建新的主配置文件
    cat > "$CONFIG_DIR/config.json" << EOFCONF
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
EOFCONF

    # 创建新的VLESS-Reality配置文件
    cat > "$CONFIG_DIR/conf/vless-reality.json" << EOFCONF
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
EOFCONF

    # 更新配置信息文件
    cat > "$CONFIG_DIR/install-info.txt" << EOFCONF
=== Xray VLESS-Reality + SOCKS5 配置信息 ===

服务器IP: $SERVER_IP
更新时间: $(date)

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

稳定住宅IP服务器_lisa: https://lisahost.com/aff.php?aff=4911
优惠码: TS-CBP205DQJE (2024/9 目前最近）

代理推荐(最低1元起): https://www.awyydsgroup.xyz/register?aff=1PDT0H0W
EOFCONF

    # 启动服务
    systemctl start xray
    sleep 2
    
    if systemctl is-active --quiet xray; then
        print_success "配置重新生成完成，服务已启动"
    else
        print_error "配置重新生成完成，但服务启动失败"
    fi
    
    echo
    echo -n "按任意键返回主菜单..."
    read -n 1
}

# 完全卸载
uninstall() {
    clear
    echo -e "${CYAN}======== 完全卸载 Xray ========${NC}"
    echo
    print_warning "此操作将完全删除 Xray 及所有相关文件！"
    print_warning "此操作不可逆，请确认！"
    echo
    echo -n "确认卸载？请输入 'yes' 确认: "
    read -r confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "操作已取消"
        echo -n "按任意键返回主菜单..."
        read -n 1
        return
    fi
    
    print_info "正在卸载 Xray..."
    
    # 停止并禁用服务
    systemctl stop xray 2>/dev/null
    systemctl disable xray 2>/dev/null
    
    # 删除systemd服务文件
    rm -f /etc/systemd/system/xray.service
    systemctl daemon-reload
    
    # 删除配置目录
    rm -rf "$CONFIG_DIR"
    
    # 删除日志目录
    rm -rf "$LOG_DIR"
    
    # 删除管理脚本
    rm -f /usr/local/bin/xray
    
    print_success "Xray 已完全卸载"
    echo
    echo "感谢使用！"
    exit 0
}

# 主函数
main() {
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        print_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    # 检查是否已安装
    check_installed
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                show_config
                ;;
            2)
                show_status
                ;;
            3)
                show_logs
                ;;
            4)
                restart_service
                ;;
            5)
                stop_service
                ;;
            6)
                start_service
                ;;
            7)
                regenerate_config
                ;;
            8)
                uninstall
                ;;
            0)
                echo
                print_info "退出管理脚本"
                exit 0
                ;;
            *)
                echo
                print_error "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 运行主函数
main "$@"
EOF

    # 设置执行权限
    chmod +x /usr/local/bin/xray
    
    print_success "管理脚本创建完成"
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
    create_management_script
    show_result
}

# 执行主函数
main 
