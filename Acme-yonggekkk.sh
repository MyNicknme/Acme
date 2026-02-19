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
[[ $EUID -ne 0 ]] && yellow "Пожалуйста, запустите скрипт от имени root" && exit
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
green "Первичная установка зависимостей Acme-yg..."
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
yellow "Обнаружен VPS только с IPv6, добавляем DNS64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1\nnameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
sleep 2
fi

acme2(){
if [[ -n $(lsof -i :80|grep -v "PID") ]]; then
yellow "Обнаружено, что порт 80 занят, выполняем полное освобождение порта 80"
sleep 2
lsof -i :80|grep -v "PID"|awk '{print "kill -9",$2}'|sh >/dev/null 2>&1
green "Порт 80 полностью освобожден!"
sleep 2
fi
}
acme3(){
readp "Введите Email для регистрации (Enter = автогенерация Gmail):" Aemail
if [ -z $Aemail ]; then
auto=`date +%s%N |md5sum | cut -c 1-6`
Aemail=$auto@gmail.com
fi
yellow "Текущий зарегистрированный Email: $Aemail"
green "Начинаем установку скрипта acme.sh"
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
green "Программа acme.sh успешно установлена"
bash ~/.acme.sh/acme.sh --upgrade --use-wget --auto-upgrade
else
red "Ошибка установки программы acme.sh" && exit
fi
}

checktls(){
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key ]] && [[ -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
cronac
green "Сертификат успешно получен или уже существует! Сертификат (cert.crt) и ключ (private.key) сохранены в папке /root/ygkkkca" 
yellow "Путь к файлу публичного ключа crt (можно копировать):"
green "/root/ygkkkca/cert.crt"
yellow "Путь к файлу приватного ключа key (можно копировать):"
green "/root/ygkkkca/private.key"
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
if [[ -f '/etc/hysteria/config.json' ]]; then
blue "Обнаружен протокол Hysteria-1. Если установлен скрипт Hysteria от Yongge, выполните запрос/смену сертификата в том скрипте для автоматического применения"
fi
if [[ -f '/etc/caddy/Caddyfile' ]]; then
blue "Обнаружен протокол Naiveproxy. Если установлен скрипт Naiveproxy от Yongge, выполните запрос/смену сертификата в том скрипте для автоматического применения"
fi
if [[ -f '/etc/tuic/tuic.json' ]]; then
blue "Обнаружен протокол Tuic. Если установлен скрипт Tuic от Yongge, выполните запрос/смену сертификата в том скрипте для автоматического применения"
fi
if [[ -f '/usr/bin/x-ui' ]]; then
blue "Обнаружен x-ui (протокол xray). Если установлен скрипт x-ui от Yongge, включите опцию TLS, сертификат применится автоматически"
fi
if [[ -f '/etc/s-box/sb.json' ]]; then
blue "Обнаружено ядро Sing-box. Если установлен скрипт Sing-box от Yongge, выполните запрос/смену сертификата в том скрипте для автоматического применения"
fi
else
bash ~/.acme.sh/acme.sh --uninstall >/dev/null 2>&1
rm -rf /root/ygkkkca
rm -rf ~/.acme.sh acme.sh
uncronac
red "К сожалению, не удалось получить сертификат. Рекомендации:"
yellow "1. Если IP начинается на 104.2 или 172, убедитесь, что 'желтое облако' CDN в Cloudflare отключено. IP домена должен совпадать с IP VPS."
echo
yellow "2. Смените имя поддомена и попробуйте переустановить скрипт (Важно)"
green "Пример: был x.ygkkk.eu.org или x.ygkkk.cf, переименуйте 'x' в Cloudflare."
echo
yellow "3. Существует лимит на частоту запросов для одного IP. Подождите некоторое время и попробуйте снова." && exit
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
vpsip="$v6 или $v4"
else
vpsip=$v4
fi
domainIP=$(dig @8.8.8.8 +time=2 +short "$ym" 2>/dev/null | grep -m1 '^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$')
if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]]; then
domainIP=$(dig @2001:4860:4860::8888 +time=2 aaaa +short "$ym" 2>/dev/null | grep -m1 ':')
fi
if echo $domainIP | grep -q "network unreachable\|timed out" || [[ -z $domainIP ]] ; then
red "IP не распознан, проверьте правильность ввода домена" 
yellow "Попробовать ввести IP вручную?"
yellow "1：Да! Ввести IP домена"
yellow "2：Нет! Выйти из скрипта"
readp "Пожалуйста, выберите：" menu
if [ "$menu" = "1" ] ; then
green "Локальный IP VPS：$vpsip"
readp "Введите IP, на который настроен домен (должен совпадать с $vpsip):" domainIP
else
exit
fi
elif [[ -n $(echo $domainIP | grep ":") ]]; then
green "Текущий IPv6 адрес домена: $domainIP"
else
green "Текущий IPv4 адрес домена: $domainIP"
fi
if [[ ! $domainIP =~ $v4 ]] && [[ ! $domainIP =~ $v6 ]]; then
yellow "Текущий локальный IP VPS: $vpsip"
red "IP, на который настроен домен, НЕ СОВПАДАЕТ с локальным IP VPS!!!"
green "Рекомендации:"
if [[ "$v6" == "2a09"* || "$v4" == "104.28"* ]]; then
yellow "WARP не отключился автоматически, отключите его вручную! Или используйте скрипт WARP от Yongge с поддержкой авто-отключения."
else
yellow "1. Убедитесь, что 'желтое облако' CDN отключено (только DNS), проверьте настройки на сайте регистратора."
yellow "2. Проверьте правильность IP-адреса в настройках DNS вашего домена."
fi
exit 
else
green "IP совпадает, начинаем процедуру получения сертификата…………"
fi
}

