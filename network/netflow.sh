#!/bin/bash

# 默认监控网卡（如果未提供参数，默认使用 eth0）
NIC=${1:-eth0}

# 检查网卡是否存在
if ! grep -q "$NIC:" /proc/net/dev; then
    echo "错误: 未找到网卡 '$NIC'，请检查接口名称！"
    exit 1
fi

# 格式化流量单位函数
format_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}") MB/s"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}") KB/s"
    else
        echo "$bytes B/s"
    fi
}

echo "开始监控网卡 [$NIC] 流量 (按 Ctrl+C 退出)..."
echo "-----------------------------------------"

while true; do
    # 读取初始流量数据（接收字节数 和 发送字节数）
    RX_PREV=$(awk -v dev="$NIC" '$1 ~ dev {print $2}' /proc/net/dev)
    TX_PREV=$(awk -v dev="$NIC" '$1 ~ dev {print $10}' /proc/net/dev)

    # 间隔 1 秒
    sleep 1

    # 读取 1 秒后的流量数据
    RX_NEXT=$(awk -v dev="$NIC" '$1 ~ dev {print $2}' /proc/net/dev)
    TX_NEXT=$(awk -v dev="$NIC" '$1 ~ dev {print $10}' /proc/net/dev)

    # 计算 1 秒内的差值（速率）
    RX_BYTES=$((RX_NEXT - RX_PREV))
    TX_BYTES=$((TX_NEXT - TX_PREV))

    # 转换单位
    RX_SPEED=$(format_bytes $RX_BYTES)
    TX_SPEED=$(format_bytes $TX_BYTES)

    # 打印输出
    echo -e "[$(date '+%H:%M:%S')] 下载速度: \033[32m$RX_SPEED\033[0m \t 上传速度: \033[36m$TX_SPEED\033[0m"
done
