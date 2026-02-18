#!/bin/bash

# DNS解锁服务器一键配置脚本
# 适用于将落地机配置为DNS服务器，用于解锁AI服务和流媒体服务

# 版本号
VERSION="1.5.0"

# 配置文件路径
DNSMASQ_CONF="/etc/dnsmasq.conf"
DNSMASQ_CONF_BAK="/etc/dnsmasq.conf.bak"
WHITELIST_FILE="/etc/dnsmasq.d/whitelist.conf"

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
    echo -e "${CYAN}║${NC} ${YELLOW}4.${NC} 查看当前配置                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}5.${NC} 还原原始配置                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}0.${NC} 退出脚本                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo -n -e "${GREEN}请选择操作 [0-5]: ${NC}"
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
        local dns_servers=$(grep "^server=" "$DNSMASQ_CONF" | awk -F'=' '{print $2}')
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
port=53
bind-interfaces

# 强制使用IPv4
all-servers
filter-AAAA

# 缓存设置
cache-size=10000

# 上游DNS服务器
# 默认使用系统DNS，可通过菜单管理进行配置
# server=8.8.8.8
# server=8.8.4.4

# 包含白名单配置
conf-dir=/etc/dnsmasq.d

# AI服务解锁规则 - 使用域名关键词匹配
# OpenAI 相关域名
address=/.openai.com/
address=/.api.openai.com/
address=/.chat.openai.com/
address=/.auth0.openai.com/
address=/.cdn.openai.com/

# Anthropic 相关域名
address=/.anthropic.com/
address=/.api.anthropic.com/
address=/.claude.ai/
address=/.api.claude.ai/

# Google AI 相关域名
address=/.googleapis.com/
address=/.generativelanguage.googleapis.com/
address=/.gemini.google.com/
address=/.ai.google.com/

# Microsoft AI 相关域名
address=/.microsoft.com/
address=/.azure.microsoft.com/
address=/.openai.azure.com/
address=/.ai.azure.com/

# Meta AI 相关域名
address=/.meta.com/
address=/.meta.ai/
address=/.facebook.com/
address=/.instagram.com/

# 其他AI服务相关域名
address=/.cohere.com/
address=/.perplexity.ai/
address=/.mistral.ai/
address=/.ai21.com/
address=/.huggingface.co/
address=/.runwayml.com/
address=/.stability.ai/
address=/.deepmind.com/
address=/.replicate.com/
address=/.fal.ai/
address=/.modal.com/
address=/.together.ai/
address=/.openrouter.ai/

# 流媒体服务解锁规则 - 使用域名关键词匹配
# Netflix 相关域名
address=/.netflix.com/
address=/.nflximg.net/
address=/.nflxvideo.net/
address=/.nflxso.net/

# Disney+ 相关域名
address=/.disneyplus.com/
address=/.disney.com/
address=/.dssott.com/

# HBO Max 相关域名
address=/.hbomax.com/
address=/.hbo.com/
address=/.warnermedia.com/

# Amazon Prime Video 相关域名
address=/.primevideo.com/
address=/.amazon.com/
address=/.amazonvideo.com/

# YouTube Premium 相关域名
address=/.youtube.com/
address=/.youtu.be/
address=/.googlevideo.com/

# Spotify 相关域名
address=/.spotify.com/
address=/.spoti.fi/
address=/.spotifycdn.com/

# Apple TV+ 相关域名
address=/.appletv.com/
address=/.apple.com/
address=/.itunes.apple.com/

# Paramount+ 相关域名
address=/.paramountplus.com/
address=/.cbs.com/
address=/.paramount.com/

# Peacock 相关域名
address=/.peacocktv.com/
address=/.nbc.com/
address=/.universalstudios.com/

# Crunchyroll 相关域名
address=/.crunchyroll.com/
address=/.funimation.com/
address=/.vrv.co/

# Hulu 相关域名
address=/.hulu.com/
address=/.disney.com/

# 亚洲流媒体服务相关域名
address=/.iqiyi.com/
address=/.v.qq.com/
address=/.qq.com/
address=/.youku.com/
address=/.bilibili.com/
address=/.acfun.cn/
address=/.tudou.com/
address=/.mgtv.com/

# 音乐流媒体服务相关域名
address=/.tidal.com/
address=/.deezer.com/
address=/.qqmusic.com/
address=/.kugou.com/
address=/.kuwo.cn/

# 体育流媒体服务相关域名
address=/.espn.com/
address=/.skysports.com/
address=/.nbcsports.com/
address=/.cbssports.com/

