#!/bin/bash

re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }
export LC_ALL=C
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
export UUID=${UUID:-$(echo -n "$USERNAME+$HOSTNAME" | md5sum | head -c 32 | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')}
export SUB_TOKEN=${SUB_TOKEN:-${UUID:0:8}}
export DOAMIN=${DOAMIN:-''}

if [[ -z "$DOMAIN" ]]; then
    if [[ "$HOSTNAME" =~ ct8 ]]; then
        CURRENT_DOMAIN="${USERNAME}.ct8.pl"
    elif [[ "$HOSTNAME" =~ useruno ]]; then
        CURRENT_DOMAIN="${USERNAME}.useruno.com"
    else
        CURRENT_DOMAIN="${USERNAME}.serv00.net"
    fi
else
    CURRENT_DOMAIN="$DOMAIN"
fi

WORKDIR="${HOME}/domains/${CURRENT_DOMAIN}/public_nodejs"
[[ -d "$WORKDIR" ]] && mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR"  >/dev/null 2>&1
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1
command -v curl &>/dev/null && COMMAND="curl -so" || command -v wget &>/dev/null && COMMAND="wget -qO" || { red "Error: neither curl nor wget found, please install one of them." >&2; exit 1; }

check_website() {
yellow "正在安装中,请稍后...\n"
CURRENT_SITE=$(devil www list | awk -v domain="$CURRENT_DOMAIN" '$1 == domain && $2 == "nodejs"')
if [ -n "$CURRENT_SITE" ]; then
    green "已存在 ${CURRENT_DOMAIN} 的node站点,无需修改"
else
    EXIST_SITE=$(devil www list | awk -v domain="$CURRENT_DOMAIN" '$1 == domain')
    
    if [ -n "$EXIST_SITE" ]; then
        devil www del "$CURRENT_DOMAIN" >/dev/null 2>&1
        devil www add "$CURRENT_DOMAIN" nodejs /usr/local/bin/node18 > /dev/null 2>&1
        green "已删除旧的站点并创建新的nodejs站点"
    else
        devil www add "$CURRENT_DOMAIN" nodejs /usr/local/bin/node18 > /dev/null 2>&1
        green "已创建nodejs站点 ${CURRENT_DOMAIN}"
    fi
fi
}

apply_configure() {
    APP_URL="https://00.ssss.nyc.mn/xhttp.js"
    $COMMAND "${WORKDIR}/app.js" "$APP_URL"
    cat > ${WORKDIR}/.env <<EOF
UUID=${UUID}
SUB_TOKEN=${SUB_TOKEN}
DOMAIN=${DOMAIN}
EOF
    ln -fs /usr/local/bin/node18 ~/bin/node > /dev/null 2>&1
    ln -fs /usr/local/bin/npm18 ~/bin/npm > /dev/null 2>&1
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global'
    echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile && source $HOME/.bash_profile
    rm -rf $HOME/.npmrc > /dev/null 2>&1
    cd ${WORKDIR} && npm install dotenv --silent > /dev/null 2>&1
    devil www restart ${CURRENT_DOMAIN} > /dev/null 2>&1
}


get_links(){
ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")
get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME="$ISP-$(get_name)"

URL="vless://${UUID}@${CURRENT_DOMAIN}:443?encryption=none&security=tls&sni=${CURRENT_DOMAIN}&fp=chrome&allowInsecure=1&type=xhttp&host=${CURRENT_DOMAIN}&path=%2Fxhttp&mode=packet-up#${NAME}-xhttp"
green "\n\n$URL\n\n"
green "节点订阅链接(仅适用于v2rayN或Sterisand): https://${CURRENT_DOMAIN}/${SUB_TOKEN}\n"

worker_scrpit="
export default {
    async fetch(request, env) {
        let url = new URL(request.url);
        if (url.pathname.startsWith('/')) {
            var arrStr = [
                '${CURRENT_DOMAIN}',
            ];
            url.protocol = 'https:';
            url.hostname = getRandomArray(arrStr);
            let new_request = new Request(url, request);
            return fetch(new_request);
        }
        return env.ASSETS.fetch(request);
    },
};
function getRandomArray(array) {
    const randomIndex = Math.floor(Math.random() * array.length);
    return array[randomIndex];
}"
if [[ -z "$DOMAIN" ]]; then
    purple "如果想要节点使用优选ip,请在cloudflared创建一个workers,复制以下代码部署并绑定域名,然后将节点里的host和sni改为绑定的域名即可换优选域名或优选ip"
    green "\ncloudflared workers代码如下: \n"
    echo "$worker_scrpit" | sed 's/^/    /' | sed 's/^ *$//'
else
    ip_address=$(devil vhost list | awk '$2 ~ /web/ {print $1}')
    purple "请将 ${yellow}${CURRENT_DOMAIN} ${purple}域名在cloudflared添加A记录指向 ${yellow}$ip_address ${purple}并开启小黄云,才可使用节点,可更换优选域名或优选ip${re}\n\n"
fi

yellow "\n\nServ00|ct8老王vless-xhttp一键安装脚本\n"
echo -e "${green}反馈论坛：${re}${yellow}https://bbs.vps8.me${re}\n"
echo -e "${green}TG反馈群组：${re}${yellow}https://t.me/vps888${re}\n"
purple "转载请著名出处，请勿滥用\n"
green "Running done!\n"

}

install_xhttp() {
    clear
    check_website
    apply_configure
    get_links
}
install_xhttp