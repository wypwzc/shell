#!/usr/bin/env bash

function state_flow() {
    # 1. 提取所有物理网卡（排除虚拟网卡）
    _all_phy_nic="$(grep -v -f <(ls -1 /sys/devices/virtual/net/ 2>/dev/null) <(ls -1 /sys/class/net/ 2>/dev/null))"
    
    # 2. 进一步过滤，只保留状态为 UP 的物理网卡
    _nic=""
    for item in ${_all_phy_nic}; do
        _state="$(cat /sys/class/net/${item}/operstate 2>/dev/null)"
        if [ "$_state" = "up" ]; then
            _nic="${_nic} ${item}"
        fi
    done

    # 移除首尾多余空格
    _nic="$(echo $_nic | xargs)"

    if [ -z "$_nic" ]; then
        echo "错误: 未检测到任何处于 UP (激活) 状态的物理网卡！"
        exit 1
    fi

    echo -e "物理网卡(up): \033[1;32m${_nic}\033[0m"
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

    format_speed() {
        local bytes=$1
        local mbps=$(awk "BEGIN {printf \"%.1f\", $bytes * 8 / 1000000}")
        local mbytes=$(awk "BEGIN {printf \"%.1f\", $bytes / 1048576}")
        
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
