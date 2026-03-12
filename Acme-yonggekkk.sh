#!/bin/bash 
export LANG=en_US.UTF-8
red='\033[0;31m'
bblue='\033[0;34m'
plain='\033[0m'
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "Пожалуйста, запустите скрипт от root" && exit
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "alpine"; then
release="alpine"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "Текущая система не поддерживается, используйте Ubuntu, Debian или Centos" && exit 
fi
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "Скрипт не поддерживает текущую систему $op, используйте Ubuntu, Debian или Centos." && exit
fi

v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
}

if [ ! -f acyg_update ]; then
green "Первый запуск скрипта Acme-yg, установка необходимых зависимостей…"
if [[ x"${release}" == x"alpine" ]]; then
apk add wget curl tar jq tzdata openssl expect git socat iproute2 virt-what
else
if [ -x "$(command -v apt-get)" ]; then
apt update -y
apt install socat -y
apt install cron -y
elif [ -x "$(command -v yum)" ]; then
yum update -y && yum install epel-release -y
yum install socat -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y
dnf install socat -y
fi
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if ! command -v "cronie" &> /dev/null; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie
fi
fi
if ! command -v "dig" &> /dev/null; then
if [ -x "$(command -v yum)" ]; then
yum install -y bind-utils
elif [ -x "$(command -v dnf)" ]; then
dnf install -y bind-utils
fi
fi
fi

packages=("curl" "openssl" "lsof" "socat" "dig" "tar" "wget")
inspackages=("curl" "openssl" "lsof" "socat" "dnsutils" "tar" "wget")
for i in "${!packages[@]}"; do
package="${packages[$i]}"
inspackage="${inspackages[$i]}"
if ! command -v "$package" &> /dev/null; then
if [ -x "$(command -v apt-get)" ]; then
apt-get install -y "$inspackage"
elif [ -x "$(command -v yum)" ]; then
yum install -y "$inspackage"
elif [ -x "$(command -v dnf)" ]; then
dnf install -y "$inspackage"
fi
fi
done
fi
touch acyg_update
fi

if [[ -z $(curl -s4m5 icanhazip.com -k) ]]; then
yellow "Обнаружено, что VPS работает только с IPV6, добавляется dns64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1\nnameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
sleep 2
fi

acme2(){
if [[ -n $(lsof -i :80|grep -v "PID") ]]; then
yellow "Обнаружено, что порт 80 занят, сейчас будет выполнено полное освобождение порта 80"
sleep 2
lsof -i :80|grep -v "PID"|awk '{print "kill -9",$2}'|sh >/dev/null 2>&1
green "Порт 80 полностью освобождён!"
sleep 2
fi
}
acme3(){
readp "Введите email для регистрации (нажмите Enter, чтобы пропустить и автоматически создать виртуальный gmail-адрес):" Aemail
if [ -z $Aemail ]; then
auto=`date +%s%N |md5sum | cut -c 1-6`
Aemail=$auto@gmail.com
fi
yellow "Текущий email для регистрации: $Aemail"
green "Начинается установка скрипта acme.sh для запроса сертификата"
bash ~/.acme.sh/acme.sh --uninstall >/dev/null 2>&1
rm -rf ~/.acme.sh acme.sh
uncronac
wget -N https://github.com/Neilpang/acme.sh/archive/master.tar.gz >/dev/null 2>&1
tar -zxvf master.tar.gz >/dev/null 2>&1
cd acme.sh-master >/dev/null 2>&1
./acme.sh --install >/dev/null 2>&1
cd
curl https://get.acme.sh | sh -s email=$Aemail
if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
green "Установка программы запроса сертификатов acme.sh прошла успешно"
bash ~/.acme.sh/acme.sh --upgrade --use-wget --auto-upgrade
else
red "Не удалось установить программу запроса сертификатов acme.sh" && exit
fi
}

