#!/usr/bin/env bash
# 查看磁盘状态
# shellcheck disable=SC2002,SC2009,SC2086,SC2261

# ============================================
# 依赖检查与自动下载
# ============================================

# 检查并安装 jq（静默）
check_jq() {
    if ! command -v jq &>/dev/null; then
        if grep -qi "Ubuntu\|Debian" /etc/os-release 2>/dev/null; then
            apt update &>/dev/null && apt install -y jq &>/dev/null
        elif grep -qi "Centos\|RedHat\|Rocky\|Alma" /etc/os-release 2>/dev/null; then
            yum install -y jq &>/dev/null
        elif grep -qi "openSUSE" /etc/os-release 2>/dev/null; then
            zypper install -y jq &>/dev/null
        else
            echo "错误: 未知系统，无法自动安装 jq，请手动安装"
            exit 1
        fi
        if ! command -v jq &>/dev/null; then
            echo "错误: jq 安装失败，请手动安装"
            exit 1
        fi
    fi
}

# 检查并安装 perccli（根据系统类型自动下载）
check_perccli() {
    PERCCLI_PATH="/opt/MegaRAID/perccli/perccli64"
    
    # 如果已经存在，直接返回
    if [ -f "$PERCCLI_PATH" ]; then
        return 0
    fi
    
    # 检查系统类型并下载对应的 perccli
    if grep -qi "Ubuntu\|Debian" /etc/os-release 2>/dev/null; then
        # Debian/Ubuntu 系统下载 .deb 包
        mkdir -p /opt/MegaRAID/perccli
        curl -sSfLk -o /tmp/perccli.deb https://gitee.com/wzc-wzc666/shell/raw/main/tools/perccli/perccli_007.1623.0000.0000_all.deb
        if [ -f /tmp/perccli.deb ]; then
            dpkg -i /tmp/perccli.deb &>/dev/null
            rm -f /tmp/perccli.deb
        else
            echo "错误: perccli.deb 下载失败"
            exit 1
        fi
    elif grep -qi "Centos\|RedHat\|Rocky\|Alma\|Fedora" /etc/os-release 2>/dev/null; then
        # CentOS/RHEL 系统下载 .rpm 包
        mkdir -p /opt/MegaRAID/perccli
        curl -sSfLk -o /tmp/perccli.rpm https://gitee.com/wzc-wzc666/shell/raw/main/tools/perccli/perccli-1.17.10-1.noarch.rpm
        if [ -f /tmp/perccli.rpm ]; then
            rpm -ivh /tmp/perccli.rpm &>/dev/null
            rm -f /tmp/perccli.rpm
        else
            echo "错误: perccli.rpm 下载失败"
            exit 1
        fi
    else
        echo "错误: 未知系统，无法自动安装 perccli，请手动安装"
        exit 1
    fi
    
    # 检查是否安装成功（可能安装到 /usr/sbin/perccli）
    if [ ! -f "$PERCCLI_PATH" ]; then
        # 尝试查找 perccli 的实际安装位置
        find_perccli=$(find /usr -name perccli -type f 2>/dev/null | head -1)
        if [ -n "$find_perccli" ]; then
            mkdir -p /opt/MegaRAID/perccli
            ln -sf "$find_perccli" "$PERCCLI_PATH"
        else
            echo "错误: perccli 安装失败"
            exit 1
        fi
    fi
    
    
}

# 执行依赖检查
check_jq 2>/dev/null
check_perccli

# ============================================
# 原有代码开始
# ============================================

blkid_info=$(blkid 2>/dev/null)
output_info() {
    disk_info1="$(echo "$disk_info" | awk '{printf "%-12s %-6s  %-4s   %-6s\n", $1, $2, $5, $4}')"
    disk_mount_path="$(echo "$disk_info" | awk '{print $6}')"
    info_disk=$(find "$disk_mount_path" -maxdepth 1  -printf '%f\n' 2>/dev/null | grep -v "instance.size" | grep -Eo "cache-[a-z0-9]+|instance|disktank" | sort | uniq | paste -sd ',')
    printf "%-14s[%02d]  %s %s $state%s  %s\033[0m\n" "$item" "$did" "$disk_info1" "$model_fs" "$disk_mount_path" "$info_disk"
}

show_system_disk() {
    for item in ${system_disk_list}; do
        state=
        echo 1 >/.test &>/dev/null || state="\033[4m"
        disk_info="$(df -h | grep "\s/$")"
        did="$(did_get $item)"
        output_info
    done
}

