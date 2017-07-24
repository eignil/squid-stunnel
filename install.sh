#!/usr/bin/env bash

source ./common.sh

[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1

domains=""
squid_ip="127.0.0.1"
squid_port="3128"
stunnel_port="4128"
#install certbot
install_certbot(){
apt-get -y update
apt-get -y install software-properties-common
add-apt-repository -y ppa:certbot/certbot
apt-get -y update
apt-get -y install certbot
}

install_software(){
install_dependencies "stunnel4 squid"
install_certbot
}
get_squid_ip_port(){
    echo "Please enter listen ip for squid."
    read -p "Default ip is empty(mean all ip address):" squid_ip
    echo
    echo "listen ip = ${squid_ip}"
    echo
    echo "Please enter listen port for squid."
    read -p "Default port is 3128:" squid_port
    [ -z "${squid_port}" ] && squid_port="3128"
    echo
    echo "listen port = ${squid_port}"
    echo

}

set_squid_ip_port() {
    if [ -s /etc/squid/squid.conf ] && grep 'http_port 3128' /etc/squid/squid.conf; then
        cp /etc/squid/squid.conf /etc/squid/squid.conf_bak
        sed -i "s/http_port 3128/http_port ${squid_ip}:${squid_port}/g" /etc/squid/squid.conf
    fi
}

config_start_squid(){
set_squid_ip_port
service squid restart
}


get_certificate_setting(){
    echo "Please enter the domains which want to get certificate from let's encrypt."
    read -p "Seperate with comma or space(example.com, www.example.com):" domains
    [ -z "${domains}" ] && domains="example.com"
    echo
    echo "domains: ${domains}"
    echo
    echo "Please enter email for important account notifications."
    read -p "Email address for important account notifications(example@example.com):" email
    [ -z "${email}" ] && email="example@example.com"
    echo
    echo "email: ${email}"
    echo
}
##
#get certificate
##
#for domain in ${domains}; do
#    certbot certonly --standalone -d ${domain}
#done
gen_certificate(){
certbot certonly --standalone -d ${domains} -m ${email}
certbot certificates
cert_path="/etc/letsencrypt/live/${domains}/fullchain.pem"
key_path="/etc/letsencrypt/live/${domains}/privkey.pem"
#grep -oE  "/etc/letsencrypt/live/${domain}/\.pem$" ./certificates_rest.tmp
}

get_stunnel_port(){
    echo "Please enter listen port for stunnel."
    read -p "Default port is 4128:" stunnel_port
    [ -z "${stunnel_port}" ] && stunnel_port="4128"
    echo
    echo "listen port = ${stunnel_port}"
    echo
}

##
#set certificate for stunnel
##
set_stunnel(){
if [ ! -f /etc/stunnel/stunnel.conf ]; then
    touch /etc/stunnel/stunnel.conf
    cat > /etc/stunnel/stunnel.conf<<-EOF
        client = no
        [squid]
        accept = ${stunnel_port}
        connect = ${squid_ip}:${squid_port}
        cert = ${cert_path}
        key  = ${key_path}
EOF
fi

sed -i "s/ENABLED=0/ENABLED=1/g" /etc/default/stunnel4
}

config_start_stunnel(){
#gen_certificate
set_stunnel
service stunnel4 restart
}
get_info(){
get_squid_ip_port
get_certificate_setting
get_stunnel_port
}
get_info
install_software
config_start_squid
config_start_stunnel
