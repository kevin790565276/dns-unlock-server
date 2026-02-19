#!/bin/bash

# DNS解锁服务器一键配置脚本
# 适用于将落地机配置为DNS服务器，用于解锁AI服务和流媒体服务

# 版本号
VERSION="1.5.6"

# 配置文件路径
DNSMASQ_CONF="/etc/dnsmasq.conf"
DNSMASQ_CONF_BAK="/etc/dnsmasq.conf.bak"
WHITELIST_FILE="/etc/dnsmasq.d/whitelist.conf"
PORT_BACKUP_FILE="/etc/dnsmasq.d/port.conf"

# 默认端口
DEFAULT_PORT="53"
CURRENT_PORT="53"

# 颜色定义
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
PURPLE="\033[35m"
CYAN="\033[36m"
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
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${GREEN}DNS解锁服务器管理工具${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}              ${PURPLE}版本: $VERSION${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}1.${NC} 安装并配置DNS解锁服务器             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2.${NC} 管理白名单                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}3.${NC} 管理上游DNS                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}4.${NC} 管理端口配置                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}5.${NC} 查看当前配置                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}6.${NC} 还原原始配置                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}0.${NC} 退出脚本                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo -n -e "${GREEN}请选择操作 [0-6]: ${NC}"
}

# 显示白名单管理菜单
display_whitelist_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${GREEN}白名单管理${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}1.${NC} 添加IP到白名单                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2.${NC} 移除白名单中的IP                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}3.${NC} 查看当前白名单                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}4.${NC} 清空白名单                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}0.${NC} 返回主菜单                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo -n -e "${GREEN}请选择操作 [0-4]: ${NC}"
}

# 显示上游DNS管理菜单
display_upstream_dns_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}             ${GREEN}上游DNS管理${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    
    # 显示当前使用的上游DNS
    echo -e "${CYAN}║${NC} ${YELLOW}当前上游DNS配置:${NC}                     ${CYAN}║${NC}"
    if grep -q "^server=" "$DNSMASQ_CONF"; then
        local dns_servers=$(grep "^server=" "$DNSMASQ_CONF" | grep -v "\.domain\.com" | awk -F'=' '{print $2}')
        local i=1
        while IFS= read -r server; do
            echo -e "${CYAN}║${NC}   ${GREEN}$i. $server${NC}                     ${CYAN}║${NC}"
            i=$((i+1))
        done <<< "$dns_servers"
    else
        echo -e "${CYAN}║${NC}   ${GREEN}使用系统默认DNS${NC}               ${CYAN}║${NC}"
    fi
    
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}1.${NC} 更改上游DNS（并备份当前配置）  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2.${NC} 恢复上游DNS                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}0.${NC} 返回主菜单                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo -n -e "${GREEN}请选择操作 [0-2]: ${NC}"
}

# 显示端口管理菜单
display_port_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}             ${GREEN}端口管理${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    
    # 显示当前端口
    if [ -f "$PORT_BACKUP_FILE" ]; then
        CURRENT_PORT=$(cat "$PORT_BACKUP_FILE" | grep "port=" | awk -F'=' '{print $2}')
    else
        CURRENT_PORT="53"
    fi
    
    echo -e "${CYAN}║${NC} ${YELLOW}当前端口:${NC} ${GREEN}$CURRENT_PORT${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}1.${NC} 更改DNS端口                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2.${NC} 恢复默认端口                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}0.${NC} 返回主菜单                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo -n -e "${GREEN}请选择操作 [0-2]: ${NC}"
}

