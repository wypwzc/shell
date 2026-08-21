#!/bin/bash

# ============================================
# 系统信息检测脚本
# 功能：检测IP地址、网卡、内存、磁盘、外网连通性
# ============================================

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m' # No Color

# 分隔线
SEPARATOR="=========================================="

echo -e "${BLUE}${SEPARATOR}${NC}"
echo -e "${BLUE}      系统信息检测报告${NC}"
echo -e "${BLUE}${SEPARATOR}${NC}"
echo ""

# ============================================
# 1. IP地址信息
# ============================================
echo -e "${YELLOW}[1] IP地址信息${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"

# 获取所有非回环的IPv4地址
echo -e "${GREEN}IPv4地址:${NC}"
ip -4 addr show | grep -v "lo" | grep inet | awk '{print $2}' | cut -d'/' -f1 | while read ip; do
    if [ -n "$ip" ]; then
        # 尝试获取对应的网卡名称
        iface=$(ip -4 addr show | grep -B2 "$ip" | head -1 | awk -F': ' '{print $2}')
        echo "  $iface: $ip"
    fi
done

# 如果没有找到，用备用方法
if [ -z "$(ip -4 addr show | grep -v lo | grep inet)" ]; then
    echo "  未找到IPv4地址"
fi

# 获取公网IP（外网IP）
echo ""
echo -e "${GREEN}公网IP:${NC}"
public_ip=$(curl -s --connect-timeout 5 ifconfig.me || curl -s --connect-timeout 5 ip.sb || curl -s --connect-timeout 5 icanhazip.com)
if [ -n "$public_ip" ]; then
    echo "  $public_ip"
else
    echo -e "  ${RED}无法获取公网IP${NC}"
fi

echo ""

# ============================================
# 2. 网卡信息
# ============================================
echo -e "${YELLOW}[2] 网卡信息${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"

# 方法1：使用ip命令
echo -e "${GREEN}网卡列表:${NC}"
for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
    # 获取MAC地址
    mac=$(cat /sys/class/net/$iface/address 2>/dev/null)
    # 获取IP地址
    ip_addr=$(ip -4 addr show $iface 2>/dev/null | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -1)
    # 获取网卡状态
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

# 如果没有网卡，提示
if [ -z "$(ls /sys/class/net/ 2>/dev/null | grep -v lo)" ]; then
    echo "  未找到网卡设备"
fi

# ============================================
# 3. 内存信息
# ============================================
echo -e "${YELLOW}[3] 内存信息${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"

# 获取内存信息（单位：MB）
total_mem=$(free -m | awk '/^Mem:/{print $2}')
used_mem=$(free -m | awk '/^Mem:/{print $3}')
free_mem=$(free -m | awk '/^Mem:/{print $4}')
available_mem=$(free -m | awk '/^Mem:/{print $7}')
swap_total=$(free -m | awk '/^Swap:/{print $2}')
swap_used=$(free -m | awk '/^Swap:/{print $3}')

# 计算使用率
usage_rate=$(awk "BEGIN {printf \"%.1f\", ($used_mem/$total_mem)*100}")

echo -e "${GREEN}物理内存:${NC}"
echo "  总内存:   ${total_mem} MB ($(awk "BEGIN {printf \"%.2f\", $total_mem/1024}") GB)"
echo "  已使用:   ${used_mem} MB"
echo "  空闲:     ${free_mem} MB"
echo "  可用:     ${available_mem} MB"
echo -e "  使用率:   ${usage_rate}%"

# 使用率颜色提示
if (( $(echo "$usage_rate > 90" | bc -l) )); then
    echo -e "  ${RED}⚠ 警告: 内存使用率过高！${NC}"
elif (( $(echo "$usage_rate > 75" | bc -l) )); then
    echo -e "  ${YELLOW}⚠ 注意: 内存使用率较高${NC}"
else
    echo -e "  ${GREEN}✓ 内存使用正常${NC}"
fi

