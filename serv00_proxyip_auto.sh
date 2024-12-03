#!/bin/bash

# 定义颜色
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }

USERNAME=$(whoami)
HOSTNAME=$(hostname)
WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")

# 从环境变量中读取变量（提供默认值以防缺失）
UUID="${UUID:-$(uuidgen)}"
VLESS_PORT="${VLESS_PORT:-443}"
HY2_PORT="${HY2_PORT:-2053}"
TUIC_PORT="${TUIC_PORT:-2096}"
REALITY_DOMAIN="${REALITY_DOMAIN:-example.com}"

# 下载并运行 sing-box
install_singbox() {
    echo -e "${yellow}开始安装并配置 sing-box (vless-reality, hysteria2, tuic)...${re}"
    cd $WORKDIR || exit 1

    # 下载文件
    ARCH=$(uname -m)
    DOWNLOAD_DIR="."
    mkdir -p "$DOWNLOAD_DIR"
    FILE_INFO=()

    if [[ "$ARCH" =~ ^(arm|arm64|aarch64)$ ]]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/sb web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
    elif [[ "$ARCH" =~ ^(amd64|x86_64|x86)$ ]]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web" "https://github.com/eooce/test/releases/download/freebsd/npm npm")
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    for entry in "${FILE_INFO[@]}"; do
        URL=$(echo "$entry" | cut -d ' ' -f 1)
        NEW_FILENAME="$DOWNLOAD_DIR/$(basename $URL)"
        curl -L -sS --max-time 2 -o "$NEW_FILENAME" "$URL" || wget -q -O "$NEW_FILENAME" "$URL"
        chmod +x "$NEW_FILENAME"
    done

    # 生成配置
    PRIVATE_KEY="`uuidgen -r`"
    PUBLIC_KEY="`uuidgen -r`"

    cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $VLESS_PORT,
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$REALITY_DOMAIN",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$REALITY_DOMAIN",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": [""]
        }
      }
    },
    {
      "tag": "hysteria2",
      "type": "hysteria2",
      "listen": "0.0.0.0",
      "listen_port": $HY2_PORT,
      "users": [
        {
          "password": "$UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    },
    {
      "tag": "tuic",
      "type": "tuic",
      "listen": "0.0.0.0",
      "listen_port": $TUIC_PORT,
      "users": [
        {
          "uuid": "$UUID",
          "password": "$UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    }
  ]
}
EOF

    # 启动 sing-box
    ./sb run -c config.json &
    sleep 2

    echo -e "${green}Sing-box 已启动！${re}"
}

# 输出节点信息
get_links() {
    IP=$(curl -s ipv4.ip.sb)
    ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "unknown")
    NAME="${ISP}-${HOSTNAME}"

    echo -e "${yellow}生成的节点信息如下：${re}"
    cat > list.txt <<EOF
VLESS Reality:
vless://$UUID@$IP:$VLESS_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$REALITY_DOMAIN&fp=chrome&pbk=PUBLIC_KEY&type=tcp&headerType=none#$NAME-reality

Hysteria2:
hysteria2://$UUID@$IP:$HY2_PORT?sni=www.bing.com&alpn=h3&insecure=1#$NAME-hy2

TUIC:
tuic://$UUID:$UUID@$IP:$TUIC_PORT?sni=www.bing.com&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#$NAME-tuic
EOF

    cat list.txt
}

# 主程序
install_singbox
get_links
