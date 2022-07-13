#-------display_pid_docker_container_name.sh----
#-------2021-12-29-----------------------
#-------2022-4-06---update---------------------
#-------2022-5-06---update one card mode---------------------------
#------功能说明: 根据pid显示对应docker容器的名字和显存------
#------依赖于nvidia-smi命令和cgroup
ONEGPU(){ 
    nvidia-smi -q -i $1 | grep "Process ID" |awk '{print $4}' > c1
    nvidia-smi -q -i $1| grep "Used GPU Memory" |awk '{print $5$6}' > c2
    nvidia-smi -q -i $1| grep "Process ID" |awk '{print $4}' |xargs -I {} cat /proc/{}/cgroup|grep pids |awk -v FS='/' '{print $NF}'| awk -v FS='-' '{print $NF}'| awk -v FS='.' '{print $1}'|xargs -i sh -c 'docker inspect --format "{{.Name}}" {}'|awk -v FS='/' '{print $2}' > c3
    count=$(wc -l < c1)
    if [ $count == 0 ]
    then
      return $?
    fi
    for i in `seq $count`
    do
      echo $1 >> c0
    done
    
    #nvidia-smi > c.txt
    paste c0 c1 c2 c3 >> c.txt

    nvidia-smi -q -i $1| grep "Used GPU Memory" |awk '{print $5}' > num_count
    cat num_count |awk '{sum+=$1} END {print sum}'|xargs -I {} echo 'Used GPU Memory Sum={} MiB' >> c.txt
    rm c0 c1 c2 c3 num_count
    echo "+-------gpu $1-----------------------------------------------------------------+"
    cat c.txt
    #seq -s- 145|tr -d '[:digit:]'
    rm c.txt
}
# 调用函数
nvidia-smi
gpu_count=$(nvidia-smi -L| wc -l)
gup_i=0
while(( $gup_i<gpu_count ))
do
    #echo $gup_i
    ONEGPU $gup_i
    let "gup_i++"
done  
# 输出总情况
echo "+-------all-------------------------------------------------------------------+"
#nvidia-smi -L
nvidia-smi --query-gpu=timestamp,driver_version,name,index,memory.total,memory.used,memory.free,temperature.gpu,utilization.memory,pstate --format=csv
echo "+-----------------------------------------------------------------------------+"
