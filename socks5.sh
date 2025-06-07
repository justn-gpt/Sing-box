#!/bin/bash
ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk '{print $2}' | xargs -r kill -9 > /dev/null 2>&1
devil www del $(whoami).serv00.net
devil www del keep.$(whoami).serv00.net
rm -rf $HOME/domains/*
shopt -s extglob dotglob
rm -rf $HOME/!(domains|mail|repo|backups)
set -x  # 启用调试模式

# 检查是否提供了必要的环境变量或命令行参数
if [ -z "$SOCKS5_PORT" ]; then
  echo "请设置 SOCKS5_PORT 环境变量或通过命令行传递，例如：SOCKS5_PORT=1234"
  exit 1
fi

if [ -z "$SOCKS5_USER" ]; then
  echo "请设置 SOCKS5_USER 环境变量或通过命令行传递，例如：SOCKS5_USER=\"your_user\""
  exit 1
fi

if [ -z "$SOCKS5_PASS" ]; then
  echo "请设置 SOCKS5_PASS 环境变量或通过命令行传递，例如：SOCKS5_PASS=\"your_password\""
  exit 1
fi

# 获取当前用户路径
FILE_PATH="/home/$USER/.s5"
S5_EXECUTABLE="${FILE_PATH}/s5"

# 打印路径信息用于调试
echo "即将创建的目录: $FILE_PATH"

# 不使用sudo创建必要的目录
mkdir -p "$FILE_PATH"
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
  curl -L -sS -o "$S5_EXECUTABLE" "https://github.com/justn-gpt/socks5/releases/download/v1.1.0/5-linux-amd64"
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

echo "脚本执行完成。"
