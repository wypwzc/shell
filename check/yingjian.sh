#!/bin/bash
# 硬件SN
# shellcheck disable=SC2004,SC2076,SC2207,SC2013
Server_Info() {
    echo -e "\e[36mServer Info:\e[0m"
    # IPMI信息
    echo "$_IPMItool" | grep -E 'IP Address[[:space:]]*:' | awk '{printf "    IPMI   :  %s\n", $NF}'
    echo "$_IPMItool" | grep "Subnet Mask" | awk '{printf "  Netmask  :  %s\n", $4}'
    echo "$_IPMItool" | grep "Default Gateway IP" | awk '{printf "    Defgw  :  %s\n", $5}'

    # 服务器厂商
    server_type=$(/usr/sbin/dmidecode -s system-Manufacturer | grep -Eio "inspur|dell|huawei|h3c") #H3C第一个是New,ipmitool拿得太慢了
    [ -z "$server_type" ] && server_type=$(ipmitool fru 2>/dev/null | grep "Board Mfg[[:space:]]*:" | head -1 | awk '{print $NF}')
    echo "Server Type:  ${server_type}"
    # 服务器型号
    server_XH=$(/usr/sbin/dmidecode -s system-product-name)
    echo "ServerModel:  ${server_XH}"
    # 服务器SN
    /usr/sbin/dmidecode -s system-serial-number | awk '{printf "Server  SN :  %s\n", $1}'
    # 服务器高度?U
    if [[ "$server_type" =~ ^[iI][nN][sS][pP][uU][rR]$ ]]; then
        # 定义浪潮产品型号高度列表
        _list_inspur_1U=("NS5284K1" "NF5180M4" "SA5112M4")
        _list_inspur_2U=("NF5280M5" "M12")
        _list_inspur_i24=("i24" "NS5162M5")
        if [[ " ${_list_inspur_1U[*]} " =~ "${server_XH}" ]]; then
            _xUfwq="1U"
        elif [[ " ${_list_inspur_2U[*]} " =~ "${server_XH}" ]]; then
            _xUfwq="2U"
        elif [[ " ${_list_inspur_i24[*]} " =~ "${server_XH}" ]]; then
            _xUfwq="i24"
        else
            _xUfwq="unknown"
        fi
    else
        _xUfwq=$(/usr/sbin/dmidecode -t chassis | grep 'Height' | awk -F: '{print $2}' | tr -d ' ')
    fi
    echo "Server  ?U :  $_xUfwq"
    # 内存信息
    DIMM_num=$(free -g | grep Mem | awk '{print $2}')
    DIMM_info=$(/usr/sbin/dmidecode -t memory | grep -A9 -E "^[[:space:]]+[sS]ize: [0-9]+ (MB|GB)")
    DIMM_XN=$(echo "$DIMM_info" | grep -E "^[[:space:]]*[sS]ize: [0-9]+ (MB|GB)" | awk -F: '{print $2" "$3}' | sort | uniq -c | awk '{print $2$3" * "$1}' | tr '\n' ' ')
    DIMM_SN=$(echo "$DIMM_info" | grep -E "[sS]erial [nN]umber: [0-9a-zA-Z]+" | awk '{print $NF}' | paste -sd ',')
    DIMM_kc=$(echo "$DIMM_info" | grep -E "^[[:space:]]*Locator:" | grep -Eo "[a-zA-Z0-9_]+?-?(DIMM|dimm)\s?[a-zA-Z0-9]+|[ABCDabcd][0-9]+" | paste -sd ',')
    DIMM_type=$(echo "$DIMM_info" | grep -E "[mM]anufacturer: [a-zA-Z0-9]+" | awk '{print $NF}' | paste -sd ',')
    DIMM_speed=$(echo "$DIMM_info" | grep -E "[sS]peed: [0-9]+ [a-zA-Z]+/s" | awk '{print $2" "$3}' | paste -sd ',')
    echo "Memory Size:  ${DIMM_num}GB"
    echo "Memory Numb:  $DIMM_XN"
    echo "Memory  SN :  $DIMM_SN"
    echo "Memory AXX :  $DIMM_kc"
    echo "Memory Type:  $DIMM_type"
    echo "MemorySpeed:  $DIMM_speed"
    # CPU信息
    dmi_cpu_info=$(dmidecode -t processor)
    #_cpu_core=$(grep "cpu cores" /proc/cpuinfo | uniq | awk '{print $NF}')
    _cpu_core=$(echo "$dmi_cpu_info" | grep "Core Count" | uniq | awk '{print $NF}')
    _cpu_Thread=$(echo "$dmi_cpu_info" | grep "Thread Count" | uniq | awk '{print $NF}')
    _cpu_name=$(grep "model name" /proc/cpuinfo | uniq | awk '{print $7$8"-"$10}')
    _cpu_xc=$(grep -c '^processor' /proc/cpuinfo)
    echo "CPU Info   :  ${_cpu_core}-core ${_cpu_Thread}-thread ${_cpu_name} (${_cpu_xc} threads total)"
    # 超线程状态
    Thread=$(lscpu | grep "Thread(s) per core" | awk '{print $NF}')
    if [ "$Thread" = "2" ]; then
        echo "CPU Thread :  ON"
    else
        echo "CPU Thread :  OFF"
    fi
    # CPU卡槽信息
    cpu_info=$(echo "$dmi_cpu_info" | grep -E "Status|Socket Designation" | awk -F ': ' '{print $2}' | tr '\n' ' ' | grep -Eo "CPU[0-9] [a-zA-Z0-9]+")
    for cpuslot in $(echo "$cpu_info" | awk '{print $1}'); do
        cpu_info_xin=$(echo "$cpu_info" | grep -E "^$cpuslot" | awk -F ' ' '{print $2}')
        if [ "$cpu_info_xin" = "Populated" ]; then
            cpu_info_xin="OK identify"
        else
            cpu_info_xin="NO Unknown"
        fi
        echo "CPU Socket :  $cpuslot $cpu_info_xin"
    done
    # 系统盘信息
    echo "System_Disk:  ${XTDISK}"
    # 获取万兆网卡名称
    for item in $(grep -v -f <(ls -1 /sys/devices/virtual/net/) <(ls -1 /sys/class/net/) | grep -v 'veth'); do
        [[ "$(ethtool "${item}" | grep -c "10000Mb/s")" == "1" ]] && _nic_name="${item}"
    done
    # 通过lldp邻居协议获取交换机接口
    _Switch_Port=$(lldpcli show neighbors ports "$_nic_name" 2>/dev/null | grep "PortID" | awk '{print $NF}')
    [ -n "$_Switch_Port" ] && echo "Switch Port:  $_Switch_Port"
}

