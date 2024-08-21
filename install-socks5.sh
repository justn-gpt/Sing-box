#!/bin/bash

set -x  # 启用调试模式

# 预定义变量
SOCKS5_PORT=9939
SOCKS5_USER="juju"
SOCKS5_PASS="972633"  # 确保密码中不包含 @ 或 :

# 硬编码路径，不使用变量
FILE_PATH="/home/jus9b/.s5"  # 将 `your_username` 替换为实际用户名
S5_EXECUTABLE="${FILE_PATH}/s5"

# 打印路径信息用于调试
echo "即将创建的目录: $FILE_PATH"

# 使用sudo创建必要的目录
sudo mkdir -p "$FILE_PATH"
if [ $? -ne 0 ]; then
    echo "目录创建失败: $FILE_PATH"
    exit 1
else
    echo "目录创建成功: $FILE_PATH"
fi

socks5_config() {
  cat > ${FILE_PATH}/config.json << EOF
{
  "log": {
    "access": "/dev/null",
    "error": "/dev/null",
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": "$SOCKS5_PORT",
      "protocol": "socks",
      "tag": "socks",
      "settings": {
        "auth": "password",
        "udp": false,
        "ip": "0.0.0.0",
        "userLevel": 0,
        "accounts": [
          {
            "user": "$SOCKS5_USER",
            "pass": "$SOCKS5_PASS"
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ]
}
EOF
}

install_socks5() {
  socks5_config

  # 检查并覆盖下载 s5 文件
  if [ -f "$S5_EXECUTABLE" ]; then
    echo "s5 文件已存在，正在覆盖..."
  fi

  # 下载 s5 文件并确保下载成功
  curl -L -sS -o "$S5_EXECUTABLE" "https://github.com/eooce/test/releases/download/freebsd/web"
  if [ $? -ne 0 ]; then
    echo "s5 文件下载失败"
    exit 1
  fi

  # 设置权限并启动 s5
  chmod 777 "$S5_EXECUTABLE"
  echo "启动 s5 进程..."
  nohup "$S5_EXECUTABLE" -c ${FILE_PATH}/config.json >"${FILE_PATH}/s5.log" 2>&1 &

  sleep 2  # 等待进程启动

  # 检查进程是否启动成功
  if pgrep -x "s5" > /dev/null; then
    echo -e "\e[1;32ms5 进程正在运行\e[0m"
  else
    echo -e "\e[1;31ms5 进程启动失败，请检查日志文件 ${FILE_PATH}/s5.log\e[0m"
    cat "${FILE_PATH}/s5.log"
    exit 1
  fi

  # 验证代理是否成功
  CURL_OUTPUT=$(curl -s 4.ipw.cn --socks5 $SOCKS5_USER:$SOCKS5_PASS@localhost:$SOCKS5_PORT)
  if [[ $CURL_OUTPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "代理创建成功，返回的IP是: $CURL_OUTPUT"
  else
    echo "代理创建失败，请检查自己输入的内容。"
  fi
}

# 执行安装和配置
install_socks5

echo "脚本执行完成。致谢：RealNeoMan、k0baya、eooce"