# 安装并配置DNS解锁服务器
install_configure() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       ${GREEN}安装并配置DNS解锁服务器${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""

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
port=$CURRENT_PORT
bind-interfaces

# 基本选项
all-servers

# 缓存设置
cache-size=10000

# 上游DNS服务器
# 默认使用系统DNS，可通过菜单管理进行配置
# server=8.8.8.8
# server=8.8.4.4

# 包含白名单配置
conf-dir=/etc/dnsmasq.d

# AI服务解锁规则 - 使用server选项转发到上游DNS
# OpenAI 相关域名
server=/.openai.com/
server=/.api.openai.com/
server=/.chat.openai.com/
server=/.auth0.openai.com/
server=/.cdn.openai.com/

# Anthropic 相关域名
server=/.anthropic.com/
server=/.api.anthropic.com/
server=/.claude.ai/
server=/.api.claude.ai/

# Google AI 相关域名
server=/.googleapis.com/
server=/.generativelanguage.googleapis.com/
server=/.gemini.google.com/
server=/.ai.google.com/

# Microsoft AI 相关域名
server=/.microsoft.com/
server=/.azure.microsoft.com/
server=/.openai.azure.com/
server=/.ai.azure.com/

# Meta AI 相关域名
server=/.meta.com/
server=/.meta.ai/
server=/.facebook.com/
server=/.instagram.com/

# 其他AI服务相关域名
server=/.cohere.com/
server=/.perplexity.ai/
server=/.mistral.ai/
server=/.ai21.com/
server=/.huggingface.co/
server=/.runwayml.com/
server=/.stability.ai/
server=/.deepmind.com/
server=/.replicate.com/
server=/.fal.ai/
server=/.modal.com/
server=/.together.ai/
server=/.openrouter.ai/

# 流媒体服务解锁规则 - 使用server选项转发到上游DNS
# Netflix 相关域名
server=/.netflix.com/
server=/.nflximg.net/
server=/.nflxvideo.net/
server=/.nflxso.net/

# Disney+ 相关域名
server=/.disneyplus.com/
server=/.disney.com/
server=/.dssott.com/
server=/.bamgrid.com/
server=/.disneystreaming.com/

# HBO Max 相关域名
server=/.hbomax.com/
server=/.hbo.com/
server=/.warnermedia.com/

# Amazon Prime Video 相关域名
server=/.primevideo.com/
server=/.amazon.com/
server=/.amazonvideo.com/

# YouTube Premium 相关域名
server=/.youtube.com/
server=/.youtu.be/
server=/.googlevideo.com/

# Spotify 相关域名
server=/.spotify.com/
server=/.spoti.fi/
server=/.spotifycdn.com/

# Apple TV+ 相关域名
server=/.appletv.com/
server=/.apple.com/
server=/.itunes.apple.com/

# Paramount+ 相关域名
server=/.paramountplus.com/
server=/.cbs.com/
server=/.paramount.com/

# Peacock 相关域名
server=/.peacocktv.com/
server=/.nbc.com/
server=/.universalstudios.com/

# Crunchyroll 相关域名
server=/.crunchyroll.com/
server=/.funimation.com/
server=/.vrv.co/

# Hulu 相关域名
server=/.hulu.com/
server=/.disney.com/

# 亚洲流媒体服务相关域名
server=/.iqiyi.com/
server=/.v.qq.com/
server=/.qq.com/
server=/.youku.com/
server=/.bilibili.com/
server=/.acfun.cn/
server=/.tudou.com/
server=/.mgtv.com/

# 音乐流媒体服务相关域名
server=/.tidal.com/
server=/.deezer.com/
server=/.qqmusic.com/
server=/.kugou.com/
server=/.kuwo.cn/

# 体育流媒体服务相关域名
server=/.espn.com/
server=/.skysports.com/
server=/.nbcsports.com/
server=/.cbssports.com/

# 新闻流媒体服务相关域名
server=/.cnn.com/
server=/.bbc.com/
server=/.foxnews.com/
server=/.msnbc.com/
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
    
    # 检查是否安装了ufw
    if command -v ufw &> /dev/null; then
        echo -e "${GREEN}使用ufw配置防火墙...${NC}"
        ufw allow $CURRENT_PORT/tcp
        ufw allow $CURRENT_PORT/udp
    # 检查是否安装了firewalld
    elif command -v firewall-cmd &> /dev/null; then
        echo -e "${GREEN}使用firewalld配置防火墙...${NC}"
        firewall-cmd --permanent --add-port=$CURRENT_PORT/tcp
        firewall-cmd --permanent --add-port=$CURRENT_PORT/udp
        firewall-cmd --reload
    # 检查是否安装了iptables
    elif command -v iptables &> /dev/null; then
        echo -e "${GREEN}使用iptables配置防火墙...${NC}"
        iptables -A INPUT -p tcp --dport $CURRENT_PORT -j ACCEPT
        iptables -A INPUT -p udp --dport $CURRENT_PORT -j ACCEPT
        # 保存iptables规则（不同系统保存方式不同）
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
    else
        echo -e "${YELLOW}未检测到可用的防火墙工具（ufw/firewalld/iptables）${NC}"
        echo -e "${YELLOW}请手动开放$CURRENT_PORT端口以允许DNS服务访问${NC}"
    fi

    # 重启DNSmasq服务
    echo -e "${YELLOW}正在重启DNSmasq服务...${NC}"
    systemctl restart dnsmasq
systemctl enable dnsmasq

    # 检查服务状态
    echo -e "${YELLOW}正在检查DNSmasq服务状态...${NC}"
    systemctl status dnsmasq --no-pager

    # 获取IPv4地址
    local ipv4_address=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s ifconfig.me)
    
    # 获取当前端口配置
    if [ -f "$PORT_BACKUP_FILE" ]; then
        CURRENT_PORT=$(cat "$PORT_BACKUP_FILE" | grep "port=" | awk -F'=' '{print $2}')
    else
        CURRENT_PORT="53"
    fi
    
    # 显示配置信息
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${GREEN}DNS解锁服务器配置完成！${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}DNS服务器IPv4: $ipv4_address${NC}"
    echo -e "${YELLOW}DNS端口: $CURRENT_PORT${NC}"
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    echo -e "${GREEN}请在中转机的分流配置中使用以下DNS服务器:${NC}"
    echo -e "${YELLOW}$ipv4_address:$CURRENT_PORT${NC}"
    echo ""
    echo -e "${GREEN}配置示例（适用于大多数分流工具）:${NC}"
    echo -e "${YELLOW}- 类型: DNS${NC}"
    echo -e "${YELLOW}- 服务器地址: $ipv4_address${NC}"
    echo -e "${YELLOW}- 端口: $CURRENT_PORT${NC}"
    echo -e "${YELLOW}- 适用范围: AI服务和流媒体域名${NC}"
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}注意事项${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}1. 确保落地机的防火墙已开放$CURRENT_PORT端口${NC}"
    echo -e "${YELLOW}2. 确保中转机可以访问落地机的$CURRENT_PORT端口${NC}"
    echo -e "${YELLOW}3. 如需添加更多服务，请编辑 $DNSMASQ_CONF 文件${NC}"
    echo -e "${YELLOW}4. 如需限制访问，请使用白名单管理功能${NC}"
    echo -e "${YELLOW}5. 如需配置上游DNS，请使用上游DNS管理功能${NC}"
    echo -e "${YELLOW}6. 如需更改端口，请使用端口管理功能${NC}"
    echo ""

    echo -n -e "${GREEN}按Enter键返回主菜单...${NC}"
    read
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
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}添加IP到白名单${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
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
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${GREEN}从白名单移除IP${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
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
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}当前白名单${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    if [ -f "$WHITELIST_FILE" ]; then
        cat "$WHITELIST_FILE"
    else
        echo -e "${RED}白名单配置文件不存在${NC}"
    fi
    echo ""
    echo -n -e "${GREEN}按Enter键返回...${NC}"
    read
}

# 清空白名单
clear_whitelist() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${GREEN}清空白名单${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}警告：此操作将清空所有白名单规则！${NC}"
    echo -n -e "${GREEN}确定要清空白名单吗？(y/N): ${NC}"
    read confirm
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

# 管理上游DNS
manage_upstream_dns() {
    while true; do
        display_upstream_dns_menu
        read -r choice
        case $choice in
            1) change_upstream_dns ;;
            2) restore_upstream_dns ;;
            0) break ;;
            "") break ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 更改上游DNS
