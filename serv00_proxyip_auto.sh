#!/bin/bash

# 设置默认值
UUID="ff553813-58eb-4d93-91b7-1d9c567952a9"
VLESS_PORT="33239"
HY2_PORT="33236"
TUIC_PORT="36233"
REYM="yg.justn.us.kg"

USERNAME=$(whoami)
HOSTNAME=$(hostname)
WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR")

install_singbox() {
    echo -e "开始自动安装 Sing-box，协议：vless-reality, hysteria2, tuic\n"
    cd $WORKDIR

    download_and_run_singbox
    echo
    generate_links
}

download_and_run_singbox() {
    ARCH=$(uname -m)
    DOWNLOAD_DIR="."
    mkdir -p "$DOWNLOAD_DIR"

    if [[ "$ARCH" == "amd64" || "$ARCH" == "x86_64" ]]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web" "https://github.com/eooce/test/releases/download/freebsd/npm npm")
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi

    declare -A FILE_MAP
    for entry in "${FILE_INFO[@]}"; do
        URL=$(echo "$entry" | cut -d ' ' -f 1)
        FILENAME="$DOWNLOAD_DIR/$(basename $URL)"
        wget -q -O "$FILENAME" "$URL"
        chmod +x "$FILENAME"
        FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$FILENAME"
    done

    # 生成 Reality Keypair
    output=$("${FILE_MAP[web]}" generate reality-keypair)
    private_key=$(echo "${output}" | awk '/PrivateKey:/ {print $2}')
    public_key=$(echo "${output}" | awk '/PublicKey:/ {print $2}')

    openssl ecparam -genkey -name prime256v1 -out "private.key"
    openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.serv00.net"

    # 创建配置文件
    cat > config.json << EOF
{
  "inbounds": [
    {
      "tag": "vless-reality",
      "type": "vless",
      "listen_port": $VLESS_PORT,
      "users": [{ "uuid": "$UUID" }],
      "tls": {
        "enabled": true,
        "reality": {
          "enabled": true,
          "server": "$REYM",
          "server_port": 443,
          "private_key": "$private_key"
        }
      }
    },
    {
      "tag": "hysteria-in",
      "type": "hysteria2",
      "listen_port": $HY2_PORT,
      "users": [{ "password": "$UUID" }]
    },
    {
      "tag": "tuic-in",
      "type": "tuic",
      "listen_port": $TUIC_PORT,
      "users": [{ "uuid": "$UUID", "password": "$UUID" }]
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ]
}
EOF

    nohup ./"${FILE_MAP[web]}" run -c config.json >/dev/null 2>&1 &
    sleep 2
}

generate_links() {
    IP=$(curl -s --max-time 1.5 ipv4.ip.sb || echo "0.0.0.0")
    PUBLIC_KEY=$(grep -oP '(?<=PublicKey: )[^\s]+' config.json)

    cat > list.txt << EOF
VLESS Reality 分享链接：
vless://$UUID@$IP:$VLESS_PORT?security=reality&encryption=none&flow=xtls-rprx-vision&sni=$REYM&fp=chrome&pbk=$PUBLIC_KEY&type=tcp#$REYM-vless

HY2 分享链接：
hysteria2://$UUID@$IP:$HY2_PORT?sni=$REYM&alpn=h3#$REYM-hysteria2

TUIC 分享链接：
tuic://$UUID:$UUID@$IP:$TUIC_PORT?sni=$REYM&udp_relay_mode=native#$REYM-tuic

Proxy IP 信息：
IP:$IP 端口:$VLESS_PORT
EOF

    cat list.txt
}

install_singbox