if [ $swap_total -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Swap内存:${NC}"
    echo "  总Swap:   ${swap_total} MB"
    echo "  已使用:   ${swap_used} MB"
    swap_rate=$(awk "BEGIN {printf \"%.1f\", ($swap_used/$swap_total)*100}")
    echo "  使用率:   ${swap_rate}%"
fi

echo ""

# ============================================
# 4. 磁盘信息
# ============================================
echo -e "${YELLOW}[4] 磁盘信息${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"

# 显示磁盘分区使用情况（人类可读格式）
echo -e "${GREEN}磁盘分区使用情况:${NC}"
df -h | grep -v "tmpfs" | grep -v "udev" | grep -v "loop" | while read line; do
    # 提取使用率
    use=$(echo $line | awk '{print $5}' | sed 's/%//')
    filesystem=$(echo $line | awk '{print $1}')
    size=$(echo $line | awk '{print $2}')
    used=$(echo $line | awk '{print $3}')
    avail=$(echo $line | awk '{print $4}')
    mount=$(echo $line | awk '{print $6}')
    
    # 根据使用率显示不同颜色
    if [ -n "$use" ] && [ "$use" -gt 90 ] 2>/dev/null; then
        echo -e "  ${RED}$filesystem${NC}  $size 已用 $used 可用 $avail 使用率 ${RED}${use}%${NC}  挂载点: $mount"
    elif [ -n "$use" ] && [ "$use" -gt 75 ] 2>/dev/null; then
        echo -e "  ${YELLOW}$filesystem${NC}  $size 已用 $used 可用 $avail 使用率 ${YELLOW}${use}%${NC}  挂载点: $mount"
    else
        echo -e "  $filesystem  $size 已用 $used 可用 $avail 使用率 ${use}%  挂载点: $mount"
    fi
done

echo ""

# 显示磁盘设备列表
echo -e "${GREEN}物理磁盘设备:${NC}"
lsblk -d -o NAME,SIZE,MODEL,ROTA 2>/dev/null | grep -v "NAME" | while read line; do
    name=$(echo $line | awk '{print $1}')
    size=$(echo $line | awk '{print $2}')
    model=$(echo $line | awk '{$1=""; $2=""; print $0}' | sed 's/^[[:space:]]*//')
    echo "  /dev/$name  $size  $model"
done

# 如果没有lsblk，使用fdisk
if [ $? -ne 0 ]; then
    fdisk -l 2>/dev/null | grep "Disk /dev/" | grep -v "loop" | while read line; do
        echo "  $line"
    done
fi

echo ""

# ============================================
# 5. 外网连通性检测
# ============================================
echo -e "${YELLOW}[5] 外网连通性检测${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"

# 检测多个外网地址
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
    
    # 使用ping检测，超时2秒，只发1个包
    if ping -c 1 -W 2 "$site" > /dev/null 2>&1; then
        echo -e "  ✓ $name ($site)  ${GREEN}连通${NC}"
        ((success_count++))
    else
        echo -e "  ✗ $name ($site)  ${RED}不通${NC}"
    fi
done

echo ""

# 判断外网连通性
if [ $success_count -gt 0 ]; then
    echo -e "${GREEN}外网连通性: 正常 (${success_count}/${total_count} 个检测点可达)${NC}"
else
    echo -e "${RED}外网连通性: 异常 (所有检测点均不可达)${NC}"
    echo -e "${YELLOW}建议: 检查网络连接、DNS配置或防火墙设置${NC}"
fi

echo ""

# ============================================
# 6. 额外信息：系统负载
# ============================================
echo -e "${YELLOW}[6] 系统负载${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
uptime_output=$(uptime)
echo "  $uptime_output"
echo ""

# ============================================
# 结束
# ============================================
echo -e "${BLUE}${SEPARATOR}${NC}"
echo -e "${GREEN}检测完成！${NC}"
echo -e "${BLUE}${SEPARATOR}${NC}"