# 新闻流媒体服务相关域名
address=/.cnn.com/
address=/.bbc.com/
address=/.foxnews.com/
address=/.msnbc.com/
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
        ufw allow 53/tcp
        ufw allow 53/udp
    # 检查是否安装了firewalld
    elif command -v firewall-cmd &> /dev/null; then
        echo -e "${GREEN}使用firewalld配置防火墙...${NC}"
        firewall-cmd --permanent --add-port=53/tcp
        firewall-cmd --permanent --add-port=53/udp
        firewall-cmd --reload
    # 检查是否安装了iptables
    elif command -v iptables &> /dev/null; then
        echo -e "${GREEN}使用iptables配置防火墙...${NC}"
        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
        iptables -A INPUT -p udp --dport 53 -j ACCEPT
        # 保存iptables规则（不同系统保存方式不同）
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
    else
        echo -e "${YELLOW}未检测到可用的防火墙工具（ufw/firewalld/iptables）${NC}"
        echo -e "${YELLOW}请手动开放53端口以允许DNS服务访问${NC}"
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
    
    # 显示配置信息
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${GREEN}DNS解锁服务器配置完成！${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}DNS服务器IPv4: $ipv4_address${NC}"
    echo -e "${YELLOW}DNS端口: 53${NC}"
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    echo -e "${GREEN}请在中转机的分流配置中使用以下DNS服务器:${NC}"
    echo -e "${YELLOW}$ipv4_address${NC}"
    echo ""
    echo -e "${GREEN}配置示例（适用于大多数分流工具）:${NC}"
    echo -e "${YELLOW}- 类型: DNS${NC}"
    echo -e "${YELLOW}- 服务器地址: $ipv4_address${NC}"
    echo -e "${YELLOW}- 端口: 53${NC}"
    echo -e "${YELLOW}- 适用范围: AI服务和流媒体域名${NC}"
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}注意事项${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}1. 确保落地机的防火墙已开放53端口${NC}"
    echo -e "${YELLOW}2. 确保中转机可以访问落地机的53端口${NC}"
    echo -e "${YELLOW}3. 如需添加更多服务，请编辑 $DNSMASQ_CONF 文件${NC}"
    echo -e "${YELLOW}4. 如需限制访问，请使用白名单管理功能${NC}"
    echo -e "${YELLOW}5. 如需配置上游DNS，请使用上游DNS管理功能${NC}"
    echo ""

    read -p -e "${GREEN}按Enter键返回主菜单...${NC}"
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
    read -p -e "${GREEN}按Enter键返回...${NC}"
}

# 清空白名单
clear_whitelist() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${GREEN}清空白名单${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}警告：此操作将清空所有白名单规则！${NC}"
    read -p -e "${GREEN}确定要清空白名单吗？(y/N): ${NC}" confirm
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
    
    # 移除现有的server配置
    sed -i '/^server=/d' "$DNSMASQ_CONF"
    
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
        # 移除现有的server配置
        sed -i '/^server=/d' "$DNSMASQ_CONF"
        
        # 从备份中恢复server配置
        grep "^server=" "${DNSMASQ_CONF}.dns.bak" >> "$DNSMASQ_CONF"
        
        # 重启服务
        echo -e "${YELLOW}正在重启DNSmasq服务...${NC}"
        systemctl restart dnsmasq
        
        echo -e "${GREEN}上游DNS已成功恢复${NC}"
        echo -e "${YELLOW}当前上游DNS配置:${NC}"
        if grep -q "^server=" "$DNSMASQ_CONF"; then
            grep "^server=" "$DNSMASQ_CONF" | awk -F'=' '{print "  " $2}'
        else
            echo -e "  ${GREEN}使用系统默认DNS${NC}"
        fi
    else
        echo -e "${RED}上游DNS备份不存在${NC}"
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
    
    echo -e "${YELLOW}DNS服务器IPv4: $ipv4_address${NC}"
    echo -e "${YELLOW}DNS端口: 53${NC}"
    echo -e "${YELLOW}DNSmasq配置文件: $DNSMASQ_CONF${NC}"
    echo -e "${YELLOW}白名单配置文件: $WHITELIST_FILE${NC}"
    echo ""
    echo -e "${GREEN}服务状态:${NC}"
    systemctl status dnsmasq --no-pager
    echo ""
    read -p -e "${GREEN}按Enter键返回主菜单...${NC}"
}

# 还原原始配置
restore_config() {
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}还原原始配置${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}警告：此操作将还原到原始配置，删除所有解锁规则！${NC}"
    read -p -e "${GREEN}确定要还原原始配置吗？(y/N): ${NC}" confirm
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
            3) manage_upstream_dns ;;
            4) view_config ;;
            5) restore_config ;;
            0) echo -e "${GREEN}感谢使用DNS解锁服务器管理工具，再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; sleep 1 ;;
        esac
    done
}

# 执行主函数
main
