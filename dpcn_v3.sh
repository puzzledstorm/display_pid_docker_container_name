ONEGPU() {
    local gpu_id=$1

    # 1. 一次性获取当前 GPU 的完整 XML/Text 信息（只调用一次 nvidia-smi，极速！）
    local gpu_info
    gpu_info=$(nvidia-smi -q -i "$gpu_id")

    # 2. 用 awk 一口气解析出所有 PID 和对应显存，格式为 "PID 显存(MiB)"
    mapfile -t proc_lines < <(echo "$gpu_info" | awk '
        /Process ID/ { pid=$4 }
        /Used GPU Memory/ && pid!="" { print pid, $5$6; pid="" }
    ')

    local count=${#proc_lines[@]}

    # 没有进程直接返回
    if [ "$count" -eq 0 ]; then
        return 0
    fi

    echo "+-------gpu $gpu_id-----------------------------------------------------------------+"

    local mem_sum=0

    for line in "${proc_lines[@]}"; do
        local pid mem mem_num process_owner="N/A"
        pid=$(echo "$line" | awk '{print $1}')
        mem=$(echo "$line" | awk '{print $2}')
        mem_num=$(echo "$mem" | sed 's/MiB//')

        if [ -f "/proc/$pid/cgroup" ]; then
            # 尝试匹配 Docker 容器 ID
            local container_id
            container_id=$(awk -v FS='/' '{print $NF}' "/proc/$pid/cgroup" | sed 's/\.scope$//' | sed 's/^docker-//' | cut -c 1-12 | head -n 1)

            if [ -n "$container_id" ]; then
                local container_name
                container_name=$(docker inspect --format "{{.Name}}" "$container_id" 2>/dev/null | sed 's/^\///')
                [ -n "$container_name" ] && process_owner="[docker]$container_name"
            fi

            # 如果不是 Docker，尝试提取 Systemd 服务名
            if [ "$process_owner" = "N/A" ]; then
                local service_name
                service_name=$(grep -o '[^/]*\.service' "/proc/$pid/cgroup" | head -n 1)
                [ -n "$service_name" ] && process_owner="[systemd]$service_name"
            fi
        fi

        # 格式化输出
        printf "%-4s %-8s %-12s %s\n" "$gpu_id" "$pid" "$mem" "$process_owner"

        # 累加显存
        [ -n "$mem_num" ] && mem_sum=$((mem_sum + mem_num))
    done

    echo "Used GPU Memory Sum=${mem_sum} MiB"
}

# --- 主程序执行 ---
nvidia-smi
gpu_count=$(nvidia-smi -L | wc -l)

for (( gup_i=0; gup_i<gpu_count; gup_i++ )); do
    ONEGPU "$gup_i"
done

# 输出总情况
echo "+-------all-------------------------------------------------------------------+"
nvidia-smi --query-gpu=timestamp,driver_version,name,index,memory.total,memory.used,memory.free,temperature.gpu,utilization.memory,pstate --format=csv
echo "+-----------------------------------------------------------------------------+"
