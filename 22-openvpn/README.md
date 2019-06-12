# 22. OPENVPN
## Задание

1. Между двумя виртуалками поднять vpn в режимах
- tun
- tap
Прочуствовать разницу.

2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуалку


## Решение

Подготовлено 3 тестовых стенда Vagrant:
1. OpenVPN в режиме tun 
2. OpenVPN в режиме tap
3. RAS на базе OpenVPN

Для запуска нужного стенда выполнить:

```bash
vagrant up
```

#### Схема vpn-соединения (п1,2)
![alt text](1openvpn.png)


#### Проверка vpn-соединения в режиме tun

- vpnserver

Интерфейсы:

```bash
[root@vpnserver vagrant]# ip -c -h -4 a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 10.0.2.15/24 brd 10.0.2.255 scope global noprefixroute dynamic eth0
       valid_lft 80234sec preferred_lft 80234sec
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.100.1/24 brd 192.168.100.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.252.1/28 brd 192.168.252.15 scope global noprefixroute eth2
       valid_lft forever preferred_lft forever
5: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
    inet 10.8.0.1 peer 10.8.0.2/32 scope global tun0
       valid_lft forever preferred_lft forever
```

Доступность внешнего интерфейса client01:
```bash
[root@vpnserver vagrant]# ping 192.168.252.2 -c 3
PING 192.168.252.2 (192.168.252.2) 56(84) bytes of data.
64 bytes from 192.168.252.2: icmp_seq=1 ttl=64 time=0.245 ms
64 bytes from 192.168.252.2: icmp_seq=2 ttl=64 time=0.252 ms
64 bytes from 192.168.252.2: icmp_seq=3 ttl=64 time=0.283 ms

--- 192.168.252.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 0.245/0.260/0.283/0.016 ms
```
Доступность внутреннего интерфейса client01:
```bash
[root@vpnserver vagrant]# ping 192.168.101.1 -c 3
PING 192.168.101.1 (192.168.101.1) 56(84) bytes of data.
64 bytes from 192.168.101.1: icmp_seq=1 ttl=64 time=0.535 ms
64 bytes from 192.168.101.1: icmp_seq=2 ttl=64 time=0.476 ms
64 bytes from 192.168.101.1: icmp_seq=3 ttl=64 time=0.539 ms

--- 192.168.101.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 0.476/0.516/0.539/0.038 ms
```
Доступность tun-интерфейса client01 (создается при успешном vpn-соединении - ip выдается сервером)
```bash
[root@vpnserver vagrant]# ping 10.8.0.6 -c 3
PING 10.8.0.6 (10.8.0.6) 56(84) bytes of data.
64 bytes from 10.8.0.6: icmp_seq=1 ttl=64 time=0.602 ms
64 bytes from 10.8.0.6: icmp_seq=2 ttl=64 time=0.514 ms
64 bytes from 10.8.0.6: icmp_seq=3 ttl=64 time=0.475 ms

--- 10.8.0.6 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 0.475/0.530/0.602/0.056 ms
```

- client01

Интерфейсы:

```bash
[root@client01 vagrant]# ip -c -h -4 a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 10.0.2.15/24 brd 10.0.2.255 scope global noprefixroute dynamic eth0
       valid_lft 78788sec preferred_lft 78788sec
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.101.1/24 brd 192.168.101.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.252.2/28 brd 192.168.252.15 scope global noprefixroute eth2
       valid_lft forever preferred_lft forever
5: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
    inet 10.8.0.6 peer 10.8.0.5/32 scope global tun0
       valid_lft forever preferred_lft forever
```

Доступность внешнего интерфейса vpnserver:
```bash
[root@client01 vagrant]# ping 192.168.252.1 -c3
PING 192.168.252.1 (192.168.252.1) 56(84) bytes of data.
64 bytes from 192.168.252.1: icmp_seq=1 ttl=64 time=0.258 ms
64 bytes from 192.168.252.1: icmp_seq=2 ttl=64 time=0.283 ms
64 bytes from 192.168.252.1: icmp_seq=3 ttl=64 time=0.261 ms

--- 192.168.252.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2010ms
rtt min/avg/max/mdev = 0.258/0.267/0.283/0.017 ms
```
Доступность внутреннего интерфейса vpnserver:
```bash
[root@client01 vagrant]# ping 192.168.100.1 -c3
PING 192.168.100.1 (192.168.100.1) 56(84) bytes of data.
64 bytes from 192.168.100.1: icmp_seq=1 ttl=64 time=0.558 ms
64 bytes from 192.168.100.1: icmp_seq=2 ttl=64 time=0.468 ms
64 bytes from 192.168.100.1: icmp_seq=3 ttl=64 time=0.486 ms

--- 192.168.100.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2010ms
rtt min/avg/max/mdev = 0.468/0.504/0.558/0.038 ms
[root@client01 vagrant]#
```
Доступность tun-интерфейса vpnserver (всегда 10.8.0.1 - первый ip из выделяемого адресного пространства):
```bash
[root@client01 vagrant]# ping 10.8.0.1 -c3
PING 10.8.0.1 (10.8.0.1) 56(84) bytes of data.
64 bytes from 10.8.0.1: icmp_seq=1 ttl=64 time=0.496 ms
64 bytes from 10.8.0.1: icmp_seq=2 ttl=64 time=0.455 ms
64 bytes from 10.8.0.1: icmp_seq=3 ttl=64 time=0.553 ms

--- 10.8.0.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2011ms
rtt min/avg/max/mdev = 0.455/0.501/0.553/0.044 ms
```
- Тестируем пропускную способность канала в режиме tun

на vpnserver запускаем iperf в режиме сервера (отчет в Мбайтах)
```bash
[root@vpnserver vagrant]# iperf -s -f M
------------------------------------------------------------
Server listening on TCP port 5001
TCP window size: 0.08 MByte (default)
------------------------------------------------------------
[  4] local 192.168.100.1 port 5001 connected with 10.8.0.6 port 59646
[ ID] Interval       Transfer     Bandwidth
[  4]  0.0-32.2 sec  1000 MBytes  31.0 MBytes/sec
```
c client01 передаем на vpnserver данные 1000 Мб (отчет в Мбайтах)
```bash
[root@client01 vagrant]# iperf -c 192.168.100.1 -n 1000M -f M
------------------------------------------------------------
Client connecting to 192.168.100.1, TCP port 5001
TCP window size: 0.12 MByte (default)
------------------------------------------------------------
[  3] local 10.8.0.6 port 59646 connected with 192.168.100.1 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-32.2 sec  1000 MBytes  31.1 MBytes/sec
```