checkacmeca(){
if [[ "${ym}" == *ip6.arpa* ]]; then
red "В настоящее время домены ip6.arpa не поддерживаются" && exit
fi
nowca=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
if [[ $nowca == $ym ]]; then
red "Обнаружено, что для этого домена уже есть запись о сертификате, повторный запрос не нужен"
red "Запись о сертификате:"
bash ~/.acme.sh/acme.sh --list
yellow "Если вы хотите получить сертификат заново, сначала выберите опцию удаления сертификата" && exit
fi
}

ACMEstandaloneDNS(){
v4v6
readp "Введите настроенный домен:" ym
green "Введенный домен:$ym" && sleep 1
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
readp "Введите настроенный домен:" ym
green "Введенный домен:$ym" && sleep 1
checkacmeca
freenom=`echo $ym | awk -F '.' '{print $NF}'`
if [[ $freenom =~ tk|ga|gq|ml|cf ]]; then
red "Обнаружен бесплатный домен freenom. Режим DNS API не поддерживается, выход." && exit 
fi
if [[ -n $(echo $ym | grep \*) ]]; then
green "Обнаружен запрос Wildcard (пан-домен) сертификата," && sleep 2
else
green "Обнаружен запрос однодоменного сертификата," && sleep 2
fi
checkacmeca
checkip
echo
ab="Выберите провайдера DNS:\n1.Cloudflare\n2.Tencent Cloud DNSPod\n3.Aliyun\n Выберите："
readp "$ab" cd
case "$cd" in 
1 )
readp "Введите Cloudflare Global API Key：" GAK
export CF_Key="$GAK"
readp "Введите Email, зарегистрированный в Cloudflare：" CFemail
export CF_Email="$CFemail"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
;;
2 )
readp "Введите Tencent Cloud DNSPod DP_Id：" DPID
export DP_Id="$DPID"
readp "Введите Tencent Cloud DNSPod DP_Key：" DPKEY
export DP_Key="$DPKEY"
if [[ $domainIP = $v4 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --insecure
fi
if [[ $domainIP = $v6 ]]; then
bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d ${ym} -k ec-256 --server letsencrypt --listen-v6 --insecure
fi
;;
3 )
readp "Введите Aliyun Ali_Key：" ALKEY
export Ali_Key="$ALKEY"
readp "Введите Aliyun Ali_Secret：" ALSER
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
ab="1.Режим Standalone (Порт 80) (Только домен, для новичков), порт 80 будет освобожден принудительно\n2.Режим DNS API (Нужен Домен, ID, Key), авто-определение Single/Wildcard домена\n0.Назад\n Выберите："
readp "$ab" cd
case "$cd" in 
1 ) acme2 && acme3 && ACMEstandaloneDNScheck;;
2 ) acme3 && ACMEDNScheck;;
0 ) start_menu;;
esac
}