disk_state_get() {
    item="$1"
    state=
    model_fs=$(echo "$blkid_info" | grep "$item" | awk -F 'TYPE=' '{print $2}' | awk -F '"' '{print $2}')
    if ! df | grep ^$item &>/dev/null; then
        # 磁盘没挂载
        disk_info="unmounted"
        output_info
    elif (("$(df $item 2>/dev/null | awk 'NR>1 {print $4}')" < 50)); then
        # 磁盘空间满
        state="\033[5m"
        disk_info="$(df -h | grep "^$item\s" | sort -u)"
        output_info
    elif ! df $item 2>/dev/null | awk 'NR>1 {print "echo 1 >"$6"/.test"}' | bash &>/dev/null; then
        # 磁盘输入输出错误
        state="\033[4m"
        disk_info="$(df -h | grep "^$item\s" | sort -u)"
        output_info
    else
        # 正常磁盘
        disk_info="$(df -h | grep "$item" | sort -u)"
        output_info
    fi
}

show_nvme_data_disk() {
    nvme_disk_list=$(echo "$data_disk_list" | grep nvme)
    if [ "$nvme_disk_list" == "" ]; then return; fi
    did="99"
    for nvme in ${nvme_disk_list}; do
        if [[ "$(lsblk -p | grep -c ${nvme}p)" != "0" ]]; then
            echo "$nvme"
            nvme_list=$(lsblk -p | grep "${nvme}p[0-9]{1}" -Eo)
            for item in ${nvme_list}; do
                disk_state_get "$item"
            done
        else
            disk_state_get "$nvme"
        fi
    done
}

show_sas_data_disk() {
    disk_sas_list="$(echo "$data_disk_list" | grep "/dev/.d")"
    if [ "$disk_sas_list" != "" ]; then
        for item in ${disk_sas_list}; do
            did="$(did_get $item)"
            if [[ "$(lsblk -p | grep -Ec "${item}[0-9]{1}")" != "0" ]]; then
                echo "$item"
                sas_list=$(lsblk -p | grep "${item}[0-9]{1}" -Eo)
                for sas in ${sas_list}; do
                    disk_state_get $sas
                done
            else
                disk_state_get "$item"
            fi
        done
    fi
}

show_raid() {
    if [ -f "/opt/MegaRAID/perccli/perccli64" ]; then
        /opt/MegaRAID/perccli/perccli64 /c0/eall/sall show 2>/dev/null | grep -E "^[0-9]" | awk '{printf "%-2s   %-6s %-7s %-2s %-5s\n", $2,$3,$5,$6,$7}'
    else
        echo "perccli64 未安装，无法显示 RAID 信息"
    fi
}

did_get() {
    local disk="$1"
    local vd_s vd JBOD_info did dg
    vd_s="$(echo "$disk_vd_list" | grep "$disk" | awk '{print $1}' 2>/dev/null)"
    # lsscsi 是[0:0:0:1] 第二位为0表示直通
    vd=$(echo "$vd_s" | awk -F: '{print $2}')
    if echo "$vd_s" | grep -Eq "0:"; then
        # 判断是否为直通模式 JBOD
        JBOD_info=$(echo "$dg_did_list" | awk '$2=='$vd' {print $3}' 2>/dev/null)
        if [ "$JBOD_info" = "JBOD" ]; then
            did="$vd" # 直通模式;直接使用vd id作为did
        fi
    else
        dg="$(echo "$vd_dg_list" | awk -F "[/| ]+" '$2=='$vd' {print $1}' 2>/dev/null)"
        did="$(echo "$dg_did_list" | grep -v "JBOD" | awk '$4=='$dg' {print $2}' 2>/dev/null)"
    fi
    echo "${did:-99}"
}

variable_set() {
    disk_vd_list=$(lsscsi 2>/dev/null | grep -v "Virtual" | sed 's@\[@@' | sed 's@\]@@' | awk -F: '{print $2":"$3,$4}' | awk '{print $1,$NF}')
    vd_dg_list=$(/opt/MegaRAID/perccli/perccli64 /c0/vall show 2>/dev/null | grep "^[0-9]")
    dg_did_list=$(/opt/MegaRAID/perccli/perccli64 /c0/eall/sall show 2>/dev/null | grep "^[0-9]")
}

get_disk_data_list() {
    disk_os="$(blkid -s LABEL 2>/dev/null | grep -Ei "os|sys_root" | grep "/dev/(s|v)d." -Eo)"
    if [ "$(echo "$disk_os" | grep -c "/dev/")" != "1" ]; then
        disk_os="$(lsblk -p 2>/dev/null | grep "\s/$" -B10 | grep "\sdisk\s" | tail -1 | awk '{print $1}')"
        if [ "$(echo "$disk_os" | grep -c "/dev/")" != "1" ]; then
            echo "未识别到系统盘"
            exit
        fi
    fi
    not_disk_os_list="$(grep -v -f <(echo "$disk_os") <(lsblk -pdn 2>/dev/null | grep "\sdisk\s" | grep -Eo "/dev/[0-z]{3,7}") | sort -u)"
    disk_virtual_list="$(lsscsi 2>/dev/null | grep -i "virtual" | grep -o "/dev/sd.")"
    if [ "$(echo "$disk_virtual_list" | grep "/dev/")" != "" ]; then
        disk_data_list="$(grep -v -f <(echo "$disk_virtual_list") <(echo "$not_disk_os_list"))"
    else
        disk_data_list="$not_disk_os_list"
    fi
    echo "$disk_data_list" &>/dev/null
}

