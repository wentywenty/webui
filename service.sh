#!/system/bin/sh
# WebUI 服务脚本

# 在后台运行时记录日志的路径
LOG_FILE="/data/local/tmp/webui_log.txt"

# 清空日志文件
echo "" > $LOG_FILE

# 启动 WebUI 服务
echo "Starting WebUI service at \$(date)" >> $LOG_FILE
/data/adb/ksu/bin/webui --path=/data/adb/modules/$moduleName/webroot >> $LOG_FILE 2>&1 &

exit 0
