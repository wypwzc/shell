#!/bin/bash
# ============================================
# 系统信息检测脚本（v2.0）
# ============================================

# 颜色定义（亮色）
RED='\033[31m'
GREEN='\033[92m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'
SEPARATOR="=========================================="

echo -e "${BLUE}${SEPARATOR}${NC}"
echo -e "${BLUE}      系统信息检测报告${NC}"
echo -e "${BLUE}${SEPARATOR}${NC}"
echo ""

# 1. IP地址信息
echo -e "${YELLOW}[1] IP地址信息${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
echo -e "${GREEN}IPv4地址:${NC}"
ip -4 addr show | grep -v "lo" | grep inet | awk '{print $2}' | cut -d'/' -f1 | while read ip; do
    if [ -n "$ip" ]; then
        iface=$(ip -4 addr show | grep -B2 "$ip" | head -1 | awk -F': ' '{print $2}')
        echo "  $iface: $ip"
    fi
done
if [ -z "$(ip -4 addr show | grep -v lo | grep inet)" ]; then
    echo "  未找到IPv4地址"
fi
echo ""
echo -e "${GREEN}公网IP:${NC}"
public_ip=$(curl -s --connect-timeout 5 ifconfig.me || curl -s --connect-timeout 5 ip.sb || curl -s --connect-timeout 5 icanhazip.com)
if [ -n "$public_ip" ]; then
    echo "  $public_ip"
else
    echo -e "  ${RED}无法获取公网IP${NC}"
fi
echo ""

# 2. 网卡信息（仅物理网卡）
echo -e "${YELLOW}[2] 网卡信息（物理网卡）${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
echo -e "${GREEN}网卡列表:${NC}"
physical_nics=$(ls /sys/class/net/ 2>/dev/null | grep -v -F -f <(ls /sys/devices/virtual/net/ 2>/dev/null))
if [ -z "$physical_nics" ]; then
    echo "  未找到物理网卡设备"
else
    for iface in $physical_nics; do
        mac=$(cat /sys/class/net/$iface/address 2>/dev/null)
        ip_addr=$(ip -4 addr show $iface 2>/dev/null | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -1)
        state=$(cat /sys/class/net/$iface/operstate 2>/dev/null)
        echo "  ┌─ 网卡: $iface"
        echo "  ├─ 状态: $state"
        echo "  ├─ MAC:  $mac"
        if [ -n "$ip_addr" ]; then
            echo "  └─ IP:   $ip_addr"
        else
            echo "  └─ IP:   无"
        fi
        echo ""
    done
fi

# 3. 内存信息（精简：总容量、可用、条数组合）
echo -e "${YELLOW}[3] 内存信息${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
total_mem=$(free -m | awk '/^Mem:/{print $2}')
available_mem=$(free -m | awk '/^Mem:/{print $7}')
total_gb=$(awk "BEGIN {printf \"%.2f\", $total_mem/1024}")
available_gb=$(awk "BEGIN {printf \"%.2f\", $available_mem/1024}")
echo -e "${GREEN}内存容量:${NC}"
echo "  总内存:   ${total_gb} GB"
echo "  可用内存: ${available_gb} GB"
echo ""
echo -e "${GREEN}内存条组成:${NC}"
if command -v dmidecode &>/dev/null; then
    # 提取所有已安装内存的 Size（过滤未安装的插槽）
    sizes=$(dmidecode -t memory 2>/dev/null | awk -F: '/Size:/ {size=$2; gsub(/^[ \t]+/,"",size); if (size !~ /No Module Installed/ && size !~ /Not Installed/) print size}')
    if [ -n "$sizes" ]; then
        # 统计每种容量出现的次数，并保留单位（如 "32 GB"）
        echo "$sizes" | sort | uniq -c | awk '{print "  " $2 " " $3 " x " $1}'
    else
        echo -e "  ${YELLOW}无法获取内存条组成（可能需要root权限）${NC}"
    fi
else
    echo -e "  ${YELLOW}dmidecode未安装，无法获取内存条组成${NC}"
fi
echo ""

# 4. 磁盘信息（简化）
echo -e "${YELLOW}[4] 磁盘信息${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
echo -e "${GREEN}物理磁盘设备:${NC}"
lsblk -d -o NAME,SIZE,MODEL,ROTA 2>/dev/null | grep -v "NAME" | while read -r name size model rota; do
    if [ "$rota" == "1" ]; then
        type="HDD"
    else
        type="SSD"
    fi
    echo "  /dev/$name  $size  $type  $model"
done
total_bytes=$(lsblk -d -b -o SIZE 2>/dev/null | grep -v "SIZE" | awk '{sum+=$1} END {print sum}')
if [ -n "$total_bytes" ] && [ "$total_bytes" -gt 0 ]; then
    total_gb=$(awk "BEGIN {printf \"%.2f\", $total_bytes/1024/1024/1024}")
    if (( $(echo "$total_gb > 1024" | bc -l) )); then
        total_tb=$(awk "BEGIN {printf \"%.2f\", $total_gb/1024}")
        echo -e "${GREEN}总容量: ${total_tb} TB${NC}"
    else
        echo -e "${GREEN}总容量: ${total_gb} GB${NC}"
    fi
else
    echo -e "${YELLOW}未能获取磁盘容量信息${NC}"
fi
echo ""

# 5. 外网连通性检测
echo -e "${YELLOW}[5] 外网连通性检测${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
test_sites=(
    "114.114.114.114:114DNS"
    "8.8.8.8:Google DNS"
    "1.1.1.1:Cloudflare DNS"
    "baidu.com:百度"
    "qq.com:腾讯"
)
success_count=0
total_count=${#test_sites[@]}
echo -e "${GREEN}正在检测外网连通性...${NC}"
echo ""
for site_info in "${test_sites[@]}"; do
    site="${site_info%:*}"
    name="${site_info#*:}"
    if ping -c 1 -W 2 "$site" > /dev/null 2>&1; then
        echo -e "  ✓ $name ($site)  ${GREEN}连通${NC}"
        ((success_count++))
    else
        echo -e "  ✗ $name ($site)  ${RED}不通${NC}"
    fi
done
echo ""
if [ $success_count -gt 0 ]; then
    echo -e "${GREEN}外网连通性: 正常 (${success_count}/${total_count} 个检测点可达)${NC}"
else
    echo -e "${RED}外网连通性: 异常 (所有检测点均不可达)${NC}"
    echo -e "${YELLOW}建议: 检查网络连接、DNS配置或防火墙设置${NC}"
fi
echo ""

# 6. 系统负载
echo -e "${YELLOW}[6] 系统负载${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
uptime_output=$(uptime)
echo "  $uptime_output"
echo ""

# 7. 内核版本与Docker版本
echo -e "${YELLOW}[7] 系统内核与Docker版本${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
echo -e "${GREEN}内核版本:${NC} $(uname -r)"
if command -v docker &>/dev/null; then
    docker_ver=$(docker -v 2>/dev/null | awk '{print $3}' | sed 's/,//')
    echo -e "${GREEN}Docker版本:${NC} $docker_ver"
else
    echo -e "${RED}Docker未安装${NC}"
fi
echo ""

echo -e "${BLUE}${SEPARATOR}${NC}"
echo -e "${GREEN}检测完成！${NC}"
echo -e "${BLUE}${SEPARATOR}${NC}"
