# Xray VLESS-Reality + SOCKS5 一键安装器

[![License](https://img.shields.io/github/license/bone2853/xray-reality-socks5-installer)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/bone2853/xray-reality-socks5-installer)](https://github.com/bone2853/xray-reality-socks5-installer/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/bone2853/xray-reality-socks5-installer)](https://github.com/bone2853/xray-reality-socks5-installer/issues)

> 🚀 一键安装 Xray VLESS-Reality + SOCKS5 代理，专为指纹浏览器优化

## ✨ 功能特性

- 🎯 **一键安装** - 零配置，自动化安装所有组件
- 🔒 **VLESS-Reality** - 最新的无特征协议，抗审查能力强
- 🌐 **SOCKS5代理** - 支持指纹浏览器等应用直接使用
- 🔐 **便捷认证** - SOCKS5固定端口、用户名、密码便于记忆，可手动修改
- 📊 **完整日志** - 详细的访问和错误日志记录
- 🛡️ **防火墙配置** - 自动配置系统防火墙规则
- ⚡ **系统服务** - 自动创建systemd服务，开机自启

## 🎯 适用场景

- ✅ 指纹浏览器代理需求
- ✅ 个人隐私保护
- ✅ 网络访问需求
- ✅ 科学研究用途

## 📋 系统要求

- **操作系统**: Ubuntu 18.04+, Debian 9+, CentOS 7+
- **架构**: x86_64, ARM64
- **权限**: Root用户
- **网络**: 服务器需要公网IP

## 🚀 一键安装

```bash
bash <(curl -s https://raw.githubusercontent.com/bone2853/xray-reality-socks5-installer/main/install.sh)
```

## 📱 使用方法

### 指纹浏览器配置

安装完成后，使用显示的SOCKS5配置信息：

```
代理类型: SOCKS5
代理IP: 你的服务器IP
代理端口: 显示的端口号
用户名: 显示的用户名
密码: 显示的密码
```

### 管理命令

```bash
# 启动服务
systemctl start xray

# 停止服务
systemctl stop xray

# 重启服务
systemctl restart xray

# 查看状态
systemctl status xray

# 查看日志
tail -f /var/log/xray/access.log
```

## 📝 配置信息

安装完成后，所有配置信息会保存在：
- 配置文件: `/etc/xray/install-info.txt`
- 主配置: `/etc/xray/config.json`
- VLESS配置: `/etc/xray/conf/vless-reality.json`
- 日志目录: `/var/log/xray/`

## 🔧 自定义配置

如需自定义配置，可以编辑对应的配置文件后重启服务：

```bash
# 编辑SOCKS5配置
nano /etc/xray/config.json

# 编辑VLESS-Reality配置
nano /etc/xray/conf/vless-reality.json

# 重启服务
systemctl restart xray
```

## 🛠️ 故障排除

### 指纹浏览器无法连接

1. 确认SOCKS5端口和认证信息正确
2. 检查服务器防火墙和云服务商安全组
3. 确认代理类型选择为SOCKS5
4. 关闭其他本地VPN代理软件，用国内IP》再测试指纹浏览器

### v2rayN无法连接
1. 点击v2rayN顶部菜单的“重启服务”
2. 点击v2rayN底部的“系统代理”，选择“自动配置系统代理”

### 服务无法启动

```bash
# 查看详细错误
journalctl -u xray -f

# 检查配置文件语法
/etc/xray/bin/xray run -test -config /etc/xray/config.json
```

### 端口无法访问

```bash
# 检查端口监听
netstat -tulnp | grep xray

# 检查防火墙
ufw status
```



## 📚 更多文档

- [详细安装指南](docs/installation.md)
- [使用说明](docs/usage.md)
- [故障排除](docs/troubleshooting.md)
- [指纹浏览器配置示例](examples/browser-config.md)

## 🤝 贡献

欢迎提交Issue和Pull Request！

1. Fork本项目
2. 创建功能分支
3. 提交更改
4. 发起Pull Request

## ⚠️ 免责声明

本项目仅供学习和技术研究使用。使用者需遵守当地法律法规，开发者不承担任何法律责任。

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。

## 💖 支持

如果这个项目对您有帮助，请给个 ⭐ Star！

---

**GitHub**: [https://github.com/bone2853/xray-reality-socks5-installer](https://github.com/bone2853/xray-reality-socks5-installer) 