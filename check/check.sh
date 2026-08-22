#!/bin/bash
# ============================================
# 系统信息检测脚本（v2.1）
# ============================================

# 颜色定义（亮色）
RED='\033[31m'
GREEN='\033[92m'
YELLOW='\033[33m'
WHITE='\033[37m'          # 用于标题和分隔线
BLUE='\033[34m'           # 用于章节标题
NC='\033[0m'
SEPARATOR="=========================================="

echo -e "${WHITE}${SEPARATOR}${NC}"
echo -e "${WHITE}      系统信息检测报告${NC}"
echo -e "${WHITE}${SEPARATOR}${NC}"
echo ""

# 1. IP地址信息（只显示公网IP和MAC地址）
echo -e "${BLUE}[1] IP地址信息${NC}"
echo -e "${BLUE}------------------------------------------${NC}"
echo -e "${GREEN}公网IP:${NC}"
public_ip=$(curl -s --connect-timeout 5 ifconfig.me || curl -s --connect-timeout 5 ip.sb || curl -s --connect-timeout 5 icanhazip.com)
if [ -n "$public_ip" ]; then
    echo "  $public_ip"
else
    echo -e "  ${RED}无法获取公网IP${NC}"
fi
echo ""
echo -e "${GREEN}物理网卡MAC地址:${NC}"
physical_nics=$(ls /sys/class/net/ 2>/dev/null | grep -v -F -f <(ls /sys/devices/virtual/net/ 2>/dev/null))
if [ -z "$physical_nics" ]; then
    echo "  未找到物理网卡"
else
    for iface in $physical_nics; do
        mac=$(cat /sys/class/net/$iface/address 2>/dev/null)
        echo "  $iface : $mac"
    done
fi
echo ""

# 2. 网卡信息（仅物理网卡，up状态绿色高亮，移除IP无）
echo -e "${BLUE}[2] 网卡信息（物理网卡）${NC}"
echo -e "${BLUE}------------------------------------------${NC}"
physical_nics=$(ls /sys/class/net/ 2>/dev/null | grep -v -F -f <(ls /sys/devices/virtual/net/ 2>/dev/null))
if [ -z "$physical_nics" ]; then
    echo "  未找到物理网卡设备"
else
    for iface in $physical_nics; do
        mac=$(cat /sys/class/net/$iface/address 2>/dev/null)
        ip_addr=$(ip -4 addr show $iface 2>/dev/null | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -1)
        state=$(cat /sys/class/net/$iface/operstate 2>/dev/null)
        # 构建信息块
        info="  ┌─ 网卡: $iface\n  ├─ 状态: $state\n  ├─ MAC:  $mac"
        # 如果有IP则添加IP行
        if [ -n "$ip_addr" ]; then
            info="$info\n  └─ IP:   $ip_addr"
        fi
        # 如果状态为up，整块绿色高亮
        if [ "$state" = "up" ]; then
            echo -e "${GREEN}${info}${NC}"
        else
            echo -e "$info"
        fi
        echo ""
    done
fi

# 3. 内存信息
echo -e "${BLUE}[3] 内存信息${NC}"
echo -e "${BLUE}------------------------------------------${NC}"
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
    sizes=$(dmidecode -t memory 2>/dev/null | awk -F: '/Size:/ {size=$2; gsub(/^[ \t]+/,"",size); if (size !~ /No Module Installed/ && size !~ /Not Installed/) print size}')
    if [ -n "$sizes" ]; then
        echo "$sizes" | sort | uniq -c | awk '{print "  " $2 " " $3 " x " $1}'
    else
        echo -e "  ${YELLOW}无法获取内存条组成（可能需要root权限）${NC}"
    fi
else
    echo -e "  ${YELLOW}dmidecode未安装，无法获取内存条组成${NC}"
fi
echo ""

# 4. 磁盘信息（增加磁盘数量显示）
echo -e "${BLUE}[4] 磁盘信息${NC}"
echo -e "${BLUE}------------------------------------------${NC}"
# 获取磁盘列表并统计数量
disk_list=$(lsblk -d -o NAME,SIZE,MODEL,ROTA 2>/dev/null | grep -v "NAME")
disk_count=$(echo "$disk_list" | wc -l)
echo -e "${GREEN}物理磁盘设备: ${disk_count}个${NC}"
echo "$disk_list" | while read -r name size model rota; do
    if [ "$rota" == "1" ]; then
        type="HDD"
    else
        type="SSD"
    fi
    echo "  /dev/$name  $size  $type  $model"