checktls(){
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key ]] && [[ -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
cronac
green "Сертификат для домена успешно получен или уже существует! Сертификат домена (cert.crt) и ключ (private.key) сохранены в папке /root/ygkkkca" 
yellow "Путь к открытому ключу crt ниже, можно сразу копировать"
green "/root/ygkkkca/cert.crt"
yellow "Путь к файлу ключа key ниже, можно сразу копировать"
green "/root/ygkkkca/private.key"
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
if [[ -f '/etc/hysteria/config.json' ]]; then
blue "Обнаружен прокси-протокол Hysteria-1. Если у вас установлен скрипт Hysteria от Yongge, выполните запрос/замену сертификата в скрипте Hysteria — этот сертификат будет применён автоматически"
fi
if [[ -f '/etc/caddy/Caddyfile' ]]; then
blue "Обнаружен прокси-протокол Naiveproxy. Если у вас установлен скрипт Naiveproxy от Yongge, выполните запрос/замену сертификата в скрипте Naiveproxy — этот сертификат будет применён автоматически"
fi
if [[ -f '/etc/tuic/tuic.json' ]]; then
blue "Обнаружен прокси-протокол Tuic. Если у вас установлен скрипт Tuic от Yongge, выполните запрос/замену сертификата в скрипте Tuic — этот сертификат будет применён автоматически"
fi
if [[ -f '/usr/bin/x-ui' ]]; then
blue "Обнаружен x-ui (прокси-протокол xray). Если у вас установлен скрипт x-ui от Yongge, включите опцию tls — этот сертификат будет применён автоматически"
fi
if [[ -f '/etc/s-box/sb.json' ]]; then
blue "Обнаружено прокси-ядро Sing-box. Если у вас установлен скрипт Sing-box от Yongge, выполните запрос/замену сертификата в скрипте Sing-box — этот сертификат будет применён автоматически"
fi
else
bash ~/.acme.sh/acme.sh --uninstall >/dev/null 2>&1
rm -rf /root/ygkkkca
rm -rf ~/.acme.sh acme.sh
uncronac
red "К сожалению, не удалось получить сертификат для домена. Рекомендации:"
yellow "1. Если IP в DNS начинается с 104.2 или 172, убедитесь, что в CF отключено CDN-облако (жёлтое облако). IP в записи должен быть локальным IP вашего VPS"
echo
yellow "2. Измените имя поддомена и затем попробуйте снова выполнить переустановку скрипта (важно)"
green "Пример: был поддомен x.ygkkk.eu.org или x.ygkkk.cf — переименуйте x в Cloudflare"
echo
yellow "3. Для одного и того же локального IP есть ограничение по времени на многократную подачу заявок на сертификат. Подождите некоторое время и затем повторите установку скрипта" && exit
fi
}

installCA(){
bash ~/.acme.sh/acme.sh --install-cert -d ${ym} --key-file /root/ygkkkca/private.key --fullchain-file /root/ygkkkca/cert.crt --ecc
}

checkip(){
v4v6
if [[ -z $v4 ]]; then
vpsip=$v6
elif [[ -n $v4 && -n $v6 ]]; then
vpsip="$v6 或者 $v4"
else
vpsip=$v4
fi
domainIP=$(dig @8.8.8.8 +time=2 +short "$ym" 2>/dev/null | grep -m1 '^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$')
if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]]; then
domainIP=$(dig @2001:4860:4860::8888 +time=2 aaaa +short "$ym" 2>/dev/null | grep -m1 ':')
fi
if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]] ; then
red "Не удалось получить IP из DNS, проверьте, правильно ли введён домен" 
yellow "Попробовать вручную ввести IP для принудительного сопоставления?"
yellow "1: Да! Введите IP, на который указывает домен"
yellow "2: Нет! Выйти из скрипта"
readp "Выберите:" menu
if [ "$menu" = "1" ] ; then
green "Локальный IP VPS: $vpsip"
readp "Введите IP, на который указывает домен, он должен совпадать с локальным IP VPS ($vpsip):" domainIP
else
exit
fi
elif [[ -n $(echo $domainIP | grep ":") ]]; then
green "Текущий домен указывает на IPV6-адрес: $domainIP"
else
green "Текущий домен указывает на IPV4-адрес: $domainIP"
fi
if [[ ! $domainIP =~ $v4 ]] && [[ ! $domainIP =~ $v6 ]]; then
yellow "Текущий локальный IP VPS: $vpsip"
red "IP, на который указывает домен, не совпадает с локальным IP текущего VPS!!!"
green "Рекомендации:"
if [[ "$v6" == "2a09"* || "$v4" == "104.28"* ]]; then
yellow "WARP не был автоматически отключён, отключите его вручную. Либо используйте скрипт WARP от Yongge с поддержкой автоматического отключения и включения"
else
yellow "1. Убедитесь, что CDN-облако отключено (только DNS), то же самое касается и других DNS-провайдеров"
yellow "2. Проверьте, правильно ли указан IP в настройках DNS"
fi
exit 
else
green "IP совпадает, начинается запрос сертификата…………"
fi
}

