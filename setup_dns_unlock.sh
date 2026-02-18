#!/bin/bash

# DNS解锁服务器一键配置脚本
# 适用于将落地机配置为DNS服务器，用于解锁AI服务

# 配置文件路径
DNSMASQ_CONF="/etc/dnsmasq.conf"
DNSMASQ_CONF_BAK="/etc/dnsmasq.conf.bak"
WHITELIST_FILE="/etc/dnsmasq.d/whitelist.conf"

# 颜色定义
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
NC="\033[0m" # No Color

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误：请以root权限运行此脚本${NC}"
        exit 1
    fi
}

# 显示主菜单
display_menu() {
    clear
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}DNS解锁服务器管理工具${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}1. 安装并配置DNS解锁服务器${NC}"
    echo -e "${YELLOW}2. 管理白名单${NC}"
    echo -e "${YELLOW}3. 查看当前配置${NC}"
    echo -e "${YELLOW}4. 还原原始配置${NC}"
    echo -e "${YELLOW}0. 退出脚本${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -n "请选择操作 [0-4]: "
}

# 显示白名单管理菜单
display_whitelist_menu() {
    clear
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}白名单管理${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}1. 添加IP到白名单${NC}"
    echo -e "${YELLOW}2. 移除白名单中的IP${NC}"
    echo -e "${YELLOW}3. 查看当前白名单${NC}"
    echo -e "${YELLOW}4. 清空白名单${NC}"
    echo -e "${YELLOW}0. 返回主菜单${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -n "请选择操作 [0-4]: "
}

# 安装并配置DNS解锁服务器
install_configure() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}安装并配置DNS解锁服务器${NC}"
    echo -e "${BLUE}====================================${NC}"

    # 更新系统
    echo -e "${YELLOW}正在更新系统...${NC}"
    apt update && apt upgrade -y

    # 安装DNSmasq
    echo -e "${YELLOW}正在安装DNSmasq...${NC}"
    apt install -y dnsmasq

    # 备份原始配置
    if [ ! -f "$DNSMASQ_CONF_BAK" ]; then
        echo -e "${YELLOW}正在备份原始配置...${NC}"
        cp "$DNSMASQ_CONF" "$DNSMASQ_CONF_BAK"
    fi

    # 创建白名单配置目录
    mkdir -p /etc/dnsmasq.d

    # 配置DNSmasq
    echo -e "${YELLOW}正在配置DNSmasq...${NC}"
    cat > "$DNSMASQ_CONF" << EOF
# 基本配置
listen-address=0.0.0.0
port=53
bind-interfaces

# 缓存设置
cache-size=10000

# 上游DNS服务器
server=8.8.8.8
server=8.8.4.4

# 包含白名单配置
conf-dir=/etc/dnsmasq.d

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

    # 创建默认白名单配置（默认允许所有IP，用户可以后续添加限制）
    cat > "$WHITELIST_FILE" << EOF
# 白名单配置
# 格式: allow-address=IP地址
# 示例: allow-address=192.168.1.100

# 默认允许所有IP（如需限制，请注释此行并添加具体IP）
# allow-address=0.0.0.0/0
EOF

    # 配置防火墙
    echo -e "${YELLOW}正在配置防火墙...${NC}"
    ufw allow 53/tcp
    ufw allow 53/udp

    # 重启DNSmasq服务
    echo -e "${YELLOW}正在重启DNSmasq服务...${NC}"
    systemctl restart dnsmasq
systemctl enable dnsmasq

    # 检查服务状态
    echo -e "${YELLOW}正在检查DNSmasq服务状态...${NC}"
    systemctl status dnsmasq --no-pager

    # 显示配置信息
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}DNS解锁服务器配置完成！${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}DNS服务器IP: $(curl -s ifconfig.me)${NC}"
    echo -e "${YELLOW}DNS端口: 53${NC}"
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    echo -e "${GREEN}请在中转机的分流配置中使用以下DNS服务器:${NC}"
    echo -e "${YELLOW}$(curl -s ifconfig.me)${NC}"
    echo ""
    echo -e "${GREEN}配置示例（适用于大多数分流工具）:${NC}"
    echo -e "${YELLOW}- 类型: DNS${NC}"
    echo -e "${YELLOW}- 服务器地址: $(curl -s ifconfig.me)${NC}"
    echo -e "${YELLOW}- 端口: 53${NC}"
    echo -e "${YELLOW}- 适用范围: AI服务域名${NC}"
    echo ""
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}注意事项:${NC}"
    echo -e "${YELLOW}1. 确保落地机的防火墙已开放53端口${NC}"
    echo -e "${YELLOW}2. 确保中转机可以访问落地机的53端口${NC}"
    echo -e "${YELLOW}3. 如需添加更多AI服务，请编辑 $DNSMASQ_CONF 文件${NC}"
    echo -e "${YELLOW}4. 如需修改DNS解析规则，请更新相应的address记录${NC}"
    echo -e "${YELLOW}5. 如需限制访问，请使用白名单管理功能${NC}"
    echo -e "${BLUE}====================================${NC}"

    read -p "按Enter键返回主菜单..."
}