change_upstream_dns() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${GREEN}更改上游DNS${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 备份当前上游DNS配置
    echo -e "${YELLOW}正在备份当前上游DNS配置...${NC}"
    cp "$DNSMASQ_CONF" "${DNSMASQ_CONF}.dns.bak"
    
    # 提示用户输入新的DNS服务器
    echo -e "${YELLOW}请输入主DNS服务器（例如：8.8.8.8）:${NC}"
    read -r primary_dns
    
    echo -e "${YELLOW}请输入备用DNS服务器（例如：8.8.4.4）:${NC}"
    read -r secondary_dns
    
    # 验证DNS格式
    validate_dns() {
        local dns=$1
        if [[ ! $dns =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            return 1
        fi
        return 0
    }
    
    if ! validate_dns "$primary_dns"; then
        echo -e "${RED}主DNS服务器格式无效${NC}"
        sleep 2
        return
    fi
    
    if ! validate_dns "$secondary_dns"; then
        echo -e "${RED}备用DNS服务器格式无效${NC}"
        sleep 2
        return
    fi
    
    # 移除现有的server配置（保留域名转发规则）
    sed -i '/^server=/ { /\.domain\.com/!d }' "$DNSMASQ_CONF"
    
    # 添加新的server配置
    echo "server=$primary_dns" >> "$DNSMASQ_CONF"
    echo "server=$secondary_dns" >> "$DNSMASQ_CONF"
    
    # 重启服务
    echo -e "${YELLOW}正在重启DNSmasq服务...${NC}"
    systemctl restart dnsmasq
    
    echo -e "${GREEN}上游DNS已成功更改为:${NC}"
    echo -e "${YELLOW}主DNS: $primary_dns${NC}"
    echo -e "${YELLOW}备用DNS: $secondary_dns${NC}"
    sleep 2
}

# 恢复上游DNS
restore_upstream_dns() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${GREEN}恢复上游DNS${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -f "${DNSMASQ_CONF}.dns.bak" ]; then
        # 移除现有的server配置（保留域名转发规则）
        sed -i '/^server=/ { /\.domain\.com/!d }' "$DNSMASQ_CONF"
        
        # 从备份中恢复server配置
        grep "^server=" "${DNSMASQ_CONF}.dns.bak" | grep -v "\.domain\.com" >> "$DNSMASQ_CONF"
        
        # 重启服务
        echo -e "${YELLOW}正在重启DNSmasq服务...${NC}"
        systemctl restart dnsmasq
        
        echo -e "${GREEN}上游DNS已成功恢复${NC}"
        echo -e "${YELLOW}当前上游DNS配置:${NC}"
        if grep -q "^server=" "$DNSMASQ_CONF"; then
            grep "^server=" "$DNSMASQ_CONF" | grep -v "\.domain\.com" | awk -F'=' '{print "  " $2}'
        else
            echo -e "  ${GREEN}使用系统默认DNS${NC}"
        fi
    else
        echo -e "${RED}上游DNS备份不存在${NC}"
    fi
    sleep 2
}

# 管理端口配置
manage_port_config() {
    while true; do
        display_port_menu
        read -r choice
        case $choice in
            1) change_port ;;
            2) restore_default_port ;;
            0) break ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 更改DNS端口
