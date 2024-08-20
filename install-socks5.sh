#!/bin/bash

# 介绍信息
echo -e "\e[32m
  ____   ___   ____ _  ______ ____  
 / ___| / _ \ / ___| |/ / ___| ___|  
 \___ \| | | | |   | ' /\___ \___ \ 
  ___) | |_| | |___| . \ ___) |__) |           不要直连
 |____/ \___/ \____|_|\_\____/____/            没有售后   
 缝合怪：cmliu 原作者们：RealNeoMan、k0baya、eooce
\e[0m"

# 获取当前用户名
USER=$(whoami)
FILE_PATH="/home/${USER,,}/.s5"

# 预定义的socks5端口号、用户名和密码
SOCKS5_PORT="9939"  # 你预定义的端口号
SOCKS5_USER="juju"  # 你预定义的用户名
SOCKS5_PASS="972633"  # 你预定义的密码（确保不含@和:）

# 创建配置文件
socks5_config(){
  mkdir -p "$FILE_PATH"
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

# 安装并运行 Socks5
install_socks5(){
  socks5_config
  if [ ! -e "${FILE_PATH}/s5" ]; then
    curl -L -sS -o "${FILE_PATH}/s5" "https://raw.githubusercontent.com/justn-gpt/Sing-box/main/web"
    if [ $? -ne 0 ]; then
      echo -e "\e[1;31m下载s5文件失败！请检查网络连接。\e[0m"
      exit 1
    fi
  fi

  if [ -e "${FILE_PATH}/s5" ]; then
    chmod 755 "${FILE_PATH}/s5"
    nohup ${FILE_PATH}/s5 -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
    sleep 2
    if pgrep -x "s5" > /dev/null; then
      echo -e "\e[1;32ms5 is running\e[0m"
    else
      echo -e "\e[1;31ms5 is not running,尝试重启...\e[0m"
      pkill -x "s5"
      nohup "${FILE_PATH}/s5" -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
      sleep 2
      pgrep -x "s5" > /dev/null && echo -e "\e[1;32ms5 restarted successfully\e[0m" || { echo -e "\e[1;31ms5 failed to start\e[0m"; exit 1; }
    fi
    CURL_OUTPUT=$(curl -s 4.ipw.cn --socks5 $SOCKS5_USER:$SOCKS5_PASS@localhost:$SOCKS5_PORT)
    if [[ $CURL_OUTPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "代理创建成功，返回的IP是: $CURL_OUTPUT"
      echo "socks://${SOCKS5_USER}:${SOCKS5_PASS}@${CURL_OUTPUT}:${SOCKS5_PORT}"
    else
      echo "代理创建失败，请检查输入的内容或代理服务状态。"
    fi
  else
    echo -e "\e[1;31ms5文件不存在，请重新检查下载步骤。\e[0m"
    exit 1
  fi
}

# 只安装 Socks5
install_socks5

echo "Socks5 安装完成。"