Certificate(){
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "acme.sh не установлен, выполнение невозможно" && exit 
green "Под Main_Domain показан домен с успешным сертификатом, под Renew - время авто-продления"
bash ~/.acme.sh/acme.sh --list
#readp "Введите домен для отзыва и удаления сертификата (скопируйте из Main_Domain, Ctrl+c для выхода):" ym
#if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $ym) ]]; then
#bash ~/.acme.sh/acme.sh --revoke -d ${ym} --ecc
#bash ~/.acme.sh/acme.sh --remove -d ${ym} --ecc
#rm -rf /root/ygkkkca
#green "Сертификат домена ${ym} успешно отозван и удален"
#else
#red "Введенный сертификат домена ${ym} не найден, проверьте данные!" && exit
#fi
}

acmeshow(){
if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
caacme1=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
if [[ -n $caacme1 && ! $caacme1 == "Main_Domain" ]] && [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
caacme=$caacme1
else
caacme='Нет записей'
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
green "Ниже показаны домены с успешно полученными сертификатами"
bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'
echo
#ab="1.Безусловное продление всех сертификатов (Рекомендуется)\n2.Выбрать определенный домен для продления\n0.Назад\n Выберите："
#readp "$ab" cd
#case "$cd" in 
#1 ) 
green "Начинаем продление сертификатов…………" && sleep 3
bash ~/.acme.sh/acme.sh --cron -f
checktls
#;;
#2 ) 
#readp "Введите домен для продления (скопируйте из Main_Domain):" ym
#if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $ym) ]]; then
#bash ~/.acme.sh/acme.sh --renew -d ${ym} --force --ecc
#checktls
#else
#red "Введенный сертификат домена ${ym} не найден, проверьте данные!" && exit
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
[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && green "acme.sh удален" || red "Ошибка удаления acme.sh"
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
white "Github проект  ：github.com/yonggekkk"
white "Blogger блог   ：ygkkk.blogspot.com"
white "YouTube канал  ：www.youtube.com/@ygkkk"
yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
green "Версия скрипта Acme-yg V2023.12.18"
yellow "Подсказки："
yellow "1. Скрипт не поддерживает VPS с несколькими IP, IP SSH входа и общий IP должны совпадать"
yellow "2. Режим порта 80 поддерживает только один домен и авто-продление, если порт 80 свободен"
yellow "3. Режим DNS API не поддерживает бесплатные домены Freenom, но поддерживает Single/Wildcard домены и авто-продление"
yellow "4. Для Wildcard доменов нужна DNS запись с именем * (Формат: *.domain.com)"
yellow "Путь к файлу публичного ключа crt: /root/ygkkkca/cert.crt"
yellow "Путь к файлу приватного ключа key: /root/ygkkkca/private.key"
echo
red "========================================================================="
acmeshow
blue "Текущие успешно полученные сертификаты (домены):"
yellow "$caacme"
echo
red "========================================================================="
green " 1. Получить сертификат letsencrypt ECC через acme.sh (Порт 80 или DNS API) "
green " 2. Показать успешные домены и время авто-продления "
green " 3. Ручное принудительное продление сертификатов "
green " 4. Удалить сертификаты и удалить скрипт ACME "
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
