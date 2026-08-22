#!/usr/bin/env bash
# 实时网卡速率查看
# shellcheck disable=SC2004,SC2086

function state_flow() {
    get_flow() {
        _tx=0
        _rx=0
        for item in ${_nic}; do
            _tx="$(($(cat /sys/class/net/${item}/statistics/tx_bytes 2>/dev/null) + ${_tx}))"
            _rx="$(($(cat /sys/class/net/${item}/statistics/rx_bytes 2>/dev/null) + ${_rx}))"
        done
    }
    _nic="$(grep -v -f <(ls -1 /sys/devices/virtual/net/ 2>/dev/null) <(ls -1 /sys/class/net/ 2>/dev/null))"
    while :; do
        get_flow
        _rx_1="${_rx}"
        _tx_1="${_tx}"
        sleep 1
        get_flow
        _results_rx=0
        _results_tx=0
        _results_rx="$(((_rx - _rx_1) / 131072))"
        _results_tx="$(((_tx - _tx_1) / 131072))"
        _time=$(date +%H:%M:%S)
        printf "time: $_time   TX: %04d Mbps   RX: %04d Mbps\n" "$_results_tx" "$_results_rx"
    done
}
state_flow

