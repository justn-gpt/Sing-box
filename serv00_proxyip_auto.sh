#!/bin/bash

# 定义颜色
re="\033[0m"
red="\033[1;91m"
green="\033[1;32m"
yellow="\033[1;33m"
purple="\033[1;35m"

function red_echo() { echo -e "${red}$1${re}"; }
function green_echo() { echo -e "${green}$1${re}"; }
function yellow_echo() { echo -e "${yellow}$1${re}"; }
function purple_echo() { echo -e "${purple}$1${re}"; }

# 检查变量是否设置
function check_var() {
  local var_name="$1"
  local default_value="$2"
  if [ -z "${!var_name}" ]; then
    export "$var_name"="$default_value"
    yellow_echo "$var_name 未设置，使用默认值: $default_value"
  else
    green_echo "$var_name 已设置: ${!var_name}"
  fi
}

# 初始化变量
check_var UUID "$(uuidgen -r)"
check_var vless_port 33239
check_var hy2_port 33236
check_var tuic_port 36233
check_var reality_domain "www.speedtest.net"

# 设置工作目录
WORKDIR="domains/$(whoami).serv00.net/logs"
mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR"
cd "$WORKDIR"

# 下载并运行核心组件
function download_and_run_singbox() {
  ARCH=$(uname -m)
  DOWNLOAD_DIR="."
  mkdir -p "$DOWNLOAD_DIR"
  declare -A FILE_MAP

  if [[ "$ARCH" =~ ^(arm|arm64|aarch64)$ ]]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/sb web")
  elif [[ "$ARCH" =~ ^(amd64|x86_64|x86)$ ]]; then
    FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web")
  else
    red_echo "不支持的架构: $ARCH"
    exit 1
  fi

  for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    FILENAME="$DOWNLOAD_DIR/$(basename "$URL")"
    curl -L -o "$FILENAME" "$URL" || wget -q -O "$FILENAME" "$URL"
    chmod +x "$FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$FILENAME"
  done

  # 生成密钥
  output=$("${FILE_MAP[web]}" generate reality-keypair)
  private_key=$(echo "$output" | awk '/PrivateKey:/ {print $2}')
  public_key=$(echo "$output" | awk '/PublicKey:/ {print $2}')

  # 配置文件生成
  cat > config.json <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "tag": "vless-in",
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $vless_port,
      "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": {
        "enabled": true,
        "server_name": "$reality_domain",
        "reality": {
          "enabled": true,
          "handshake": { "server": "$reality_domain", "server_port": 443 },
          "private_key": "$private_key",
          "short_id": [""]
        }
      }
    },
    {
      "tag": "hysteria-in",
      "type": "hysteria2",
      "listen": "0.0.0.0",
      "listen_port": $hy2_port,
      "users": [{ "password": "$UUID" }],
      "tls": { "enabled": true, "certificate_path": "cert.pem", "key_path": "private.key" }
    },
    {
      "tag": "tuic-in",
      "type": "tuic",
      "listen": "0.0.0.0",
      "listen_port": $tuic_port,
      "users": [{ "uuid": "$UUID", "password": "$UUID" }],
      "tls": { "enabled": true, "certificate_path": "cert.pem", "key_path": "private.key" }
    }
  ]
}
EOF

  # 运行服务
  nohup "${FILE_MAP[web]}" run -c config.json >/dev/null 2>&1 &
}

# 输出节点链接
function get_links() {
  IP=$(curl -s ipv4.ip.sb)
  cat <<EOF

节点链接：
VLESS-Reality: vless://$UUID@$IP:$vless_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reality_domain&type=tcp#VLESS-Reality
Hysteria2: hysteria2://$UUID@$IP:$hy2_port?sni=www.speedtest.net&alpn=h3&insecure=1#Hysteria2
TUIC: tuic://$UUID:$UUID@$IP:$tuic_port?sni=www.speedtest.net&alpn=h3&insecure=1#TUIC

EOF
}

# 主逻辑
function main() {
  green_echo "开始安装 Sing-box..."
  download_and_run_singbox
  green_echo "服务安装完成。"
  get_links
}

main