done
# 计算总容量
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

# 5. 外网连通性检测（仅223.5.5.5和baidu.com，加curl cip.cc）
echo -e "${BLUE}[5] 外网连通性检测${NC}"
echo -e "${BLUE}------------------------------------------${NC}"
test_sites=(
    "223.5.5.5:阿里DNS"
    "baidu.com:百度"
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
# 新增 curl cip.cc 输出
echo -e "${GREEN}IP归属地信息 (cip.cc):${NC}"
curl -s cip.cc | sed 's/^/  /'
echo ""

# 6. 系统负载与CPU使用率
echo -e "${BLUE}[6] 系统负载与CPU使用率${NC}"
echo -e "${BLUE}------------------------------------------${NC}"
uptime_output=$(uptime)
echo "  系统负载: $uptime_output"
echo ""
# 获取CPU使用率（us, sy, wa, id）
cpu_line=$(top -bn1 | grep "Cpu(s)" | head -1)
if [ -n "$cpu_line" ]; then
    # 尝试多种格式解析
    us=$(echo "$cpu_line" | awk -F'us,' '{print $1}' | awk '{print $NF}' | sed 's/[^0-9.]//g')
    sy=$(echo "$cpu_line" | awk -F'sy,' '{print $1}' | awk '{print $NF}' | sed 's/[^0-9.]//g')
    wa=$(echo "$cpu_line" | awk -F'wa,' '{print $1}' | awk '{print $NF}' | sed 's/[^0-9.]//g')
    id=$(echo "$cpu_line" | awk -F'id,' '{print $1}' | awk '{print $NF}' | sed 's/[^0-9.]//g')
    if [ -z "$us" ] || [ -z "$sy" ] || [ -z "$wa" ] || [ -z "$id" ]; then
        fields=($(echo "$cpu_line" | awk '{print $2, $4, $6, $8, $10}' | tr -d ','))
        us=${fields[0]}
        sy=${fields[1]}
        id=${fields[3]}
        wa=${fields[4]}
        if [ -z "$us" ] || [ -z "$id" ]; then
            us=$(echo "$cpu_line" | awk '{print $2}' | cut -d'%' -f1)
            sy=$(echo "$cpu_line" | awk '{print $4}' | cut -d'%' -f1)
            wa=$(echo "$cpu_line" | awk '{print $10}' | cut -d'%' -f1)
            id=$(echo "$cpu_line" | awk '{print $8}' | cut -d'%' -f1)
        fi
    fi
    if [ -n "$id" ] && [ "$id" != "" ]; then
        total=$(awk "BEGIN {printf \"%.1f\", 100 - $id}")
        us=${us:-0}
        sy=${sy:-0}
        wa=${wa:-0}
        echo -e "${GREEN}CPU使用率:${NC} ${total}%  (us: ${us}%, sy: ${sy}%, wa: ${wa}%)"
    else
        echo -e "${YELLOW}无法解析CPU使用率（未获取到idle值）${NC}"
    fi
else
    echo -e "${YELLOW}无法获取CPU信息（top命令可能不支持）${NC}"
fi
echo ""

# 7. 内核版本与Docker版本
echo -e "${BLUE}[7] 系统内核与Docker版本${NC}"
echo -e "${BLUE}------------------------------------------${NC}"
echo -e "${GREEN}内核版本:${NC} $(uname -r)"
if command -v docker &>/dev/null; then
    docker_ver=$(docker -v 2>/dev/null | awk '{print $3}' | sed 's/,//')
    echo -e "${GREEN}Docker版本:${NC} $docker_ver"
else
    echo -e "${RED}Docker未安装${NC}"
fi
echo ""

echo -e "${WHITE}${SEPARATOR}${NC}"
echo -e "${GREEN}检测完成！${NC}"
echo -e "${WHITE}${SEPARATOR}${NC}"