All_disk() {
    # 清除虚拟磁盘
    _disk=$(lsscsi | grep '\sVirtual' | awk -F '/' '{print $NF}' | sed -r 's/\s//g')
    IFS=$'\n'
    for item in ${_disk}; do
        echo 1 | sudo tee "/sys/block/$item/device/delete" &>/dev/null
    done

    # 创建JSON 变量
    json_disk='{"system":[],"data":[]}'

    # 系统盘列表
    disk_os_list=$(lsblk -pn 2>/dev/null | grep -A1 -B6 "\s/$" | grep -Eo '/dev/(s|v)d[a-z]{1,2}[1-9]{1}' | grep -Eo '/dev/(s|v)d[a-z]' | sort -u)
    if [[ "$disk_os_list" == "" ]]; then
        disk_os_list=$(lsblk -p | awk '$7=="/"' | grep '/dev/(s|v)d[a-z]{1,2}' -Eo | sort -u)
        if [ "$disk_os_list" != "" ]; then
            for item in ${disk_os_list}; do
                json_disk=$(echo "$json_disk" | jq --arg v "$item" '.system += [$v]')
            done
        else
            echo "$json_disk" | jq -c
            exit
        fi
    else
        for item in ${disk_os_list}; do
            json_disk=$(echo "$json_disk" | jq --arg v "$item" '.system += [$v]')
        done
    fi

    # 所有盘列表
    disk_all_list=$(lsblk -pnd 2>/dev/null | grep '/dev/(vd[a-z]{1,2}|sd[a-z]{1,2}|nvme[0-9]{1}n1)' -Eo | sort -u)

    # 虚拟磁盘列表
    disk_virtual_list=$(lsscsi 2>/dev/null | grep -i "\svirtual\s" | awk '{print $7}')

    # 数据盘列表
    disk_data_list=$(grep -v -f <(echo -e "$disk_os_list$") <(echo "$disk_all_list"))
    if [ "$disk_virtual_list" != "" ]; then
        disk_data_list=$(grep -v -f <(echo -e "$disk_virtual_list") <(echo "$disk_data_list"))
    fi
    if [[ "$disk_data_list" == "" ]]; then
        echo "$json_disk" | jq -c
    else
        for item in ${disk_data_list}; do
            json_disk=$(echo "$json_disk" | jq --arg v "$item" '.data += [$v]')
        done
        echo "$json_disk" | jq -c
    fi
}

main() {
    echo -e "\033[1;92m=== DISK state 磁盘状态查看 ===\033[0m"
    disk_list=$(All_disk)
    if echo "$disk_list" | jq '.system' &>/dev/null; then
        variable_set

        system_disk_list=$(echo "$disk_list" | jq '.system[]' | sed 's/"//g')
        data_disk_list=$(echo "$disk_list" | jq '.data[]' | sed 's/"//g')

        if [ -z "$1" ]; then
            echo -e "\n\033[1;92m system disk list: $(echo "$system_disk_list" | grep dev -c) \033[0m"
            show_system_disk

            echo -e "\n\033[1;92m nvme disk list: $(echo "$data_disk_list" | grep dev | grep -c nvme) \033[0m"
            show_nvme_data_disk

            echo -e "\n\033[1;92m sas sata disk list: $(echo "$data_disk_list" | grep dev | grep -vc nvme) \033[0m"
            show_sas_data_disk

            echo -e "\n\033[1;92m raid list: \033[0m"
            show_raid
        elif [ "$1" = 1 ]; then
            echo -e "\n\033[1;92m system disk list: $(echo "$system_disk_list" | grep dev -c) \033[0m"
            show_system_disk
            echo -e "\n\033[1;92m nvme disk list: $(echo "$data_disk_list" | grep dev | grep -c nvme) \033[0m"
            show_nvme_data_disk
        elif [ "$1" = 2 ]; then
            echo -e "\n\033[1;92m sas sata disk list: $(echo "$data_disk_list" | grep dev | grep -vc nvme) \033[0m"
            show_sas_data_disk
        elif [ "$1" = 3 ]; then
            echo -e "\n\033[1;92m raid list: \033[0m"
            show_raid
        fi

    fi
}
main "$1"
