#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'fc44fe6a-f083-4591-9c03-f8d61dc3907f'} 
export NEZHA_SERVER=${NEZHA_SERVER:-''}      
export NEZHA_PORT=${NEZHA_PORT:-'5555'}             
export NEZHA_KEY=${NEZHA_KEY:-''}                
export PORT=${PORT:-'5678'} 
USERNAME=$(whoami)
HOSTNAME=$(hostname)

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="domains/${USERNAME}.ct8.pl/logs" || WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR" && cd "$WORKDIR")

# Download Dependency Files
ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-arm64 web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://download.hysteria.network/app/latest/hysteria-freebsd-amd64 web" "https://eooce.2go.us.kg/npm npm")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ123456789
    local name=""
    for i in {1..3}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    if [ -e "$NEW_FILENAME" ]; then
        echo -e "\e[1;32m$NEW_FILENAME already exists, Skipping download\e[0m"
    else
        curl -L -sS -o "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloading $NEW_FILENAME\e[0m"
    fi
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait


# Generate cert
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout server.key -out server.crt -subj "/CN=bing.com" -days 36500

# Generate configuration file
cat << EOF > config.yaml
listen: :$PORT

tls:
  cert: server.crt
  key: server.key

auth:
  type: password
  password: "$UUID"

fastOpen: true

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true

transport:
  udp:
    hopInterval: 30s
EOF

run() {
  if [ -n "${FILE_MAP[npm]}" ] && [ -e "${FILE_MAP[npm]}" ]; then
    tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
    if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
      NEZHA_TLS="--tls"
    else
      NEZHA_TLS=""
    fi
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
      export TMPDIR=$(pwd)
      nohup ./"${FILE_MAP[npm]}" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
      sleep 1
      pgrep -f "${FILE_MAP[npm]}" > /dev/null && echo -e "\e[1;32m${FILE_MAP[npm]} is running\e[0m" || { echo -e "\e[1;35m${FILE_MAP[npm]} is not running, restarting...\e[0m"; pkill -f "${FILE_MAP[npm]}" && nohup ./"${FILE_MAP[npm]}" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m${FILE_MAP[npm]} restarted\e[0m"; }
    else
      echo -e "\e[1;35mNEZHA variable is empty, skipping running\e[0m"
    fi
  fi

  if [ -n "${FILE_MAP[web]}" ] && [ -e "${FILE_MAP[web]}" ]; then
    nohup ./"${FILE_MAP[web]}" server config.yaml >/dev/null 2>&1 &
    sleep 1
    pgrep -f "${FILE_MAP[web]}" > /dev/null && echo -e "\e[1;32m${FILE_MAP[web]} is running\e[0m" || { echo -e "\e[1;35m${FILE_MAP[web]} is not running, restarting...\e[0m"; pkill -f "${FILE_MAP[web]}" && nohup ./"${FILE_MAP[web]}" server config.yaml >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m${FILE_MAP[web]} restarted\e[0m"; }
  fi
}
run

get_ip() {
  ip=$(curl -s --max-time 2 ipv4.ip.sb)
  if [ -z "$ip" ]; then
      if [[ "$HOSTNAME" =~ s[0-9]\.serv00\.com ]]; then
          ip=${HOSTNAME/s/web}
      else
          ip="$HOSTNAME"
      fi
  fi
  echo $ip
}
HOST_IP=$(get_ip)

ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')

echo -e "\e[1;32mHysteria2安装成功\033[0m\n"
echo -e "\e[1;33mV2rayN 或 Nekobox、小火箭等直接导入,跳过证书验证需设置为true\033[0m\n"
echo -e "\e[1;32mhysteria2://$UUID@$HOST_IP:$PORT/?sni=www.bing.com&alpn=h3&insecure=1#$ISP\033[0m\n"
echo -e "\e[1;33mSurge\033[0m"
echo -e "\e[1;32m$ISP = hysteria2, $HOST_IP, $PORT, password = $PASSWORD, skip-cert-verify=true, sni=www.bing.com\033[0m\n"
echo -e "\e[1;33mClash\033[0m"
cat << EOF
- name: $ISP
  type: hysteria2
  server: $HOST_IP
  port: $PORT
  password: $UUID
  alpn:
    - h3
  sni: www.bing.com
  skip-cert-verify: true
  fast-open: true
EOF
rm -rf ${FILE_MAP[web]} ${FILE_MAP[npm]} config.yaml fake_useragent_0.2.0.json
echo -e "\n\e[1;32mRuning done!\033[0m\n"
exit 0