# DNS解锁服务器一键配置

这是一个用于将落地机配置为DNS解锁服务器的一键脚本，专门用于解锁AI服务（如OpenAI、Anthropic等）。当您有一台可以解锁AI但线路不好的落地机，和一台线路好但无法解锁AI的中转机时，此脚本可以帮助您快速将落地机配置为DNS解锁服务器，让中转机通过它来解锁所有AI服务。

## 功能特性

- 🚀 **一键配置**：自动安装和配置DNSmasq
- 🔓 **解锁多种AI服务**：支持OpenAI、Anthropic、Google AI、Microsoft AI、Meta AI等
- 🌐 **全局可用**：监听所有网络接口，支持多设备使用
- 🛡️ **安全配置**：自动配置防火墙，开放必要端口
- 📝 **详细日志**：提供清晰的安装和配置过程反馈

## 支持的AI服务

| 服务名称 | 域名 | 解锁状态 |
|---------|------|----------|
| OpenAI | openai.com | ✅ |
| Anthropic | anthropic.com | ✅ |
| Google AI | googleapis.com | ✅ |
| Microsoft AI | microsoft.com | ✅ |
| Meta AI | meta.com | ✅ |
| Cohere | cohere.com | ✅ |
| Perplexity | perplexity.ai | ✅ |
| Claude | claude.ai | ✅ |

## 系统要求

- Linux操作系统（Ubuntu、Debian等基于apt的系统）
- Root用户权限
- 可以解锁AI服务的网络环境
- 稳定的网络连接

## 快速开始

### 1. 直接在落地机上运行脚本

无需克隆仓库，直接使用以下命令运行：

```bash
bash <(curl -s https://raw.githubusercontent.com/yourusername/dns-unlock-server/main/setup_dns_unlock.sh)
```

### 2. 配置中转机

脚本运行完成后，会显示落地机的公网IP地址。在中转机的分流配置中，将DNS服务器设置为该IP地址，并确保AI服务的流量通过此DNS解析。

#### 配置示例（适用于大多数分流工具）：
- **类型**：DNS
- **服务器地址**：`落地机公网IP`
- **端口**：53
- **适用范围**：AI服务域名

## 技术原理

1. **DNSmasq**：轻量级DNS服务器，用于拦截和重定向特定域名的解析
2. **域名解析规则**：通过直接指定AI服务域名的IP地址，绕过地区限制
3. **网络流量**：中转机将AI服务的DNS请求发送到落地机，落地机返回解锁后的IP地址，中转机再根据此IP进行流量转发

## 自定义配置

### 添加更多AI服务

编辑DNSmasq配置文件，添加新的域名解析规则：

```bash
nano /etc/dnsmasq.conf
```

添加格式如下的规则：

```conf
# 服务名称
domain=example.com
address=/example.com/IP地址
```

保存后重启DNSmasq服务：

```bash
systemctl restart dnsmasq
```

### 修改上游DNS服务器

默认使用Google DNS（8.8.8.8和8.8.4.4），您可以根据需要修改为其他DNS服务器：

```bash
nano /etc/dnsmasq.conf
```

找到并修改以下行：

```conf
# 上游DNS服务器
server=8.8.8.8
server=8.8.4.4
```

## 故障排查

### 服务启动失败

检查DNSmasq服务状态：

```bash
systemctl status dnsmasq
```

### 端口被占用

检查53端口占用情况：

```bash
netstat -tulpn | grep :53
```

### 防火墙问题

确保防火墙已开放53端口：

```bash
ufw status
```

如果需要手动开放端口：

```bash
ufw allow 53/tcp
ufw allow 53/udp
```

## 安全注意事项

1. **仅用于合法用途**：请确保您的使用符合当地法律法规
2. **限制访问**：如需增强安全性，可在DNSmasq配置中限制允许访问的IP范围
3. **定期更新**：定期更新系统和脚本，以适应AI服务的IP变化

## 许可证

本项目采用MIT许可证 - 详情请参阅[LICENSE](LICENSE)文件

## 贡献

欢迎提交Issue和Pull Request，帮助改进此项目！

## 联系方式

如果您有任何问题或建议，请通过GitHub Issues与我联系。