# 管理白名单
manage_whitelist() {
    while true; do
        display_whitelist_menu
        read -r choice
        case $choice in
            1) add_to_whitelist ;;
            2) remove_from_whitelist ;;
            3) view_whitelist ;;
            4) clear_whitelist ;;
            0) break ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 添加IP到白名单
add_to_whitelist() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}添加IP到白名单${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}请输入要添加的IP地址（例如：192.168.1.100）:${NC}"
    read -r ip

    # 验证IP格式
    if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}无效的IP地址格式${NC}"
        sleep 2
        return
    fi

    # 检查是否已存在
    if grep -q "allow-address=$ip" "$WHITELIST_FILE"; then
        echo -e "${YELLOW}此IP已在白名单中${NC}"
        sleep 2
        return
    fi

    # 添加到白名单
    echo "allow-address=$ip" >> "$WHITELIST_FILE"

    # 重启服务
    systemctl restart dnsmasq

    echo -e "${GREEN}IP地址 $ip 已成功添加到白名单${NC}"
    sleep 2
}

# 从白名单移除IP
remove_from_whitelist() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}从白名单移除IP${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}请输入要移除的IP地址:${NC}"
    read -r ip

    # 检查是否存在
    if ! grep -q "allow-address=$ip" "$WHITELIST_FILE"; then
        echo -e "${RED}此IP不在白名单中${NC}"
        sleep 2
        return
    fi

    # 从白名单移除
    sed -i "/allow-address=$ip/d" "$WHITELIST_FILE"

    # 重启服务
    systemctl restart dnsmasq

    echo -e "${GREEN}IP地址 $ip 已成功从白名单移除${NC}"
    sleep 2
}

# 查看当前白名单
view_whitelist() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}当前白名单${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    if [ -f "$WHITELIST_FILE" ]; then
        cat "$WHITELIST_FILE"
    else
        echo -e "${RED}白名单配置文件不存在${NC}"
    fi
    echo ""
    read -p "按Enter键返回..."
}

# 清空白名单
clear_whitelist() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}清空白名单${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${RED}警告：此操作将清空所有白名单规则！${NC}"
    read -p "确定要清空白名单吗？(y/N): " confirm
    if [[ $confirm == [Yy]* ]]; then
        # 重建白名单文件，保留注释
        cat > "$WHITELIST_FILE" << EOF
# 白名单配置
# 格式: allow-address=IP地址
# 示例: allow-address=192.168.1.100

# 默认允许所有IP（如需限制，请注释此行并添加具体IP）
# allow-address=0.0.0.0/0
EOF

        # 重启服务
        systemctl restart dnsmasq

        echo -e "${GREEN}白名单已成功清空${NC}"
    else
        echo -e "${YELLOW}操作已取消${NC}"
    fi
    sleep 2
}

# 查看当前配置
view_config() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}当前配置${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${YELLOW}DNS服务器IP: $(curl -s ifconfig.me)${NC}"
    echo -e "${YELLOW}DNS端口: 53${NC}"
    echo -e "${YELLOW}DNSmasq配置文件: $DNSMASQ_CONF${NC}"
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    echo -e "${GREEN}服务状态:${NC}"
    systemctl status dnsmasq --no-pager
    echo ""
    read -p "按Enter键返回主菜单..."
}

# 还原原始配置
restore_config() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}还原原始配置${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo -e "${RED}警告：此操作将还原到原始配置，删除所有解锁规则！${NC}"
    read -p "确定要还原原始配置吗？(y/N): " confirm
    if [[ $confirm == [Yy]* ]]; then
        if [ -f "$DNSMASQ_CONF_BAK" ]; then
            # 停止服务
            systemctl stop dnsmasq

            # 还原配置
            cp "$DNSMASQ_CONF_BAK" "$DNSMASQ_CONF"

            # 删除白名单配置
            rm -f "$WHITELIST_FILE"

            # 重启服务
            systemctl restart dnsmasq

            echo -e "${GREEN}配置已成功还原到原始状态${NC}"
        else
            echo -e "${RED}原始配置备份不存在${NC}"
        fi
    else
        echo -e "${YELLOW}操作已取消${NC}"
    fi
    sleep 2
}

# 主函数
main() {
    check_root
    while true; do
        display_menu
        read -r choice
        case $choice in
            1) install_configure ;;
            2) manage_whitelist ;;
            3) view_config ;;
            4) restore_config ;;
            0) echo -e "${GREEN}感谢使用DNS解锁服务器管理工具，再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 执行主函数
main