checkacmeca(){
if [[ "${ym}" == *ip6.arpa* ]]; then
red "Сейчас не поддерживается запрос сертификата для домена ip6.arpa" && exit
fi
nowca=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
if [[ $nowca == $ym ]]; then
red "Проверка показала, что для введённого домена уже есть запись о запросе сертификата, повторный запрос не требуется"
red "Запись о запросе сертификата:"
bash ~/.acme.sh/acme.sh --list
yellow "Если вы всё же хотите запросить заново, сначала выполните удаление сертификата" && exit
fi
}

ACMEstandaloneDNS(){
v4v6
vpsip=${v4:-$v6}
readp "Введите домен, для которого уже настроен DNS (нажмите Enter, если домена нет — будет использован домен с суффиксом nip.io для автоматического разрешения IP):" ym
if [ -z "$ym" ]; then
case "$vpsip" in *:*) ym="${vpsip//:/-}.nip.io" ;; *) ym="${vpsip//./-}.nip.io" ;; esac
fi
green "Введённый домен:$ym" && sleep 1
checkacmeca
checkip
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
installCA
checktls
}

ACMEDNS(){
readp "Введите домен, для которого уже настроен DNS:" ym
green "Введённый домен:$ym" && sleep 1
checkacmeca
freenom=`echo $ym | awk -F '.' '{print $NF}'`
if [[ $freenom =~ tk|ga|gq|ml|cf ]]; then
red "Обнаружено, что вы используете бесплатный домен Freenom, текущий режим DNS API не поддерживается, скрипт завершает работу" && exit 
fi
if [[ -n $(echo $ym | grep \*) ]]; then
green "Обнаружено, что сейчас запрашивается wildcard-сертификат," && sleep 2
else
green "Обнаружено, что сейчас запрашивается сертификат для одного домена," && sleep 2
fi
checkacmeca
checkip
echo
ab="Выберите провайдера DNS-хостинга домена:\n1.Cloudflare\n2.Tencent Cloud DNSPod\n3.Aliyun\n Выберите："
readp "$ab" cd
case "$cd" in 
1 )
readp "Скопируйте Global API Key из Cloudflare：" GAK
export CF_Key="$GAK"
readp "Введите email адрес, на который зарегистрирован вход в Cloudflare：" CFemail
export CF_Email="$CFemail"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
;;
2 )
readp "Скопируйте DP_Id из Tencent Cloud DNSPod：" DPID
export DP_Id="$DPID"
readp "Скопируйте DP_Key из Tencent Cloud DNSPod：" DPKEY
export DP_Key="$DPKEY"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
;;
3 )
readp "Скопируйте Ali_Key из Aliyun：" ALKEY
export Ali_Key="$ALKEY"
readp "Скопируйте Ali_Secret из Aliyun：" ALSER
export Ali_Secret="$ALSER"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_ali -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
esac
installCA
checktls
}

