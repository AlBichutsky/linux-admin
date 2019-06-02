#!/bin/bash

# Проброс http c интерфейса eth0 (inet)

# все что приходит на адрес 10.0.2.15 (inet) по 80 порту будет пересылаться на адрес 192.168.0.2 через destination NAT
iptables -t nat -A PREROUTING --dst 10.0.2.15 -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
# все что приходит на public ip 192.168.50.10 по 80 порту будет пересылаться на адрес 192.168.0.2 через destination NAT
iptables -t nat -A PREROUTING --dst 192.168.50.10 -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80

# Разрешаем проходящие соединения в цепочке FORWARD.

# После прохождения цепочки PREROUTING пакет c интерфейса eth0 (inet) будет направлен на маршрутизацию через eth1 (192.168.254.1) до 192.168.0.2
iptables -I FORWARD 1 -i eth0 -o eth1 -d 192.168.0.2 -p tcp -m tcp --dport 8080 -j ACCEPT
# После прохождения цепочки PREROUTING пакет c интерфейса eth2 (public) будет направлен на маршрутизацию через eth1 (192.168.254.1) до 192.168.0.2
iptables -I FORWARD 1 -i eth2 -o eth1 -d 192.168.0.2 -p tcp -m tcp --dport 8080 -j ACCEPT

# Сохраняем правила
service iptables save

# end
