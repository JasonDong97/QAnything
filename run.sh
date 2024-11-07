check_log_errors() {
    local log_file=$1  # 将第一个参数赋值给变量log_file，表示日志文件的路径

    # 检查日志文件是否存在
    if [[ ! -f "$log_file" ]]; then
        echo "指定的日志文件不存在: $log_file"
        return 1
    fi

    # 使用grep命令检查"core dumped"或"Error"的存在
    # -C 5表示打印匹配行的前后各5行
    local pattern="core dumped|Error|error"
    if grep -E -C 5 "$pattern" "$log_file"; then
        echo "检测到错误信息，请查看上面的输出。"
        exit 1
    else
        echo "$log_file 中未检测到明确的错误信息。请手动排查 $log_file 以获取更多信息。"
    fi
}

start_time=$(date +%s)  # 记录开始时间

if [ -f "close.sh" ]; then
    ./close.sh
fi

export USER_IP=192.168.10.106

mkdir -p ./logs/debug_logs/

# 8001
python3 -u qanything_kernel/dependent_server/rerank_server/rerank_server.py > ./logs/debug_logs/rerank_server.log 2>&1 &
PID1=$!

# 8002
nohup python3 -u qanything_kernel/dependent_server/embedding_server/embedding_server.py > ./logs/debug_logs/embedding_server.log 2>&1 &
PID2=$!

# 8003
nohup python3 -u qanything_kernel/dependent_server/pdf_parser_server/pdf_parser_server.py > ./logs/debug_logs/pdf_parser_server.log 2>&1 &
PID3=$!

#8004
nohup python3 -u qanything_kernel/dependent_server/ocr_server/ocr_server.py > ./logs/debug_logs/ocr_server.log 2>&1 &
PID4=$!

# 8110
nohup python3 -u qanything_kernel/dependent_server/insert_files_serve/insert_files_server.py --port 8110 --workers 1 > ./logs/debug_logs/insert_files_server.log 2>&1 &
PID5=$!

#8777
nohup python3 -u qanything_kernel/qanything_server/sanic_api.py --host $USER_IP --port 8777 --workers 1 > ./logs/debug_logs/main_server.log 2>&1 &
PID6=$!

# 生成close.sh脚本，写入kill命令
echo "#!/bin/bash" > close.sh
echo "kill $PID1 $PID2 $PID3 $PID4 $PID5 $PID6" > close.sh

# 监听后端服务启动
backend_start_time=$(date +%s)

while ! grep -q "Starting worker" logs/debug_logs/main_server.log; do
    echo "Waiting for the backend service to start..."
    echo "等待启动后端服务"
    sleep 1

    # 获取当前时间并计算经过的时间
    current_time=$(date +%s)
    elapsed_time=$((current_time - backend_start_time))

    # 检查是否超时
    if [ $elapsed_time -ge 180 ]; then
        echo "启动后端服务超时，自动检查日志文件 logs/debug_logs/main_server.log："
        check_log_errors logs/debug_logs/main_server.log
        exit 1
    fi
    sleep 5
done

current_time=$(date +%s)
elapsed=$((current_time - start_time))  # 计算经过的时间（秒）
echo "Time elapsed: ${elapsed} seconds."
echo "已耗时: ${elapsed} 秒."
user_ip=$USER_IP
echo "请在[http://$user_ip:8777/qanything/]下访问前端服务来进行问答，如果前端报错，请在浏览器按F12以获取更多报错信息"

tail -f -n 100 logs/debug_logs/debug.log