Raid_Disk_Info() {
    # 阵列磁盘信息
    echo -e "\e[36mRaid_Disk Info:\e[0m"
    model=$1
    mingli_model=$2
    # 获取阵列信息
    RaidXin=$(/opt/MegaRAID/perccli/perccli64 /c0/eall/sall show 2>/dev/null | grep -E "[0-9]{2}:[0-9]")
    # 过滤掉状态为UGood -的磁盘后无盘,防止查询不到信息
    RaidXin_zt=$(echo "$RaidXin" | grep -v "UGood -")
    ShuLi=0
    if [ -n "$RaidXin" ] && [ -n "$RaidXin_zt" ] && [ -z "$mingli_model" ]; then
        zl_info() {
            local diskc=$1
            local ShuLi=$2
            local model=$3
            local smartctl_info DiskSn Disktype DiskDx
            smartctl_info=$(smartctl -a -d "megaraid,$diskc" "/dev/$XTDISK")
            DiskSn=$(echo "$smartctl_info" | grep -E "[sS]erial [nN]umber:[[:space:]]*[0-9a-zA-Z]+" | awk '{print $NF}')
            Disktype=$(echo "$smartctl_info" | grep -E "(Vendor|Product):" | awk -F: '{print $2}' | awk '{print $NF}' | grep -vE "\s$" | paste -sd ' ')
            [ -z "$Disktype" ] && Disktype=$(echo "$smartctl_info" | grep "Device Model" | awk '{print $3" "$4$5}')
            if [ "$model" = "calculate" ]; then
                DiskDx=$(echo "$RaidXin" | awk -v kcdisks="$diskc" '{if($2==kcdisks) print $5}' | awk '
{
    size = substr($1, 1, length($1)-1) + 0;
    if (size == 0) { print "0";} 
    else if (size < 2) { print "2T";}
    else if (size < 4) { print "4T";}
    else if (size < 6) { print "6T";}
    else if (size < 6.5) { print "14T双盘";}
    else if (size < 8) { print "8T";}
    else if (size < 10) { print "10T";}
    else if (size < 12) { print "12T";}
    else if (size < 14) { print "14T";}
    else if (size < 16) { print "16T";}
    else if (size < 64) { print "64G";}
    else if (size < 128) { print "128G";}
    else if (size < 256) { print "256G";}
    else if (size < 300) { print "300G";}
    else if (size < 512) { print "512G";}
    else if (size < 1000) { print "1T";}
}')
            else
                # 显示磁盘实际大小
                DiskDx=$(echo "$RaidXin" | awk -v kcdisks="$diskc" '{if($2==kcdisks) print $5}')
            fi
            printf "Number: %02d   Slot: %4s   Size: %4s   SN: %s  Model: %s\n" "$ShuLi" "$diskc" "$DiskDx" "$DiskSn" "$Disktype"
        }
        # 通过阵列获取所有磁盘solt号
        DiskKch=$(echo "$RaidXin" | awk '{print $2}')
        disk_info() {
            echo "==== perccli64 ====    bash 2.sh 2 1或bash 2.sh 6 使用: smartctl 模式"
            # 通过solt号获取磁盘信息和匹配阵列信息
            for diskc in $DiskKch; do
                ShuLi=$((ShuLi + 1))
                zl_info "$diskc" "$ShuLi" "$model" &
            done
            wait
        }
        disk_info | sort -nk 2
    else
        # 无阵列信息获取
        lsblk_info() {
            local diskc=$1
            local ShuLi=$2
            local model=$3
            local smartctl_info DiskSn Disktype DiskDx
            smartctl_info=$(smartctl -a "/dev/$diskc")
            DiskSn=$(echo "$smartctl_info" | grep Serial | awk '{print $NF}')
            Disktype=$(echo "$smartctl_info" | grep "Device Model" | awk '{print $3" "$4$5}')
            [ -z "$Disktype" ] && Disktype=$(echo "$smartctl_info" | grep -E "(Vendor|Product):" | awk -F: '{print $2}' | awk '{print $NF}' | grep -vE "\s$" | paste -sd ' ')
            if [ "$model" = "calculate" ]; then
                DiskDx=$(lsblk -d -o NAME,SIZE | grep "^$diskc " | awk '{print $NF}' | tr -d 'GT' | awk '
{
    size = substr($1, 1, length($1)-1) + 0;
    if (size == 0) { print "0";} 
    else if (size < 2) { print "2T";}
    else if (size < 4) { print "4T";}
    else if (size < 6) { print "6T";}
    else if (size < 6.5) { print "14T双盘";}
    else if (size < 8) { print "8T";}
    else if (size < 10) { print "10T";}
    else if (size < 12) { print "12T";}
    else if (size < 14) { print "14T";}
    else if (size < 16) { print "16T";}
    else if (size < 64) { print "64G";}
    else if (size < 128) { print "128G";}
    else if (size < 256) { print "256G";}
    else if (size < 300) { print "300G";}
    else if (size < 512) { print "512G";}
    else if (size < 1000) { print "1T";}
}')
            else
                # 显示磁盘实际大小
                DiskDx=$(lsblk -d -o NAME,SIZE | grep "^$diskc " | awk '{print $NF}')
            fi
            printf "Number: %02d   Name: %4s   Size: %4s   SN: %s  Model: %s\n" "$ShuLi" "$diskc" "$DiskDx" "$DiskSn" "$Disktype"
        }
        # lsblk获取磁盘名称
        _DISKs=$(lsblk -d -o NAME | grep -v "NAME\|sr0\|nvme")
        disk_info() {
            echo "==== smartctl ===="
            # 通过磁盘名称获取磁盘信息
            for diskc in $_DISKs; do
                ShuLi=$((ShuLi + 1))
                lsblk_info "$diskc" "$ShuLi" "$model" &
            done
            wait
        }
        disk_info | sort -nk 2
    fi
}

Pcie_Nvme_Info() {
    # 检查是否有NVMe设备
    if ! lsblk -d -o NAME | grep -q nvme; then
        exit 0
    fi
    echo -e "\e[36mPcie_Nvme Info:\e[0m"
    # 获取NVMe设备信息
    nvmeinfo_nvme() {
        local nvme_name=$1
        local mod_x=$2
        local nvme_SN nvme_Model nvme_Health nvme_Size smartctl_info
        if [ "$mod_x" = "nvmecil" ]; then
            nvme_SN=$(nvme id-ctrl "/dev/$nvme_name" --output-format=json | jq -r '.sn // empty' 2>/dev/null || nvme id-ctrl "/dev/$nvme_name" | awk '/^sn/ {print $2}')
            nvme_Model=$(nvme id-ctrl "/dev/$nvme_name" --output-format=json | jq -r '.mn // empty' 2>/dev/null || nvme id-ctrl "/dev/$nvme_name" | awk '/^mn/ {print $2}')
            nvme_Health=$(nvme smart-log "/dev/$nvme_name" | grep -Eo "[pP]ercentage(_| )[uU]sed[[:space:]]*:[[:space:]]+[0-9]+" | awk '{print 100 - $NF}')
        elif [ "$mod_x" = "smartctl" ]; then
            smartctl_info=$(smartctl -a "/dev/$nvme_name")
            nvme_SN=$(echo "$smartctl_info" | grep -E "[sS]erial [nN]umber:[[:space:]]*[0-9a-zA-Z]+" | awk '{print $NF}')
            nvme_Model=$(echo "$smartctl_info" | grep -E "[mM]odel [nN]umber[[:space:]]*:[[:space:]]+" | awk -F: '{print $2}' | awk '{print $1" "$2$3$4}')
            nvme_Health=$(echo "$smartctl_info" | grep -Eo "[pP]ercentage(_| )[uU]sed[[:space:]]*:[[:space:]]+[0-9]+" | awk '{print 100 - $NF}')
        fi
        nvme_Size=$(lsblk -dn "/dev/$nvme_name" | awk '
{
    size = substr($4, 1, length($1)-1) + 0;
    if (size == 0) { print "0";} 
    else if (size < 2) { print "2T";}
    else if (size < 4) { print "4T";}
    else if (size < 6) { print "6T";}
    else if (size < 6.5) { print "14T双盘";}
    else if (size < 8) { print "8T";}
    else if (size < 10) { print "10T";}
    else if (size < 12) { print "12T";}
    else if (size < 14) { print "14T";}
    else if (size < 16) { print "16T";}
    else if (size < 64) { print "64G";}
    else if (size < 128) { print "128G";}
    else if (size < 256) { print "256G";}
    else if (size < 300) { print "300G";}
    else if (size < 512) { print "512G";}
    else if (size < 1000) { print "1T";}
}')
        printf "Name: %s  Size: %s  SN: %s  Model: %s  Health: %s\n" "$nvme_name" "$nvme_Size" "$nvme_SN" "$nvme_Model" "$nvme_Health"
    }
    # 获取nvme名称
    nvme_name_s=$(lsblk -d -o NAME | grep -E "nvme[0-9a-zA-Z]+")
    nvme_info() {
        if command -v nvme >/dev/null 2>&1; then
            # 使用 nvmecil命令
            for nvme_name in $nvme_name_s; do
                nvmeinfo_nvme "$nvme_name" nvmecil &
            done
        elif command -v smartctl >/dev/null 2>&1; then
            # 使用 smartctl命令
            for nvme_name in $nvme_name_s; do
                nvmeinfo_nvme "$nvme_name" smartctl &
            done
        else
            echo "nvmecil与smartctl命令缺失"
        fi
        wait
    }
    nvme_info | sort -nk 2
}

echo "============ Start Info ============"
# 获取IPMI信息
_IPMItool=$(ipmitool lan print 2>/dev/null)
# 获取系统盘盘符
XTDISK=$(lsblk -no PKNAME "$(df / | awk 'NR>1{print $1}')")
[ -z "$XTDISK" ] && XTDISK=$(lsblk 2>/dev/null | grep -A1 -B4 "\s/$" | grep -Eo '(s|v)d[a-z]{1,2}[1-9]{1}' | grep -Eo '(s|v)d[a-z]' | sort -u)
[ -z "$XTDISK" ] && echo "系统盘盘符获取失败" && exit 1
if [ -z "$1" ]; then
    Server_Info
    Raid_Disk_Info calculate "$2"
    Pcie_Nvme_Info
elif [ "$1" = 1 ]; then
    Server_Info
elif [ "$1" = 2 ]; then
    echo "$_IPMItool" | grep -E 'IP Address[[:space:]]*:' | awk '{printf "    IPMI   :  %s\n", $NF}'
    Raid_Disk_Info calculate "$2"
elif [ "$1" = 3 ]; then
    echo "$_IPMItool" | grep -E 'IP Address[[:space:]]*:' | awk '{printf "    IPMI   :  %s\n", $NF}'
    Pcie_Nvme_Info
elif [ "$1" = 5 ]; then
    echo "$_IPMItool" | grep -E 'IP Address[[:space:]]*:' | awk '{printf "    IPMI   :  %s\n", $NF}'
    Raid_Disk_Info actual "$2"
elif [ "$1" = 6 ]; then
    echo "$_IPMItool" | grep -E 'IP Address[[:space:]]*:' | awk '{printf "    IPMI   :  %s\n", $NF}'
    Raid_Disk_Info actual "1"
fi

