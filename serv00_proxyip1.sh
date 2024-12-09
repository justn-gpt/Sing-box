#!/bin/bash

# 定义颜色
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"

red() { echo -e "\e[1;91m$1${re}"; }
green() { echo -e "\e[1;32m$1${re}"; }
yellow() { echo -e "\e[1;33m$1${re}"; }
purple() { echo -e "\e[1;35m$1${re}"; }

# 初始化变量
UUID=${UUID:-$(uuidgen -r)}
vless_port=${vless_port:-7239}
vmess_port=${vmess_port:-3823}
hy2_port=${hy2_port:-31257}
reality_domain=${reality_domain:-"www.speedtest.net"}

USERNAME=$(whoami)
HOSTNAME=$(hostname)
WORKDIR="domains/${USERNAME}.serv00.net/logs"
mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR"
cd "$WORKDIR"

# 自动选择可用 IP
function select_ip() {
  echo "正在选择可用 IP..."
  rm -f ip.txt
  for ym in "cache${HOSTNAME#s}.serv00.com" "$HOSTNAME" "web${HOSTNAME#s}.serv00.com"; do
    response=$(curl -s "https://ss.botai.us.kg/api/getip?host=$ym")
    if [[ -z "$response" ]]; then
      dig @8.8.8.8 +time=2 +short "$ym" >> ip.txt
    else
      echo "$response" | while IFS='|' read -r ip status; do
        [[ $status == "Accessible" ]] && echo "$ip: 可用" || echo "$ip: 被墙"
      done >> ip.txt
    fi
  done
  IP=$(grep -m 1 "可用" ip.txt | cut -d ':' -f 1)
  IP=${IP:-$(head -n 1 ip.txt | cut -d ':' -f 1)}
  green "已选择 IP: $IP"
}

# 生成证书
function generate_certificates() {
  openssl ecparam -genkey -name prime256v1 -out private.key
  openssl req -new -x509 -days 3650 -key private.key -out cert.pem -subj "/CN=${reality_domain}"
  green "已生成证书：cert.pem 和 private.key"
}

# 下载并安装 Sing-box
function install_singbox() {
  ARCH=$(uname -m)
  FILE_URL="https://github.com/eooce/test/releases/download"
  if [[ "$ARCH" =~ arm ]]; then
    FILE_URL="${FILE_URL}/arm64/sb"
  else
    FILE_URL="${FILE_URL}/freebsd/sb"
  fi
  curl -Lo singbox "$FILE_URL"
  chmod +x singbox
  ./singbox generate reality-keypair > reality_keypair.txt
  public_key=$(awk '/PublicKey:/ {print $2}' reality_keypair.txt)
  private_key=$(awk '/PrivateKey:/ {print $2}' reality_keypair.txt)
  green "已下载并初始化 Sing-box"
}

# 创建配置文件
function create_config() {
  cat > config.json <<EOF
{
  "log": { "level": "info", "disabled": false },
  "inbounds": [
    {
      "tag": "vless-reality",
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $vless_port,
      "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": {
        "enabled": true,
        "server_name": "$reality_domain",
        "reality": {
          "enabled": true,
          "private_key": "$private_key",
          "short_id": [""]
        }
      }
    },
    {
      "tag": "vmess-ws",
      "type": "vmess",
      "listen": "0.0.0.0",
      "listen_port": $vmess_port,
      "users": [{ "uuid": "$UUID" }],
      "transport": {
        "type": "ws",
        "path": "/$UUID-vm"
      }
    },
    {
      "tag": "hysteria",
      "type": "hysteria2",
      "listen": "0.0.0.0",
      "listen_port": $hy2_port,
      "users": [{ "password": "$UUID" }],
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "insecure": true
      }
    }
  ],
  "outbounds": [
    { "tag": "direct", "type": "direct" },
    { "tag": "block", "type": "block" }
  ]
}
EOF
  green "已生成配置文件：config.json"
}

# 启动服务
function start_singbox() {
  nohup ./singbox run -c config.json > singbox.log 2>&1 &
  sleep 2
  if ! pgrep -f singbox >/dev/null; then
    red "Sing-box 启动失败，请检查日志：singbox.log"
    exit 1
  fi
  green "Sing-box 已成功启动"
}

# 输出节点信息
function generate_links() {
  vless_link="vless://${UUID}@${IP}:${vless_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${reality_domain}&type=tcp"
  vmess_link="vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"Vmess-ws\", \"add\": \"${IP}\", \"port\": \"${vmess_port}\", \"id\": \"${UUID}\", \"aid\": \"0\", \"net\": \"ws\", \"path\": \"/${UUID}-vm\", \"tls\": \"\" }" | base64)"
  hy2_link="hysteria2://${UUID}@${IP}:${hy2_port}?sni=www.bing.com&insecure=1"
  
  cat > list.txt <<EOF
节点分享链接：
1. VLESS Reality: $vless_link
2. Vmess WS: $vmess_link
3. Hysteria2: $hy2_link
EOF

  green "节点信息已生成：list.txt"
  cat list.txt
}

# 主逻辑
function main() {
  select_ip
  generate_certificates
  install_singbox
  create_config
  start_singbox
  generate_links
}

main
