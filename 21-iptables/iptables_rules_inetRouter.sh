#!/bin/bash
# Добавляем правило для NAT, чтобы гостевые машины могли ходит в интернет через inetRouter
iptables -t nat -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
# Правила для knocking port
# создаем 3 новые цепочки правил TRAFFIC, SSH-INPUT, SSH-INPUTTWO
iptables -t filter -N TRAFFIC
iptables -t filter -N SSH-INPUT
iptables -t filter -N SSH-INPUTTWO
# Правила для цепочки TRAFFIC
iptables -t filter -A INPUT -j TRAFFIC
iptables -t filter -A TRAFFIC -p icmp --icmp-type any -j ACCEPT
iptables -t filter -A TRAFFIC -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 22 -m recent --rcheck --seconds 30 --name SSH2 -j ACCEPT
iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH2 --remove -j DROP
iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 9991 -m recent --rcheck --name SSH1 -j SSH-INPUTTWO
iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH1 --remove -j DROP
iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 7777 -m recent --rcheck --name SSH0 -j SSH-INPUT
iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH0 --remove -j DROP
iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 8881 -m recent --name SSH0 --set -j DROP
# Правила для цепочки SSH-INPUT
iptables -t filter -A SSH-INPUT -m recent --name SSH1 --set -j DROP
# Правила для цепочки SSH-INPUTTWO
iptables -t filter -A SSH-INPUTTWO -m recent --name SSH2 --set -j DROP
# 
iptables -t filter -A TRAFFIC -j DROP
# Сохраняем правила
service iptables save

# end