change_port() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}更改DNS端口${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 获取当前端口
    if [ -f "$PORT_BACKUP_FILE" ]; then
        CURRENT_PORT=$(cat "$PORT_BACKUP_FILE" | grep "port=" | awk -F'=' '{print $2}')
    else
        CURRENT_PORT="53"
    fi
    
    echo -e "${YELLOW}当前DNS端口: $CURRENT_PORT${NC}"
    echo -e "${YELLOW}请输入新的DNS端口（例如：5353）:${NC}"
    read -r new_port
    
    # 验证端口格式
    if [[ ! $new_port =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号，请输入1-65535之间的数字${NC}"
        sleep 2
        return
    fi
    
    # 停止服务
    systemctl stop dnsmasq
    
    # 更新配置文件中的端口
    sed -i "s/^port=.*/port=$new_port/" "$DNSMASQ_CONF"
    
    # 创建端口备份文件
    echo "port=$new_port" > "$PORT_BACKUP_FILE"
    
    # 更新防火墙规则
    echo -e "${YELLOW}正在更新防火墙规则...${NC}"
    
    # 移除旧端口规则
    if command -v ufw &> /dev/null; then
        ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
        ufw delete allow $CURRENT_PORT/udp 2>/dev/null
        # 添加新端口规则
        ufw allow $new_port/tcp
        ufw allow $new_port/udp
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --remove-port=$CURRENT_PORT/tcp 2>/dev/null
        firewall-cmd --permanent --remove-port=$CURRENT_PORT/udp 2>/dev/null
        # 添加新端口规则
        firewall-cmd --permanent --add-port=$new_port/tcp
        firewall-cmd --permanent --add-port=$new_port/udp
        firewall-cmd --reload
    elif command -v iptables &> /dev/null; then
        iptables -D INPUT -p tcp --dport $CURRENT_PORT -j ACCEPT 2>/dev/null
        iptables -D INPUT -p udp --dport $CURRENT_PORT -j ACCEPT 2>/dev/null
        # 添加新端口规则
        iptables -A INPUT -p tcp --dport $new_port -j ACCEPT
        iptables -A INPUT -p udp --dport $new_port -j ACCEPT
        # 保存规则
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
    fi
    
    # 重启服务
    echo -e "${YELLOW}正在重启DNSmasq服务...${NC}"
    systemctl restart dnsmasq
    
    # 更新当前端口变量
    CURRENT_PORT=$new_port
    
    echo -e "${GREEN}DNS端口已成功更改为: $new_port${NC}"
    echo -e "${YELLOW}请在中转机的分流配置中使用新端口${NC}"
    sleep 2
}

# 恢复默认端口
restore_default_port() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}恢复默认端口${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 获取当前端口
    if [ -f "$PORT_BACKUP_FILE" ]; then
        CURRENT_PORT=$(cat "$PORT_BACKUP_FILE" | grep "port=" | awk -F'=' '{print $2}')
    else
        CURRENT_PORT="53"
    fi
    
    if [ "$CURRENT_PORT" == "53" ]; then
        echo -e "${YELLOW}当前已经是默认端口53${NC}"
        sleep 2
        return
    fi
    
    echo -e "${YELLOW}当前端口: $CURRENT_PORT${NC}"
    echo -e "${YELLOW}默认端口: 53${NC}"
    echo -n -e "${GREEN}确定要恢复默认端口吗？(y/N): ${NC}"
    read confirm
    
    if [[ $confirm == [Yy]* ]]; then
        # 停止服务
        systemctl stop dnsmasq
        
        # 更新配置文件中的端口
        sed -i "s/^port=.*/port=53/" "$DNSMASQ_CONF"
        
        # 删除端口备份文件
        rm -f "$PORT_BACKUP_FILE"
        
        # 更新防火墙规则
        echo -e "${YELLOW}正在更新防火墙规则...${NC}"
        
        # 移除旧端口规则
        if command -v ufw &> /dev/null; then
            ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
            ufw delete allow $CURRENT_PORT/udp 2>/dev/null
            # 添加默认端口规则
            ufw allow 53/tcp
            ufw allow 53/udp
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --remove-port=$CURRENT_PORT/tcp 2>/dev/null
            firewall-cmd --permanent --remove-port=$CURRENT_PORT/udp 2>/dev/null
            # 添加默认端口规则
            firewall-cmd --permanent --add-port=53/tcp
            firewall-cmd --permanent --add-port=53/udp
            firewall-cmd --reload
        elif command -v iptables &> /dev/null; then
            iptables -D INPUT -p tcp --dport $CURRENT_PORT -j ACCEPT 2>/dev/null
            iptables -D INPUT -p udp --dport $CURRENT_PORT -j ACCEPT 2>/dev/null
            # 添加默认端口规则
            iptables -A INPUT -p tcp --dport 53 -j ACCEPT
            iptables -A INPUT -p udp --dport 53 -j ACCEPT
            # 保存规则
            if command -v iptables-save &> /dev/null; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
            fi
        fi
        
        # 重启服务
        echo -e "${YELLOW}正在重启DNSmasq服务...${NC}"
        systemctl restart dnsmasq
        
        # 更新当前端口变量
        CURRENT_PORT="53"
        
        echo -e "${GREEN}DNS端口已成功恢复为默认端口: 53${NC}"
    else
        echo -e "${YELLOW}操作已取消${NC}"
    fi
    sleep 2
}

# 查看当前配置
view_config() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${GREEN}当前配置${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 获取IPv4地址
    local ipv4_address=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s ifconfig.me)
    
    # 获取当前端口配置
    if [ -f "$PORT_BACKUP_FILE" ]; then
        CURRENT_PORT=$(cat "$PORT_BACKUP_FILE" | grep "port=" | awk -F'=' '{print $2}')
    else
        CURRENT_PORT="53"
    fi
    
    echo -e "${YELLOW}DNS服务器IPv4: $ipv4_address${NC}"
    echo -e "${YELLOW}DNS端口: $CURRENT_PORT${NC}"
    echo -e "${YELLOW}DNSmasq配置文件: $DNSMASQ_CONF${NC}"
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    echo -e "${GREEN}服务状态:${NC}"
    systemctl status dnsmasq --no-pager
    echo ""
    echo -n -e "${GREEN}按Enter键返回主菜单...${NC}"
    read
}

