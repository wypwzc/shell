#!/usr/bin/env bash
# 拨号状态查看
# shellcheck disable=SC2001,SC2004,SC2086,SC2143

HMBHZT() {
    # nft速率记录
    read -r -d '' cmd <<"EEE"
_table="f_o_n_i"
nft delete table inet $_table 2>/dev/null
nft create table inet $_table 
nft add chain inet $_table output '{ type filter hook output priority 0; }'
_vnic=$(ip -br a | grep '\s[0-9.]{7,15}' -E | grep '^(mac|ppp)[0-9a-z]{12}' -Eo)
nft add rule inet $_table output oifname "$_vnic" counter 2>/dev/null
speed_one="$(nft list table inet f_o_n_i | grep 'oifname' | awk '{print $2$7}' | awk -F'"' '{print $2,$3}')"
sleep 2
speed_two="$(nft list table inet f_o_n_i | grep 'oifname' | awk '{print $2$7}' | awk -F'"' '{print $2,$3}')"
echo -e "$speed_two\n$speed_one"
EEE

    IPMI_ip=$(ipmitool lan print 2>/dev/null | grep 'IP Address[[:space:]]*:' | awk '{print $NF}')
    sort_ps=$(echo "$IPMI_ip" | awk -F. '{printf "%03d%03d%01d\n",$2,$3,$4}')
    [[ -z $IPMI_ip ]] && IPMI_ip="X:X" && sort_ps="0000000"
    if grep -qi "Ubuntu" /etc/os-release && [ -f /usr/local/bin/m-netctl ]; then
        # Ubuntu m-netctl 拨号状态
        if [[ "$(ip r | head -1 | grep -Eo "dev m\-ss\-[0-z]{10}" | awk '{print $2}')" = "m-ms-main" ]]; then
            echo -e "\e[31m默认路由丢失;请重启网络服务\e[0m"
            exit 1
        fi
        arp_n_all=$(arp -n)
        DCBc=$(m-netctl data export --data-export-format text | grep -v "Comment\|^$")
        MACc=$(echo "$DCBc" | awk '{print $5}')
        IPRA=$(ip r | grep -v "default\|m-ms\|docker\|linkdown")
        UBTB() {
            local Mac=$1
            local ZHHAO MacC BOIP BOtime _IFwk _calculate_1 _calculate_2 SPeed NWIP GDIP _IFgw _GWIP _PZIP arp_mac CS_Ping CS_Curl RIZI ERRORS KEY SBYY
            ZHHAO=$(echo "$DCBc" | grep "$Mac" | awk '{printf "%18s\t%9s\t%10s\t%4s\t%18s\t%8s\n",$5,$7".Mbps",$4,$3,$1,$2}')
            _status=$(echo "$DCBc" | grep "$Mac" | awk '{print $6}')
            MacC=$(echo "$Mac" | tr -d ':')
            BOIP=$(echo "$IPRA" | grep ppp$MacC | awk '{print $9}')
            BOtime=$(head -1 /var/log/pppoe/ppp$MacC.log 2>/dev/null | awk -F- '{print $2"-"$3}')
            if [[ "$_status" = 0 ]]; then
                echo -e "\033[33m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-失败\t未启用账号\033[0m"
            elif [[ -n "$BOIP" ]]; then
                # PPPoE获取IP
                _IFwk=$(echo "$IPRA" | grep "$MacC" | awk '{print $3}')
                _calculate_1=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                sleep 6s
                _calculate_2=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                SPeed="$(echo "$((_calculate_2 - _calculate_1)) / 6 * 8" | bc -l | awk '{printf("%04d\n", $0/1000000)}')"
                NWIP=$(echo "$BOIP" | grep '^10\.\|^192\.168\.\|^100\.\|^172\.')
                if [ -z "$NWIP" ]; then
                    echo -e "\033[32m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-成功\t$SPeed\t$BOtime\t$BOIP\033[0m"
                else
                    echo -e "\033[36m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-内网\t$SPeed\t$BOtime\t$BOIP\033[0m"
                fi
            elif [[ -n "$(echo "$ZHHAO" | grep "/")" ]]; then
                # 固定IP测试是否通网
                GDIP=$(echo "$ZHHAO" | awk '{print $5}' | awk -F "/" '{print $1}')
                _IFwk=$(echo "$IPRA" | grep "$GDIP" | awk '{print $3}')
                _IFgw=$(echo "$DCBc" | grep "$GDIP" | awk '{print $2}')
                #ping -I "$_IFwk" -c1 "$_IFgw" >/dev/null 2>&1 && CS_Pinggw=0 || CS_Pinggw=1
                arp_mac=$(echo "$arp_n_all" | grep "$_IFwk" | grep "$_IFgw" | grep -Eo "([0-9a-f]{2}\:){5}[0-9a-f]{2}|incomplete")
                ping -I "$_IFwk" -c2 223.5.5.5 >/dev/null 2>&1 && CS_Ping=0 || CS_Ping=1
                curl -m 10 --interface "$_IFwk" -4IL qq.com >/dev/null 2>&1 && CS_Curl=0 || CS_Curl=1
                for ((i = 1; i <= 3; i++)); do
                    _GWIP=$(curl -m 10 --interface "$_wk" -4L ip.sb 2>/dev/null | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -1)
                    [[ -n "$_GWIP" ]] && break
                    [[ $i -lt 3 ]] && sleep 3
                done
                _PZIP=$(echo "$IPRA" | grep "$_IFwk" 2>/dev/null | awk '{print $NF}' | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
                if [[ -z "$_IFwk" ]]; then
                    echo -e "\033[33m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-失败\t未启用账号\033[0m"
                #elif [[ -n "$_IFgw" ]] && [[ "$CS_Pinggw" = 1 ]]; then
                elif [[ "$arp_mac" = "incomplete" ]] || [ -z "$arp_mac" ]; then
                    _calculate_1=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    sleep 2s
                    _calculate_2=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    SPeed="$(echo "$((_calculate_2 - _calculate_1)) / 2 * 8" | bc -l | awk '{printf("%04d\n", $0/1000000)}')"
                    echo -e "\033[31m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-失败\t$SPeed\t\033[0m\033[31m网关不通;未获取到arp_mac\033[0m"
                elif [[ -z "$_GWIP" ]]; then
                    _calculate_1=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    sleep 2s
                    _calculate_2=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    SPeed="$(echo "$((_calculate_2 - _calculate_1)) / 2 * 8" | bc -l | awk '{printf("%04d\n", $0/1000000)}')"
                    echo -e "\033[32m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-成功\t$SPeed\t\033[0m\033[31m公网ip获取失败(可以尝试换mac地址)\033[0m"
                elif [[ "$_GWIP" != "$_PZIP" ]]; then
                    _calculate_1=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    sleep 2s
                    _calculate_2=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    SPeed="$(echo "$((_calculate_2 - _calculate_1)) / 2 * 8" | bc -l | awk '{printf("%04d\n", $0/1000000)}')"
                    echo -e "\033[32m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-成功\t$SPeed\t\033[0m\033[31m公网ip不相等\"$_GWIP\"\033[0m"
                elif [ "$CS_Ping" -eq 0 ] || [ "$CS_Curl" -eq 0 ]; then
                    _calculate_1=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    sleep 2s
                    _calculate_2=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    SPeed="$(echo "$((_calculate_2 - _calculate_1)) / 2 * 8" | bc -l | awk '{printf("%04d\n", $0/1000000)}')"
                    echo -e "\033[32m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-成功\t$SPeed\033[0m"
                else
                    _calculate_1=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    sleep 2s
                    _calculate_2=$(awk 'NF' /proc/net/dev | grep "$_IFwk" | awk '{print $10}')
                    SPeed="$(echo "$((_calculate_2 - _calculate_1)) / 2 * 8" | bc -l | awk '{printf("%04d\n", $0/1000000)}')"
                    echo -e "\033[31m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-失败\t$SPeed\033[0m"
                fi
            else
                # PPPoE失败原因
                RIZI=$(grep -vE "\[|PPP|dst|PADS:|Connect|Re|sing|Terminating|Plugin" /var/log/pppoe/ppp$MacC.log 2>/dev/null)
                unset SBYY
                declare -A ERRORS=(
                    ["PADO"]="PADO线路不通"
                    ["PADS"]="PADS报文超时(mac连接请求过多,触发封锁)"
                    ["Modem"]="调制解调器的难题"
                    ["CHAP authentication failed: Authentication fail"]="CHAP身份验证失败"
                    ["PAP authentication failed"]="PAP身份验证失败"
                    ["UserName_Err"]="用户名错误"
                    ["BlackList user"]="黑名单用户"
                    ["User Locked"]="用户锁定"
                )
                for KEY in "${!ERRORS[@]}"; do
                    if echo "$RIZI" | grep -q "$KEY"; then
                        SBYY="$SBYY ${ERRORS[$KEY]}"
                    fi
                done
                echo -e "\033[31m$sort_ps\t$IPMI_ip\t$ZHHAO\t拨号-失败\t$SBYY\033[0m"
            fi
        }
        for Mac in $MACc; do
            UBTB "$Mac" &
        done
        wait
    elif grep -q "MAC=" /data/kuaicdn/network/ipv4_static_ip.txt 2>/dev/null && ip r | grep -qEo "dev mac[0-z]*"; then
        # 腾讯多IP拨号
        _ipr=$(ip r | grep -v default)
        WangKa=$(echo "$_ipr" | grep -Eo "dev mac[0-z]*" | awk '{print $NF}')
        arp_n_all=$(arp -n)
        TX_wk_curl() {
            local _wk=$1
            local _GWIP _ipaddr _ipv4_ip _gateway _vlan _MAC _ipv4_v4 v6_GWIP v6_status v6_ipmask v6_gateway
            # 账号通网测试
            curl -m 10 --interface "$_wk" -4IL qq.com >/dev/null 2>&1 && CS_Curl=0 || CS_Curl=1
            for ((i = 1; i <= 3; i++)); do # V4 测试
                _GWIP=$(curl -m 10 --interface "$_wk" -4L ip.sb 2>/dev/null | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -1)
                [[ -n "$_GWIP" ]] && break
                [[ $i -lt 3 ]] && sleep 3
            done
            _ipaddr=$(echo "$_ipr" | grep "$_wk" | grep -Eo "src [0-9.]+" | awk '{print $NF}')
            _gateway=$(grep "$_ipaddr/" /root/network/ipv4_static_ip.txt | awk -F "IPV4_GATEWAY=" '{print $2}' | awk '{print $1}')
            ping -I "$_wk" -c2 "$_gateway" >/dev/null 2>&1 && CS_Ping=0 || CS_Ping=1
            # 账号信息获取
            _vlan=$(grep "$_ipaddr/" /root/network/ipv4_static_ip.txt | awk -F "VLAN=" '{print $2}' | awk '{print $1}')
            _MAC=$(grep "$_ipaddr/" /root/network/ipv4_static_ip.txt | awk -F "MAC=" '{print $2}' | awk '{print $1}')
            _ipv4_ip=$(grep "$_ipaddr/" /root/network/ipv4_static_ip.txt | awk -F "IPV4_MASK=" '{print $2}' | awk '{print $1}')
            _ipv4_v4=$(echo "$_ipv4_ip" | awk -F/ '{print $1}')
            v6_ipmask=$(grep "$_ipaddr/" /root/network/ipv4_static_ip.txt | awk -F "IPV6_MASK=" '{print $2}' | awk '{print $1}')
            v6_gateway=$(grep "$_ipaddr/" /root/network/ipv4_static_ip.txt | awk -F "IPV6_GATEWAY=" '{print $2}' | awk '{print $1}')
            arp_mac=$(echo "$arp_n_all" | grep "$_wk" | grep "$_gateway" | grep -Eo "([0-9a-f]{2}\:){5}[0-9a-f]{2}|incomplete")
            if [[ -z "$v6_ipmask" ]] || [[ -z "$v6_gateway" ]]; then
                v6_status="\e[33mv6-未配\e[0m"
            else
                for ((i = 1; i <= 3; i++)); do # v6 测试
                    v6_GWIP=$(curl -m 10 --interface "$_wk" -6L ip.sb 2>/dev/null)
                    [[ -n "$v6_GWIP" ]] && break
                    [[ $i -lt 3 ]] && sleep 3
                done
                if [[ -n "$v6_GWIP" ]]; then
                    v6_status="v6-通网"
                else
                    v6_status="\e[31mv6-不通\e[0m"
                fi
            fi
            # 网卡测速
            Speed1=$(cat /sys/class/net/$_wk/statistics/tx_bytes 2>/dev/null)
            sleep 2
            Speed2=$(cat /sys/class/net/$_wk/statistics/tx_bytes 2>/dev/null)
            SPeed=$((($Speed2 - $Speed1) / 275144)) 2>/dev/null
            SPeed=$(printf "%04d" $SPeed)
            # 根据条件输出测试结果
            if [[ "$arp_mac" = "incomplete" ]] || [ -z "$arp_mac" ]; then
                echo -e "\e[31m$sort_ps\t$IPMI_ip\t$_MAC\t$_vlan\t$_ipv4_ip  \t$_gateway\t$v6_ipmask\t$v6_gateway    \t$v6_status\e[31m\t拨号-不通网关;未获取到arp_mac\e[0m"
            elif [ "$CS_Curl" -eq 1 ] || [ -z "$_GWIP" ]; then
                echo -e "\e[31m$sort_ps\t$IPMI_ip\t$_MAC\t$_vlan\t$_ipv4_ip  \t$_gateway\t$v6_ipmask\t$v6_gateway    \t$v6_status\e[31m\t拨号-不通网络\t${SPeed}.Mbps\e[0m"
            elif [[ "$_GWIP" != "$_ipv4_v4" ]]; then
                echo -e "\e[31m$sort_ps\t$IPMI_ip\t$_MAC\t$_vlan\t$_ipv4_ip  \t$_gateway\t$v6_ipmask\t$v6_gateway    \t$v6_status\e[31m\t拨号-公网ip不相等\t\"$_GWIP\"\e[0m"
            elif [ "$CS_Curl" -eq 0 ] || [ -n "$_GWIP" ]; then
                echo -e "\e[32m$sort_ps\t$IPMI_ip\t$_MAC\t$_vlan\t$_ipv4_ip  \t$_gateway\t$v6_ipmask\t$v6_gateway    \t$v6_status\e[32m\t拨号-通网\t${SPeed}.Mbps\e[0m"
            fi
        }
        for _wk in $WangKa; do
            TX_wk_curl "$_wk" &
        done
        wait
    elif [[ -n $(docker ps -a | grep host-pppoe-converge-t250506) ]]; then
        # 腾讯汇聚多IP拨号
        _file="/data/device-conf/network/pppoe/conf/account.txt"
        _docker_list=$(grep -Po '(MAC=).+?(PASSWORD).+?(\s)' "$_file" | sed -r 's/MAC|\:|\=|VLAN|PASSWORD|USERNAME//g')
        _ip_r=$(ip r)
        _ip_br=$(ip -br a)
        IFS=$'\n'
        for item in ${_docker_list}; do
            _head=$(echo "$item" | awk '{print $1}')
            _ip_mask=$(echo "$_ip_br" | grep "^ppp$_head" | awk '{print $3}')
            if [ "$(echo "$_ip_r" | grep "$_head" -c)" -eq 0 ]; then
                echo -e "\033[35m$item [ERROR] dial failed\033[0m"
            else
                echo -e "\033[36m$item \t $_ip_mask \t [SUCCESS] dial success\033[0m"
            fi
        done
    elif ip r | grep -qEoi "eds\-[0-9]"; then
        # ksyun 多IP拨号
        arp_n_all=$(arp -n)
        _ipr=$(ip r | grep "eds-")
        _ip_s=$(echo -e "$_ipr" | grep -Eo "src ([0-9]{1,3}\.){3}[0-9]{1,3}" | awk '{print $NF}')
        TX_wk_curl() {
            local _ipv4_ip=$1
            local _wk _ipaddr _ipv4_ip _gateway _vlan _MAC wk_info EM_vlan
            _wk=$(echo -e "$_ipr" | grep "$_ipv4_ip" | grep -Eo "eds-[0-9]{1,}")
            for ((i = 1; i <= 3; i++)); do
                _GWIP=$(curl -m 10 -sL --interface "$_ipv4_ip" ip.sb 2>/dev/null | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}")
                [[ -n "$_GWIP" ]] && break
                [[ $i -lt 3 ]] && sleep 3
            done
            _ipaddr=$(echo "$_ipr" | grep "$_wk" | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}" | awk -F/ '{print $NF}')
            _gateway=$(echo "$_ipr" | grep "$_wk" | grep default | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}")
            wk_info=$(ip addr show dev "$_wk")
            _MAC=$(echo "$wk_info" | grep "link/ether" | grep -Eo "([0-9a-f]{2}\:){5}[0-9a-f]{2}" | grep -v "ff:ff:ff:ff:ff:ff")
            EM_vlan=$(echo "$wk_info" | grep -Eo "eds-[0-9]{1,}@[0-9a-z.]*" | awk -F@ '{print $NF}')
            _vlan=$(grep "$EM_vlan" /proc/net/vlan/config | awk '{print $3}')
            arp_mac=$(echo "$arp_n_all" | grep "$_wk" | grep "$_gateway" | grep -Eo "([0-9a-f]{2}\:){5}[0-9a-f]{2}|incomplete")
            Speed1=$(cat /sys/class/net/$_wk/statistics/tx_bytes 2>/dev/null)
            sleep 2
            Speed2=$(cat /sys/class/net/$_wk/statistics/tx_bytes 2>/dev/null)
            SPeed=$((($Speed2 - $Speed1) / 275144)) 2>/dev/null
            SPeed=$(printf "%04d" $SPeed)
            if [[ "$arp_mac" = "incomplete" ]] || [ -z "$arp_mac" ]; then
                echo -e "\e[31m$sort_ps\t$IPMI_ip\t$_MAC\t$_vlan\t$_ipv4_ip  \t$_gateway     \t拨号-不通网关;未获取到arp_mac\e[0m"
            elif [ "$_GWIP" != "$_ipv4_ip" ] || [ -z "$_GWIP" ]; then
                echo -e "\e[31m$sort_ps\t$IPMI_ip\t$_MAC\t$_vlan\t$_ipv4_ip  \t$_gateway     \t拨号-不通网络\t${SPeed}.Mbps\e[0m"
            elif [ "$_GWIP" = "$_ipv4_ip" ] || [ -n "$_GWIP" ]; then
                echo -e "\e[32m$sort_ps\t$IPMI_ip\t$_MAC\t$_vlan\t$_ipv4_ip  \t$_gateway     \t拨号-通网\t${SPeed}.Mbps\e[0m"
            fi
        }
        for _ip in $_ip_s; do
            TX_wk_curl "$_ip" &
        done
        wait
    elif [[ -n $(docker ps -a | grep netns-pppoe-isolated-t240110) ]]; then
        # netns-pppoe-isolated-t240110
        BohaoMS="netns-pppoe-isolated-t240110"
        BohaoMS=$(printf "%24s" $BohaoMS)
        ZHZHzh=$(jq -r '.data[] | "\(.attrs.mac) \(.attrs.max_rx).Mbps \(.attrs.vlan) \(.attrs.username) \(.attrs.password)  \(.attrs.bridge)"' /data/kuaicdn/dcim/attachment/ip_link_pppoe/local.json | awk '{printf "%18s\t%9s\t%10s\t%4s\t%18s\t%8s\n",$1,$2,$6,$3,$4,$5}')
        Mac=$(jq -r '.data[].attrs.mac' /data/kuaicdn/dcim/attachment/ip_link_pppoe/local.json | tr -d ':')
        BOA() {
            local BOA_rq=$1
            local MARQ_mac=$2
            local IP time MAZH ZHZH speed_node SPeed NWIP RIZI SBYY ERRORS KEY
            IP=$(docker exec $BOA_rq tail -n15 /apps/data/logs/pppoe.log | grep 'local  IP' | tail -1 | awk '{printf "%-18s",$4}' | tail -n1)
            [[ -z $IP ]] && IP=$(docker exec $1 ip r | grep '[0-9]\.[0-9]' | awk -F 'src ' '{printf "%-18s",$2}')
            time=$(docker exec $BOA_rq grep "\"time\"" /apps/data/script/ip_monitor_address.jsons 2>/dev/null | tail -1 | jq '.time[0]' | xargs -n6)
            [[ -z $time ]] && time="0000-00-00 00-00-00"
            MAZH=$(echo "$MARQ_mac" | sed -e 's/^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4:\5:\6/')
            ZHZH=$(echo "$ZHZHzh" | grep "$MAZH")
            speed_node="$(docker exec $BOA_rq bash -c "$cmd")"
            SPeed="$(echo "$speed_node" | awk '{print $2}' | awk '{ values[NR] = $0 } END { print int((values[1] - values[2]) / 249000) }' 2>/dev/null)"
            SPeed=$(printf "%04d" $SPeed)
            NWIP=$(echo "$IP" | grep '^10\.\|^192\.168\.\|^100\.\|^172\.')
            if [ -z "$IP" ]; then
                RIZI=$(docker exec $BOA_rq tail -20 /apps/data/logs/pppoe.log 2>/dev/null | grep -v "username\|ppp\|Connect\|terminated\|CHAP authentication failed$\|PADT\|PPPoE" | sort -u)
                unset SBYY
                declare -A ERRORS=(
                    ["PADO"]="PADO线路不通"
                    ["PADS"]="PADS报文超时(mac连接请求过多,触发封锁)"
                    ["Modem"]="调制解调器的难题"
                    ["CHAP authentication failed: Authentication fail"]="CHAP身份验证失败"
                    ["PAP authentication failed"]="PAP身份验证失败"
                    ["UserName_Err"]="用户名错误"
                    ["BlackList user"]="黑名单用户"
                    ["User Locked"]="用户锁定"
                )
                for KEY in "${!ERRORS[@]}"; do
                    if echo "$RIZI" | grep -q "$KEY"; then
                        SBYY="$SBYY ${ERRORS[$KEY]}"
                    fi
                done
                echo -e "\033[31m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-失败\t${SBYY:0:75}\033[0m"
            elif [ -z "$NWIP" ] && [[ $SPeed = "0000" ]]; then
                echo -e "\033[33m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-成功\t$SPeed\t$IP\t$time\033[0m"
            elif [ -z "$NWIP" ]; then
                echo -e "\033[32m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-成功\t$SPeed\t$IP\t$time\033[0m"
            elif [[ $SPeed = "0000" ]]; then
                echo -e "\033[35m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-内网\t$SPeed\t$IP\t$time\033[0m"
            else
                echo -e "\033[36m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-内网\t$SPeed\t$IP\t$time\033[0m"
            fi
        }
        for MARQ in ${Mac}; do
            BOA "netns-pppoe-$MARQ" "$MARQ" &
        done
        wait
    elif [[ -n $(docker ps -a | grep netns-isolated-dhcp) ]]; then
        # DHCP 拨号
        _list=$(docker ps -a | awk '/netns-isolated-dhcp/{print $NF}')
        DHCP_curl() {
            local item=$1
            local _state speed_node SPeed _IP
            _state=$(docker exec "$item" bash -c "ip r" | grep "scope link" | awk '{print $NF}')
            speed_node="$(docker exec $item bash -c "$cmd")"
            SPeed="$(echo "$speed_node" | awk '{print $2}' | awk '{ values[NR] = $0 } END { print int((values[1] - values[2]) / 249000) }' 2>/dev/null)"
            SPeed=$(printf "%04d" $SPeed)
            if [[ -n "$_state" ]]; then
                _IP=$(docker exec "$item" ip r | grep scope | awk '{print $NF}')
                echo -e "\033[32m$item\tdhcp\t拨号成功\t$SPeed\t$_IP\033[0m"
            else
                echo -e "\033[31m$item\tdhcp\t拨号失败\t$SPeed\033[0m"
            fi
        }
        for item in $_list; do
            DHCP_curl "$item" &
        done
        wait
    elif [[ -n $(docker ps -a | grep "host-pppoe-converge-t240316\|host-pppoe-converge-t2405210") ]]; then
        # PPPOE 异网POP 用的
        BohaoMS=$(docker ps -a | grep "host-pppoe-converge-t240" | awk '{print $NF}')
        _MAC=$(awk '{print $1}' /data/device-conf/network/pppoe/conf/account.txt | awk -F= '{print $2}')
        _ip_r=$(ip r | grep -v "br-admin-lan\|br-interior\|docker0\|default")
        COVBOPPP() {
            local COVBOPPP_mac=$1
            local ZHZH _MAc _IP RIZI SBYY Speed1 Speed2 SPeed NWIP ERRORS KEY
            ZHZH=$(grep "$COVBOPPP_mac" /data/device-conf/network/pppoe/conf/account.txt | awk -F= '{print $2,$3,$4,$5,$6,$7}' | awk '{printf "%18s\t%9s\t%10s\t%4s\t%18s\t%8s\n",$1,$11".Mbps",$9,$3,$5,$7}')
            _MAc=$(echo "$COVBOPPP_mac" | tr -d ':')
            _IP=$(echo "$_ip_r" | grep ppp$_MAc | awk '{print $9}')
            if [ -z "$_IP" ]; then
                RIZI=$(docker exec netns-pppoe-$_MAc tail -20 /apps/data/logs/pppoe.log 2>/dev/null | grep -v "username\|ppp\|Connect\|terminated\|CHAP authentication failed$\|PADT\|PPPoE" | sort -u)
                unset SBYY
                declare -A ERRORS=(
                    ["PADO"]="PADO线路不通"
                    ["PADS"]="PADS报文超时(mac连接请求过多,触发封锁)"
                    ["Modem"]="调制解调器的难题"
                    ["CHAP authentication failed: Authentication fail"]="CHAP身份验证失败"
                    ["PAP authentication failed"]="PAP身份验证失败"
                    ["UserName_Err"]="用户名错误"
                    ["BlackList user"]="黑名单用户"
                    ["User Locked"]="用户锁定"
                )
                for KEY in "${!ERRORS[@]}"; do
                    if echo "$RIZI" | grep -q "$KEY"; then
                        SBYY="$SBYY ${ERRORS[$KEY]}"
                    fi
                done
                echo -e "\033[31m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-失败\t${SBYY:0:75}\033[0m"
            else
                Speed1=$(cat /sys/class/net/ppp$_MAc/statistics/tx_bytes 2>/dev/null)
                sleep 2
                Speed2=$(cat /sys/class/net/ppp$_MAc/statistics/tx_bytes 2>/dev/null)
                SPeed=$((($Speed2 - $Speed1) / 262144))
                SPeed=$(printf "%04d" $SPeed)
                NWIP=$(echo "$_IP" | grep '^10\.\|^192\.168\.\|^100\.\|^172\.')
                if [ -z "$NWIP" ] && [[ $SPeed = "0000" ]]; then
                    echo -e "\033[33m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-成功\t$SPeed\t$_IP\033[0m"
                elif [ -z "$NWIP" ]; then
                    echo -e "\033[32m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-成功\t$SPeed\t$_IP\033[0m"
                elif [[ $SPeed = "0000" ]]; then
                    echo -e "\033[35m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-内网\t$SPeed\t$_IP\033[0m"
                else
                    echo -e "\033[36m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-内网\t$SPeed\t$_IP\033[0m"
                fi
            fi
        }
        for MACC in $_MAC; do
            COVBOPPP "$MACC" &
        done
        wait
    elif [[ -n $(docker ps -a | grep netns-pppoe-converge) ]]; then
        BohaoMS="netns-pppoe-converge"
        BohaoMS=$(printf "%24s" $BohaoMS)
        Mac=$(awk -F 'MAC=' '{print $2}' /data/device-conf/network/pppoe/conf/account.txt | grep -v "ENABLE=0" | awk '{print $1}' | tr -d ':')
        BOB() {
            local BOB_rq=$1
            local BOB_mac=$2
            local IP time MAZH ZHZH RIZI SBYY Speed1 Speed2 SPeed NWIP ERRORS KEY
            IP=$(docker exec $BOB_rq tail -n15 /apps/data/logs/pppoe.log | grep 'local  IP' | tail -1 | awk '{printf "%-18s",$4}' | tail -n1)
            #[[ -z $IP ]] && IP=$(docker exec $1 ip r | grep '[0-9]\.[0-9]' | awk -F 'src ' '{printf "%-18s",$2}')
            time=$(docker exec $BOB_rq grep "\"time\"" /apps/data/script/ip_monitor_address.jsons 2>/dev/null | tail -1 | jq '.time[0]' | xargs -n6)
            [[ -z $time ]] && time="0000-00-00 00-00-00"
            MAZH=$(echo "$BOB_mac" | sed -e 's/^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4:\5:\6/')
            ZHZH=$(grep "$MAZH" /data/device-conf/network/pppoe/conf/account.txt | awk -F= '{print $2,$3,$4,$5,$6,$7}' | awk '{printf "%5s\t%10s\t%18s\t%9s\t%4s\t%18s\t%8s\n","00000",$9,$1,$11".Mbps",$3,$5,$7}')
            if [ -z "$IP" ]; then
                RIZI=$(docker exec $BOB_rq tail -20 /apps/data/logs/pppoe.log 2>/dev/null | grep -v "username\|ppp\|Connect\|terminated\|CHAP authentication failed$\|PADT\|PPPoE" | sort -u)
                unset SBYY
                declare -A ERRORS=(
                    ["PADO"]="PADO线路不通"
                    ["PADS"]="PADS报文超时(mac连接请求过多,触发封锁)"
                    ["Modem"]="调制解调器的难题"
                    ["CHAP authentication failed: Authentication fail"]="CHAP身份验证失败"
                    ["PAP authentication failed"]="PAP身份验证失败"
                    ["UserName_Err"]="用户名错误"
                    ["BlackList user"]="黑名单用户"
                    ["User Locked"]="用户锁定"
                )
                for KEY in "${!ERRORS[@]}"; do
                    if echo "$RIZI" | grep -q "$KEY"; then
                        SBYY="$SBYY ${ERRORS[$KEY]}"
                    fi
                done
                echo -e "\033[31m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-失败\t${SBYY:0:75}\033[0m"
            else
                Speed1=$(docker exec $BOB_rq cat /sys/class/net/mac$BOB_mac/statistics/tx_bytes 2>/dev/null)
                sleep 2
                Speed2=$(docker exec $BOB_rq cat /sys/class/net/mac$BOB_mac/statistics/tx_bytes 2>/dev/null)
                SPeed=$((($Speed2 - $Speed1) / 262144))
                SPeed=$(printf "%04d" $SPeed)
                NWIP=$(echo "$IP" | grep '^10\.\|^192\.168\.\|^100\.\|^172\.')
                if [ -z "$NWIP" ] && [[ $SPeed = "0000" ]]; then
                    echo -e "\033[33m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-成功\t$SPeed\t$IP\t$time\033[0m"
                elif [ -z "$NWIP" ]; then
                    echo -e "\033[32m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-成功\t$SPeed\t$IP\t$time\033[0m"
                elif [[ $SPeed = "0000" ]]; then
                    echo -e "\033[35m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-内网\t$SPeed\t$IP\t$time\033[0m"
                else
                    echo -e "\033[36m$BohaoMS\t$IPMI_ip\t$ZHZH\t拨号-内网\t$SPeed\t$IP\t$time\033[0m"
                fi
            fi
        }
        for MARQ in ${Mac}; do
            BOB "netns-pppoe-$MARQ" "$MARQ" &
        done
        wait
    elif [[ -n $(docker ps -a | grep netns-static-isolated) ]]; then
        BohaoMS=$(docker ps -a | grep "netns-static-isolated" | awk '{print $NF}')
        BohaoMS=$(printf "%24s" $BohaoMS)
        ZXMAC=$(awk -F 'MAC=' '{print $2}' /data/kuaicdn/conf/network/static_ip.conf | awk '{print $1}')
        BOC() {
            local MAAC=$1
            local ZHZH MAC Speed1 Speed2 SPeed ZHZT
            ZHZH=$(grep "$MAAC" /data/kuaicdn/conf/network/static_ip.conf | awk -F= '{print $3,$4,$5,$6,$7}' | awk '{printf"%8s\t%10s%4s\t%-22s\t%-15s",$9".Mbps",$7,$1,$3,$5}')
            MAC=$(echo $MAAC | tr -d ':')
            Speed1=$(docker exec netns-static-$MAC cat /sys/class/net/mac$MAC/statistics/tx_bytes 2>/dev/null)
            sleep 2
            Speed2=$(docker exec netns-static-$MAC cat /sys/class/net/mac$MAC/statistics/tx_bytes 2>/dev/null)
            SPeed=$((($Speed2 - $Speed1) / 275144)) 2>/dev/null
            SPeed=$(printf "%04d" $SPeed)
            docker exec netns-static-$MAC ping -c2 qq.com >/dev/null 2>&1 && ZHZT=0 || ZHZT=1
            if [[ "$ZHZT" == "0" ]]; then
                ZHZT="拨号-成功IP通网"
                echo -e "\e[32m$BohaoMS\t$IPMI_ip\t$MAAC\t$ZHZH\t$ZHZT\t$SPeed\e[0m"
            else
                ZHZT="拨号-失败IP不通"
                echo -e "\e[31m$BohaoMS\t$IPMI_ip\t$MAAC\t$ZHZH\t$ZHZT\t$SPeed\e[0m"
            fi
        }
        for MAAC in ${ZXMAC}; do
            BOC "$MAAC" &
        done
        wait
    elif [[ -n $(docker ps -a | grep netns-static-converge) ]]; then
        ZXMAC=$(awk -F 'MAC=' '{print $2}' /data/kuaicdn/conf/network/static_ip.conf | awk '{print $1}')
        BOD() {
            local MAAC=$1
            local ZHZH MAC Speed1 Speed2 SPeed ZHZT DCID
            ZHZH=$(grep "$MAAC" /data/kuaicdn/conf/network/static_ip.conf | awk -F= '{print $3,$4,$5,$6,$7}' | awk '{printf"%8s\t%10s%4s\t%-22s\t%-15s",$9".Mbps",$7,$1,$3,$5}')
            MAC=$(echo $MAAC | tr -d ':')
            DCID=$(docker ps -a | grep netns-static-converge | awk '{print $NF}')
            BohaoMS=$(printf "%24s" $DCID 2>/dev/null)
            Speed1=$(docker exec $DCID cat /sys/class/net/mac$MAC/statistics/tx_bytes 2>/dev/null)
            sleep 2
            Speed2=$(docker exec $DCID cat /sys/class/net/mac$MAC/statistics/tx_bytes 2>/dev/null)
            SPeed=$((($Speed2 - $Speed1) / 275144)) 2>/dev/null
            SPeed=$(printf "%04d" $SPeed)
            docker exec $DCID ping -I mac$MAC -c2 qq.com >/dev/null 2>&1 && ZHZT=0 || ZHZT=1
            if [[ "$ZHZT" == "0" ]]; then
                ZHZT="拨号-成功IP通网"
                echo -e "\e[32m$BohaoMS\t$IPMI_ip\t$MAAC\t$ZHZH\t$ZHZT\t$SPeed\e[0m"
            else
                ZHZT="拨号-失败IP不通"
                echo -e "\e[31m$BohaoMS\t$IPMI_ip\t$MAAC\t$ZHZH\t$ZHZT\t$SPeed\e[0m"
            fi
        }
        for MAAC in ${ZXMAC}; do
            BOD "$MAAC" &
        done
        wait
    elif grep -qi "CentOS" /etc/os-release; then
        # CentOS 固定IP
        wk_centos=$(ip r | grep default | grep -Eo "dev [0-Z]*" | grep -v "99" | awk '{print $2}')
        [ -z "$wk_centos" ] && wk_centos=$(ip r | grep default | grep -Eo "dev [0-Z]*" | awk '{print $2}')
        ip_a_info=$(ip a | grep -EA3 "[0-9]{1,}: $wk_centos")
        eth0_mac=$(echo "$ip_a_info" | grep -Eo "([0-9a-f]{2}:){5}[0-9a-f]{2}" | grep -Ev "ff:ff:ff:ff:ff:ff|00:00:00:00:00:00")
        eth0_IP=$(echo "$ip_a_info" | grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}" | grep -Ev "0.0.0.0")
        eth0_uuid=$(nmcli -g connection.uuid connection show "$wk_centos")
        eth0_vlan=$(nmcli connection show "$eth0_uuid" | grep "vlan.id" | awk '{print $NF}')
        eth0_gateway=$(nmcli connection show "$eth0_uuid" | grep "IP4.GATEWAY" | awk '{print $NF}')
        get_flow() {
            _tx=0
            for item in ${_nic}; do
                _tx="$(($(cat /sys/class/net/${item}/statistics/tx_bytes 2>/dev/null) + ${_tx}))"
            done
        }
        _nic="$(grep -v -f <(ls -1 /sys/devices/virtual/net/ 2>/dev/null) <(ls -1 /sys/class/net/ 2>/dev/null))"
        get_flow
        _tx_1="${_tx}"
        sleep 2
        get_flow
        _results_tx=0
        _results_tx="$(((_tx - _tx_1) / 262144))"
        _results_tx=$(printf "%04d\n" "$_results_tx")
        echo -e "\033[32m$sort_ps\t$IPMI_ip\t$eth0_mac\t10000.Mbps\t$wk_centos\t$eth0_vlan\t$eth0_IP\t$eth0_gateway\t拨号-成功\t$_results_tx\033[0m"
    fi
}
ZZHH=$(HMBHZT | sort -nk6 | sort -nk5)
echo "---------------------------------------------------------------------------------------------------------------------------------"
echo -e "$ZZHH"
if [[ $SJSJ != 1 ]]; then
    BHZS=$(echo -e "$ZZHH" | grep -c 拨号)
    BHCG=$(echo -e "$ZZHH" | grep -c "拨号-成功")
    BHSB=$(echo -e "$ZZHH" | grep -c "拨号-失败")
    BHNW=$(echo -e "$ZZHH" | grep -c "拨号-内网")
    BH00=$(echo -e "$ZZHH" | grep -c '\<0000\>')
    echo "---------------------------------------------------------------------------------------------------------------------------------"
    echo -e "\e[34m拨号账号总数量:$BHZS\e[0m"
    echo -e "\e[32m成功数量:$BHCG\e[0m \e[31m失败数量:$BHSB\e[0m \e[36m内网数量:$BHNW\e[0m \e[33m速率为零:$BH00\e[0m"
fi
echo "================================================================================================================================="
