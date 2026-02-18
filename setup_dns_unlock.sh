#!/bin/bash

# DNS解锁服务器一键配置脚本
# 适用于将落地机配置为DNS服务器，用于解锁AI服务

echo "===================================="
echo "DNS解锁服务器一键配置脚本"
echo "===================================="

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请以root权限运行此脚本"
  exit 1
fi

# 更新系统
echo "正在更新系统..."
apt update && apt upgrade -y

# 安装DNSmasq
echo "正在安装DNSmasq..."
apt install -y dnsmasq

# 备份原始配置
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak

# 配置DNSmasq
echo "正在配置DNSmasq..."
cat > /etc/dnsmasq.conf << EOF
# 基本配置
listen-address=0.0.0.0
port=53
bind-interfaces

# 缓存设置
cache-size=10000

# 上游DNS服务器
server=8.8.8.8
server=8.8.4.4

# AI服务解锁规则
# OpenAI
domain=openai.com
address=/openai.com/104.18.32.67
address=/api.openai.com/104.18.31.67

# Anthropic
domain=anthropic.com
address=/anthropic.com/108.156.172.122
address=/api.anthropic.com/108.156.172.122

# Google AI
domain=googleapis.com
address=/generativelanguage.googleapis.com/142.250.185.95

# Microsoft AI
domain=microsoft.com
address=/azure.microsoft.com/20.106.105.124

# Meta AI
domain=meta.com
address=/meta.ai/157.240.224.13

# 其他AI服务
domain=cohere.com
address=/cohere.com/104.21.70.49

domain=perplexity.ai
address=/perplexity.ai/104.26.14.106

domain=claude.ai
address=/claude.ai/108.156.172.122
EOF

# 配置防火墙
echo "正在配置防火墙..."
ufw allow 53/tcp
ufw allow 53/udp

# 重启DNSmasq服务
echo "正在重启DNSmasq服务..."
systemctl restart dnsmasq
systemctl enable dnsmasq

# 检查服务状态
echo "正在检查DNSmasq服务状态..."
systemctl status dnsmasq --no-pager

# 显示配置信息
echo "===================================="
echo "DNS解锁服务器配置完成！"
echo "===================================="
echo "DNS服务器IP: $(curl -s ifconfig.me)"
echo "DNS端口: 53"
echo ""
echo "请在中转机的分流配置中使用以下DNS服务器:"
echo "$(curl -s ifconfig.me)"
echo ""
echo "配置示例（适用于大多数分流工具）:"
echo "- 类型: DNS"
echo "- 服务器地址: $(curl -s ifconfig.me)"
echo "- 端口: 53"
echo "- 适用范围: AI服务域名"
echo ""
echo "===================================="
echo "注意事项:"
echo "1. 确保落地机的防火墙已开放53端口"
echo "2. 确保中转机可以访问落地机的53端口"
echo "3. 如需添加更多AI服务，请编辑 /etc/dnsmasq.conf 文件"
echo "4. 如需修改DNS解析规则，请更新相应的address记录"
echo "===================================="
