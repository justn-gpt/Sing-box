#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'39e8b439-06be-4783-ad52-6357fc5e8743'}         
export NEZHA_SERVER=${NEZHA_SERVER:-'nz.f4i.cn'}             
export NEZHA_PORT=${NEZHA_PORT:-'5555'}            
export NEZHA_KEY=${NEZHA_KEY:-''}
export PASSWORD=${PASSWORD:-'admin'} 
export PORT=${PORT:-'6789'}  
USERNAME=$(whoami)
HOSTNAME=$(hostname)

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="domains/${USERNAME}.ct8.pl/logs" || WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR" && cd "$WORKDIR")

# Download Dependency Files
ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd.sha256sum web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd web" "https://eooce.2go.us.kg/npm npm")
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
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout $WORKDIR/server.key -out $WORKDIR/server.crt -subj "/CN=bing.com" -days 36500

# Generate configuration file
cat > config.json <<EOL
{
  "server": "[::]:$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "$WORKDIR/server.crt",
  "private_key": "$WORKDIR/server.key",
  "congestion_control": "bbr",
  "alpn": ["h3", "spdy/3.1"],
  "udp_relay_ipv6": true,
  "zero_rtt_handshake": false,
  "dual_stack": true,
  "auth_timeout": "3s",
  "task_negotiation_timeout": "3s",
  "max_idle_time": "10s",
  "max_external_packet_size": 1500,
  "gc_interval": "3s",
  "gc_lifetime": "15s",
  "log_level": "warn"
}
EOL

# running files
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
    nohup ./"${FILE_MAP[web]}" -c config.json >/dev/null 2>&1 &
    sleep 1
    pgrep -f "${FILE_MAP[web]}" > /dev/null && echo -e "\e[1;32m${FILE_MAP[web]} is running\e[0m" || { echo -e "\e[1;35m${FILE_MAP[web]} is not running, restarting...\e[0m"; pkill -f "${FILE_MAP[web]}" && nohup ./"${FILE_MAP[web]}" -c config.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m${FILE_MAP[web]} restarted\e[0m"; }
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
echo -e "\e[1;32m本机IP: $HOST_IP\033[0m"
ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
echo -e "\e[1;32mTuic安装成功\033[0m\n"
echo -e "\e[1;33mV2rayN 或 Nekobox，跳过证书验证需设置为true\033[0m\n"
echo -e "\e[1;32mtuic://$UUID:$PASSWORD@$HOST_IP:$PORT?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$ISP\e[0m\n"
echo -e "\e[1;33mClash\033[0m\n"
cat << EOF
- name: $ISP
  type: tuic
  server: $HOST_IP
  port: $PORT                                                          
  uuid: $UUID
  password: $PASSWORD
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: www.bing.com                                
  skip-cert-verify: true
EOF
rm -rf ${FILE_MAP[web]} ${FILE_MAP[npm]} config.json fake_useragent_0.2.0.json
echo -e "\n\e[1;32mRuning done!\033[0m\n"
exit 0