ACMEDNScheck(){
wgcfv6=$(curl -s6m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ACMEDNS
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ACMEDNS
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

ACMEstandaloneDNScheck(){
wgcfv6=$(curl -s6m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ACMEstandaloneDNS
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ACMEstandaloneDNS
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

acme(){
mkdir -p /root/ygkkkca
ab="1. Выбрать режим запроса сертификата через отдельный 80 порт (нужен только домен, рекомендуется новичкам), во время установки порт 80 будет принудительно освобождён\n2. Выбрать режим запроса сертификата через DNS API (нужны домен, ID, Key), автоматически определяется одиночный или wildcard-домен\n Выберите："
readp "$ab" cd
case "$cd" in 
1 ) acme2 && acme3 && ACMEstandaloneDNScheck;;
2 ) acme3 && ACMEDNScheck;;
esac
}

Certificate(){
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "acme.sh не установлен, выполнение невозможно" && exit 
green "В столбце Main_Domainc отображаются домены, для которых сертификаты уже успешно получены, в столбце Renew отображается время автоматического продления для соответствующего сертификата"
bash ~/.acme.sh/acme.sh --list
#readp "Введите домен, сертификат которого нужно отозвать и удалить (скопируйте домен из столбца Main_Domain, для выхода нажмите Ctrl+c):" ym
#if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $ym) ]]; then
#bash ~/.acme.sh/acme.sh --revoke -d ${ym} --ecc
#bash ~/.acme.sh/acme.sh --remove -d ${ym} --ecc
#rm -rf /root/ygkkkca
#green "Сертификат для домена ${ym} успешно отозван и удалён"
#else
#red "Сертификат для введённого домена ${ym} не найден, проверьте данные самостоятельно!" && exit
#fi
}

acmeshow(){
if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
caacme1=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
if [[ -n $caacme1 && ! $caacme1 == "Main_Domain" ]] && [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
caacme=$caacme1
else
caacme='Нет записей о запросе сертификата'
fi
else
caacme='acme не установлен'
fi
}
cronac(){
uncronac
crontab -l > /tmp/crontab.tmp
echo "0 0 * * * root bash ~/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}
uncronac(){
crontab -l > /tmp/crontab.tmp
sed -i '/--cron/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}
acmerenew(){
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "acme.sh не установлен, выполнение невозможно" && exit 
green "Ниже показаны домены, для которых сертификаты уже успешно получены"
bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'
echo
#ab="1. Автоматически продлить все сертификаты в один клик (рекомендуется)\n2. Выбрать конкретный домен для продления сертификата\n0. Вернуться на уровень выше\n Выберите："
#readp "$ab" cd
#case "$cd" in 
#1 ) 
green "Начинается продление сертификата…………" && sleep 3
bash ~/.acme.sh/acme.sh --cron -f
checktls
#;;
#2 ) 
#readp "Введите домен, сертификат которого нужно продлить (скопируйте домен из столбца Main_Domain):" ym
#if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $ym) ]]; then
#bash ~/.acme.sh/acme.sh --renew -d ${ym} --force --ecc
#checktls
#else
#red "Сертификат для введённого домена ${ym} не найден, проверьте данные самостоятельно!" && exit
#fi
#;;
#0 ) start_menu;;
#esac
}
uninstall(){
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "acme.sh не установлен, выполнение невозможно" && exit 
curl https://get.acme.sh | sh
bash ~/.acme.sh/acme.sh --uninstall
rm -rf /root/ygkkkca
rm -rf ~/.acme.sh acme.sh
sed -i '/acme.sh.env/d' ~/.bashrc 
source ~/.bashrc
uncronac
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh успешно удалён" || red "Не удалось удалить acme.sh"
}

clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "Проект Yongge на Github  ：github.com/yonggekkk"
white "Блог Yongge на Blogger ：ygkkk.blogspot.com"
white "Канал Yongge на YouTube ：www.youtube.com/@ygkkk"
yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
green "Версия скрипта Acme-yg V26.3.11"
yellow "Подсказки:"
yellow "1. Скрипт не поддерживает VPS с несколькими IP, IP для входа по SSH должен совпадать с общесетевым IP VPS"
yellow "2. Режим 80 порта поддерживает только запрос сертификата для одного домена; автоматическое продление поддерживается, если порт 80 не занят"
yellow "3. Режим 80 порта поддерживает получение сертификата и без собственного домена — используется домен с суффиксом nip.io, который автоматически указывает на IP"
yellow "4. Режим DNS API не поддерживает бесплатные домены Freenom, поддерживаются сертификаты для одного домена и wildcard-сертификаты, автоматическое продление без условий"
yellow "5. Перед запросом wildcard-сертификата нужно создать у провайдера DNS запись с именем * (формат ввода: *.основной_домен_или_поддомен)"
yellow "Путь сохранения открытого ключа crt：/root/ygkkkca/cert.crt"
yellow "Путь сохранения файла ключа key：/root/ygkkkca/private.key"
echo
red "========================================================================="
acmeshow
blue "Текущий успешно полученный сертификат (в виде домена):"
yellow "$caacme"
echo
red "========================================================================="
green " 1. Запросить letsencrypt ECC сертификат через acme.sh (поддерживаются режим 80 порта и режим DNS API) "
green " 2. Просмотреть успешно полученные домены и время автоматического продления "
green " 3. Вручную продлить сертификат в один клик "
green " 4. Удалить сертификат и удалить скрипт быстрого запроса ACME-сертификатов "
green " 0. Выход "
echo
readp "Введите номер:" NumberInput
case "$NumberInput" in     
1 ) acme;;
2 ) Certificate;;
3 ) acmerenew;;
4 ) uninstall;;
* ) exit      
esac
