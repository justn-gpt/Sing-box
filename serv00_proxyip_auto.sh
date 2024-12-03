#!/bin/bash

# 定义颜色
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }

USERNAME=$(whoami)
HOSTNAME=$(hostname)
WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")

# 从环境变量中获取参数，提供默认值
UUID="${UUID:-$(uuidgen)}"
vless_port="${vless_port:-33239}"
hy2_port="${hy2_port:-33236}"
tuic_port="${tuic_port:-36233}"
reality_domain="${reality_domain:-yg.justn.us.kg}"

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

    # 生成配置文件
    private_key="`uuidgen -r`"
    public_key="`uuidgen -r`"

    cat > config.json << EOF
{
  "inbounds": [
    {
      "tag": "vless-reality",
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $vless_port,
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$reality_domain",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$reality_domain",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": [""]
        }
      }
    },
    {
      "tag": "hysteria2",
      "type": "hysteria2",
      "listen": "0.0.0.0",
      "listen_port": $hy2_port,
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
      "listen_port": $tuic_port,
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

# 生成节点信息并处理 proxyip/非标端口反代ip
get_links() {
    IP=$(curl -s ipv4.ip.sb)
    ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "unknown")
    NAME="${ISP}-${HOSTNAME}"

    echo -e "${yellow}生成的节点和反代信息如下：${re}"
    cat > list.txt <<EOF
VLESS Reality:
vless://$UUID@$IP:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reality_domain&fp=chrome&pbk=$public_key&type=tcp&headerType=none#$NAME-reality

Proxyip 信息:
全局应用：设置变量名：proxyip 设置变量值：$IP:$vless_port
单节点应用：path 路径改为：/pyip=$IP:$vless_port

非标端口反代信息:
优选 IP 地址：$IP，端口：$vless_port（TLS 必须开启）

Hysteria2:
hysteria2://$UUID@$IP:$hy2_port?sni=www.bing.com&alpn=h3&insecure=1#$NAME-hy2

TUIC:
tuic://$UUID:$UUID@$IP:$tuic_port?sni=www.bing.com&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#$NAME-tuic
EOF

    cat list.txt
}

# 执行安装和生成节点信息
install_singbox
get_links
