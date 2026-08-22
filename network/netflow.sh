#!/usr/bin/env bash

function state_flow() {
    # 精妙的核心点：取差集，自动剔除所有虚拟网卡，只留真实物理网卡
    _nic="$(grep -v -f <(ls -1 /sys/devices/virtual/net/ 2>/dev/null) <(ls -1 /sys/class/net/ 2>/dev/null))"

    if [ -z "$_nic" ]; then
        echo "错误: 未检测到任何物理网卡！"
        exit 1
    fi

    echo -e "已自动识别物理网卡: \033[1;32m$(echo $_nic)\033[0m"
    echo "开始实时监控 (按 Ctrl+C 退出)..."
    echo "-----------------------------------------"

    get_flow() {
        _tx=0
        _rx=0
        for item in ${_nic}; do
            _tx="$(($(cat /sys/class/net/${item}/statistics/tx_bytes 2>/dev/null) + ${_tx}))"
            _rx="$(($(cat /sys/class/net/${item}/statistics/rx_bytes 2>/dev/null) + ${_rx}))"
        done
    }

    # 单位格式化函数（兼顾 Mbps 与 KB/s，更直观）
    format_speed() {
        local bytes=$1
        local mbps=$(awk "BEGIN {printf \"%.2f\", $bytes * 8 / 1000000}")
        local mbytes=$(awk "BEGIN {printf \"%.2f\", $bytes / 1048576}")
        
        if [ $(echo "$mbps >= 1" | bc 2>/dev/null || awk "BEGIN {print ($mbps >= 1)}") -eq 1 ]; then
            printf "%6.1f Mbps (%5.1f MB/s)" "$mbps" "$mbytes"
        else
            local kbytes=$(awk "BEGIN {printf \"%.1f\", $bytes / 1024}")
            printf "%6.1f KB/s               " "$kbytes"
        fi
    }

    while :; do
        get_flow
        _rx_1="${_rx}"
        _tx_1="${_tx}"
        
        sleep 1
        
        get_flow
        _rx_speed="$((_rx - _rx_1))"
        _tx_speed="$((_tx - _tx_1))"
        
        _time=$(date +%H:%M:%S)
        
        _rx_fmt=$(format_speed $_rx_speed)
        _tx_fmt=$(format_speed $_tx_speed)
        
        echo -e "[$_time] 下载: \033[32m$_rx_fmt\033[0m \t 上传: \033[36m$_tx_fmt\033[0m"
    done
}

state_flow
