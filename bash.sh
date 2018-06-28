#!/bin/sh
# This is Script for Shadowsocks+pptp installing and starting on CentOS6
#获取ip
ipaddr=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
#配置iptables防火墙
iptables -F
iptables -X
iptables -Z

#禁止其他端口输入 远程SSH端口必须保证打开
iptables -P INPUT DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

#允许ping
iptables -A INPUT -p icmp -j ACCEPT

#pptp端口
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 1723 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 113 -j ACCEPT
iptables -A INPUT -p udp -m udp --dport 1194 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 1194 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 47 -j ACCEPT

#L2TP端口
iptables -A INPUT -m policy --dir in --pol ipsec -p udp --dport 1701 -j ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT

#VPN分配ip
iptables -A FORWARD -s 10.0.0.0/24 -o eth0 -j ACCEPT
iptables -A FORWARD -d 10.0.0.0/24 -i eth0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -j SNAT --to-source $ipaddr

#屏蔽常见后门
iptables -A OUTPUT -p tcp -m tcp --sport 31337 -j DROP
iptables -A OUTPUT -p tcp -m tcp --dport 31337 -j DROP
service iptables save
service iptables restart && echo "iptables Starts OK"

#pptp dns用的谷歌，用户名vpn/vpnuser/...密码victory
yum install -y ppp
yum install -y pptp
yum install -y pptpd
echo "ms-dns 8.8.8.8" >> /etc/ppp/options.pptpd
echo "ms-dns 8.8.4.4" >> /etc/ppp/options.pptpd
echo "vpn * victory *" >> /etc/ppp/chap-secrets
echo "vpnuser * victory *" >> /etc/ppp/chap-secrets
echo "vpnuser1 * victory *" >> /etc/ppp/chap-secrets
echo "vpnuser2 * victory *" >> /etc/ppp/chap-secrets
echo "localip 10.0.0.1" >> /etc/pptpd.conf
echo "remoteip 10.0.0.10-100" >> /etc/pptpd.conf

#设置ipv4转发
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "echo 1 > /proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
sysctl -p && echo "TCP optimizes OK"

#启动服务
chkconfig pptpd on
chkconfig iptables on
service iptables start
service pptpd start

#设置Shadowsocks接口、密码、加密等
port=443
password='study'
method='aes-256-cfb'
#安装必须报
yum install -y m2crypto python-setuptools python-pip
easy_install pip
pip install shadowsocks && echo "Shadowsocks Install OK"
#添加转发
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport $port -j ACCEPT
iptables -A INPUT -m state --state NEW -m udp -p udp --dport $port -j ACCEPT
service iptables save
service iptables restart && echo "iptables Starts OK"
#优化SS传输
ulimit -n 51200
echo "* soft nofile 51200" >> /etc/security/limits.conf
echo "* hard nofile 51200" >> /etc/security/limits.conf
echo "net.core.rmem_max = 67108864" >> /etc/sysctl.conf
echo "net.core.wmem_max = 67108864" >> /etc/sysctl.conf
echo "net.core.netdev_max_backlog = 250000" >> /etc/sysctl.conf
echo "net.core.somaxconn = 3240000" >> /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 10000 65000" >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle = 0" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fin_timeout = 30" >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_time = 1200" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 8192" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_tw_buckets = 5000" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fastopen = 3" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 67108864" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 67108864" >> /etc/sysctl.conf
echo "net.ipv4.tcp_mtu_probing = 1" >> /etc/sysctl.conf
#如果延迟高（卡）用hybla模式，延迟低用cubic
echo "# for high-latency network" >> /etc/sysctl.conf
echo "# net.ipv4.tcp_congestion_control = hybla" >> /etc/sysctl.conf
echo "# for low-latency network, use cubic instead" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = cubic" >> /etc/sysctl.conf
sysctl -p && echo "TCP optimizes OK"
#启动SS服务
nohup ssserver -p $port -k $password -m $method --user nobody -d start > /dev/null 2>&1 &
echo "Shadowsocks Start OK"
echo "------------------------------------------------------------------"
#打印SS配置信息
printf "Server:\t\t$ipaddr\n"
printf "Port:\t\t$port\n"
printf "Method:\t\t$method\n"
printf "Password:\t\t$password\n"
#SS服务加自启
echo "ssserver -p $port -k $password -m $method --user nobody -d start" >> /etc/rc.local
