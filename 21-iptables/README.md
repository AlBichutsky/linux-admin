# 21. IPTABLES
## Задание

 1) Реализовать knocking port.
- centralRouter может попасть на ssh inetrRouter через knock скрипт.
2) Добавить inetRouter2, который виден(маршрутизируется) с хоста.
3) Запустить nginx на centralServer.
4) Пробросить 80й порт на inetRouter2 8080.
5) Дефолт в инет оставить через inetRouter.

Критерии оценки: 5 - все сделано. 

## Решение

Тестовый стенд разворачивается помощью Vagrant

Для запуска выполнить:

```bash
vagrant up
```
#### Схема тестового стенда
![alt text](plan_network_iptables.png)

###  1.Реализовать knocking port: centralRouter может попасть на ssh inetRouter через knock скрипт

Нам необходимо запретить доступ по ssh к inetRouter всем, кроме тех, кто знает «как правильно постучаться». 

Перед ssh-подключением потребуется последовательно постучаться на следующие порты inetRouter: 8881 7777 9991 и затем в течении 30 сек открыть ssh-сессию.

Применены правила iptables на inetRouter:
```bash
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
iptables
# Сохраняем правила
service iptables save
```
Чтобы постучаться к inetRouter, на centralRouter используем скрипт `knock.sh` с параметрами:
- имя/ip хоста;
- порты, на которые стучимся

У нас есть 30 секунд для подключения после запуска скрипта. Если не успели за этот интервал, то придётся запускать скрипт заново.

Выполняем команду для подключения к inetRouter:
```bash
bash /vagrant/knock.sh 192.168.255.1 8881 7777 9991 && ssh vagrant@192.168.255.1
```
### 2. Добавить inetRouter2, который виден(маршрутизируется) с хоста.

- в Vagrantfile добавлен inetRouter2 с public-интерфейсом - 192.168.50.10, который виден с моей хостовой машины (хостовая машина и inetRouter2 в одной сети).
```
[Alexey@alexhome 21-iptables]$ ping 192.168.50.10 -c3
PING 192.168.50.10 (192.168.50.10) 56(84) bytes of data.
64 bytes from 192.168.50.10: icmp_seq=1 ttl=64 time=0.138 ms
64 bytes from 192.168.50.10: icmp_seq=2 ttl=64 time=0.205 ms
64 bytes from 192.168.50.10: icmp_seq=3 ttl=64 time=0.201 ms

--- 192.168.50.10 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1999ms
rtt min/avg/max/mdev = 0.138/0.181/0.205/0.032 ms
```

### 3. Запустить nginx на centralServer
- для проверки в Vagrantfile также добавлен public-интерфейс - 192.168.50.12 для centralServer, который виден с моей хостовой машины (хостовая машина и centralServer в одной сети).

Стартовая страница nginx на centralServer открывается:

![alt text](nginx_on_centralServer.png)

### 4. Пробросить http c inetRouter2:8080 на centralServer:80.

При обращении к inetRouter2:8080 должна открываться страница nginx на centralServer:80.

Применены правила iptables на inetRouter2:
```bash
# Проброс http c интерфейса eth0 (inet)

# все что приходит на адрес 10.0.2.15 (inet) на порт 8080 будет пересылаться на адрес 192.168.0.2 через destination NAT
iptables -t nat -A PREROUTING --dst 10.0.2.15 -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
# Разрешаем проходящие соединения в цепочке FORWARD.
# После прохождения цепочки PREROUTING пакет c интерфейса eth0 (inet) будет отправлен через eth1 (192.168.254.1) до 192.168.0.2
iptables -I FORWARD 1 -i eth0 -o eth1 -d 192.168.0.2 -p tcp -m tcp --dport 8080 -j ACCEPT

# Проброс http c интерфейса eth4 (public) для проверки

# все что приходит на public ip 192.168.50.10 на порт 80 будет пересылаться на адрес 192.168.0.2 через destination NAT
iptables -t nat -A PREROUTING --dst 192.168.50.10 -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
# Разрешаем проходящие соединения в цепочке FORWARD.
# После прохождения цепочки PREROUTING пакет c интерфейса eth4 (public) будет отправлен через eth1 (192.168.254.1) до 192.168.0.2
iptables -I FORWARD 1 -i eth2 -o eth1 -d 192.168.0.2 -p tcp -m tcp --dport 8080 -j ACCEPT
```

### 5. Дефолт в инет оставить через inetRouter

Проверяем, что пакеты c centralServer в интернет идут через inetRouter:
```bash
[root@centralServer vagrant]# traceroute mail.ru
traceroute to mail.ru (217.69.139.200), 30 hops max, 60 byte packets
 1  gateway (192.168.0.1)  0.203 ms  0.142 ms  0.101 ms
 2  192.168.255.1 (192.168.255.1)  0.376 ms  0.342 ms  0.348 ms
 3  * * *
 4  * * *
 5  * * *
 6  * * *
 7  77.94.178.17 (77.94.178.17)  3.379 ms  3.429 ms  3.301 ms
 8  ae3-atlant-mmts9-msk.naukanet.ru (77.94.160.48)  3.257 ms  3.205 ms  2.948 ms
 9  mail-ru.naukanet.ru (77.94.167.182)  2.892 ms  2.684 ms  2.627 ms
10  * * *
11  * * *
12  *^C
[root@centralServer vagrant]#
```