ONEGPU(){
    nvidia-smi -q -i $1 | grep "Process ID" | awk '{print $4}' > c1
    nvidia-smi -q -i $1 | grep "Used GPU Memory" | awk '{print $5$6}' > c2
    nvidia-smi -q -i $1 | grep "Process ID" | awk '{print $4}' | while read pid; do
        container_id=$(cat /proc/"$pid"/cgroup | awk -v FS='/' '{print $NF}' | sed 's/\.scope$//' | sed 's/^docker-//' | cut -c 1-12)
        if [ -n "$container_id" ]; then
            container_name=$(docker inspect --format "{{.Name}}" "$container_id")
            # 移除容器名称开头的斜杠
            container_name=$(echo "$container_name" | sed 's/^\///')
            echo "$pid $container_name" >> c3_temp
        fi
    done
    cat c3_temp > c3
    rm c3_temp

    count=$(wc -l < c1)
    if [ $count -eq 0 ]; then
        rm c1 c2 c3
        return $?
    fi

    for i in $(seq $count); do
        echo "$1" >> c0
    done

    paste c0 c1 c2 c3 >> c.txt

    nvidia-smi -q -i $1 | grep "Used GPU Memory" | awk '{print $5}' > num_count
    cat num_count | awk '{sum+=$1} END {print sum}' | xargs -I {} echo 'Used GPU Memory Sum={} MiB' >> c.txt
    rm c0 c1 c2 c3 num_count
    echo "+-------gpu $1-----------------------------------------------------------------+"
    cat c.txt
    rm c.txt
}

# 调用函数
nvidia-smi
gpu_count=$(nvidia-smi -L | wc -l)
gup_i=0
while (( $gup_i < gpu_count )); do
    ONEGPU $gup_i
    let "gup_i++"
done
# 输出总情况
echo "+-------all-------------------------------------------------------------------+"
nvidia-smi --query-gpu=timestamp,driver_version,name,index,memory.total,memory.used,memory.free,temperature.gpu,utilization.memory,pstate --format=csv
echo "+-----------------------------------------------------------------------------+"
