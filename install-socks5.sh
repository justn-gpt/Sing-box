#!/bin/bash

# 预定义变量（根据提供的图片）
SOCKS5_PORT=9939
SOCKS5_USER="juju"
SOCKS5_PASS="972633"  # 确保密码中不包含 @ 或 :

# 固定路径
USER=$(whoami)
WORKDIR="/home/${USER,,}/.nezha-agent"
FILE_PATH="/home/${USER,,}/.s5"
S5_EXECUTABLE="${FILE_PATH}/s5"

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

  # 下载并覆盖 s5 文件
  if [ -f "$S5_EXECUTABLE" ]; then
    echo "s5 文件已存在，正在覆盖..."
  fi

  curl -L -sS -o "$S5_EXECUTABLE" "https://github.com/eooce/test/releases/download/freebsd/web"
  chmod 777 "$S5_EXECUTABLE"

  nohup "$S5_EXECUTABLE" -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
  sleep 2

  # 检查进程是否启动成功
  if pgrep -x "s5" > /dev/null; then
    echo -e "\e[1;32ms5 is running\e[0m"
  else
    echo -e "\e[1;35ms5 is not running, restarting...\e[0m"
    pkill -x "s5"
    nohup "$S5_EXECUTABLE" -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
    sleep 2
    echo -e "\e[1;32ms5 restarted\e[0m"
  fi

  CURL_OUTPUT=$(curl -s 4.ipw.cn --socks5 $SOCKS5_USER:$SOCKS5_PASS@localhost:$SOCKS5_PORT)
  if [[ $CURL_OUTPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "代理创建成功，返回的IP是: $CURL_OUTPUT"
  else
    echo "代理创建失败，请检查自己输入的内容。"
  fi
}

# 基于提供的输入选项自动执行整个过程
mkdir -p "$FILE_PATH"
install_socks5

echo "脚本执行完成。致谢：RealNeoMan、k0baya、eooce"