# 还原原始配置
restore_config() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}还原原始配置${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}警告：此操作将还原到原始配置，删除所有解锁规则，并卸载DNSmasq！${NC}"
    echo -n -e "${GREEN}确定要还原原始配置吗？(y/N): ${NC}"
    read confirm
    if [[ $confirm == [Yy]* ]]; then
        if [ -f "$DNSMASQ_CONF_BAK" ]; then
            # 停止服务
            systemctl stop dnsmasq

            # 还原配置
            cp "$DNSMASQ_CONF_BAK" "$DNSMASQ_CONF"

            # 删除白名单配置
            rm -f "$WHITELIST_FILE"

            # 删除DNS备份
            rm -f "${DNSMASQ_CONF}.dns.bak"

            # 删除端口配置
            rm -f "$PORT_BACKUP_FILE"

            # 卸载DNSmasq
            echo -e "${YELLOW}正在卸载DNSmasq...${NC}"
            apt remove -y dnsmasq

            # 清理配置文件
            rm -rf /etc/dnsmasq.d

            echo -e "${GREEN}配置已成功还原到原始状态，DNSmasq已卸载${NC}"
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
            3) manage_upstream_dns ;;
            4) manage_port_config ;;
            5) view_config ;;
            6) restore_config ;;
            0) echo -e "${GREEN}感谢使用DNS解锁服务器管理工具，再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 执行主函数
main
