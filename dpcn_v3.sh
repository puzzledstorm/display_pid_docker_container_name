ONEGPU() {
    local gpu_id=$1

    # 获取 PID 列表和显存使用列表（直接存入数组/变量，不写文件）
    mapfile -t pids < <(nvidia-smi -q -i "$gpu_id" | grep "Process ID" | awk '{print $4}')
    mapfile -t mems < <(nvidia-smi -q -i "$gpu_id" | grep "Used GPU Memory" | awk '{print $5$6}')
    mapfile -t mem_nums < <(nvidia-smi -q -i "$gpu_id" | grep "Used GPU Memory" | awk '{print $5}')

    local count=${#pids[@]}

    # 如果当前 GPU 没有运行任何进程，直接返回
    if [ "$count" -eq 0 ]; then
        return 0
    fi

    echo "+-------gpu $gpu_id-----------------------------------------------------------------+"

    local mem_sum=0

    # 循环拼装输出
    for (( i=0; i<count; i++ )); do
        local pid="${pids[i]}"
        local mem="${mems[i]}"
        local mem_num="${mem_nums[i]}"
        local container_name="N/A"

        # 尝试通过 PID 匹配 Docker 容器名
        if [ -f "/proc/$pid/cgroup" ]; then
            local container_id
            container_id=$(awk -v FS='/' '{print $NF}' "/proc/$pid/cgroup" | sed 's/\.scope$//' | sed 's/^docker-//' | cut -c 1-12 | head -n 1)
            
            if [ -n "$container_id" ]; then
                # 获取容器名（去掉开头的斜杠）
                local name
                name=$(docker inspect --format "{{.Name}}" "$container_id" 2>/dev/null | sed 's/^\///')
                [ -n "$name" ] && container_name="$name"
            fi
        fi

        # 格式化输出：GPU_ID PID 显存占用 容器名
        printf "%-4s %-8s %-12s %s\n" "$gpu_id" "$pid" "$mem" "$container_name"

        # 累加显存
        mem_sum=$((mem_sum + mem_num))
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
