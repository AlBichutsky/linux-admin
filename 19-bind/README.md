# 19. BIND
## Задание

### Настраиваем split-dns

Взять стенд https://github.com/erlong15/vagrant-bind

Добавить еще один сервер client2.

Завести в зоне `dns.lab` имена:
- `web1` - смотрит на клиент1;
- `web2` - смотрит на клиент2;

Завести еще одну зону `newdns.lab` с записью `www`:
- смотрит на обоих клиентов;

Настроить split-dns:
- клиент1 - видит обе зоны, но в зоне `dns.lab` только `web1`
- клиент2 - видит только `dns.lab`;

*) настроить все без выключения selinux

Критерии оценки: 
- 4 - основное задание сделано, но есть вопросы;
- 5 - сделано основное задание;
- 6 - выполнено задания со звездочкой;

## Решение

### Тестовый стенд разворачивается и настривается с помощью Vagrant + Ansible 
Для запуска стенда выполнить: 
```
vagrant up
```
### Поднимаемые хосты:
- ns01 - основной DNS-сервер (192.168.50.10) 
- ns02 - вторичный DNS-сервер (192.168.50.11)
- client -  клиент1 (192.168.50.15)
- client2 - клиент2 (192.168.50.16)

### Зона `dns.lab`
- `web1` - смотрит на клиент1;
- `web2` - смотрит на клиент2;

```
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11
; Web hosts
web1            IN      A       192.168.50.15
web2            IN      A       192.168.50.16
```
Проверка на основном DNS-сервере разрешения имен web1, web2
```
[root@ns01 vagrant]# nslookup web1
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web1.dns.lab
Address: 192.168.50.15

[root@ns01 vagrant]# nslookup web2
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web2.dns.lab
Address: 192.168.50.16
```

### Зона `newdns.lab`
- запись www смотрит на client1 и client2 
(реализована простая round robin DNS-балансировка):
```
$TTL 3600
$ORIGIN newdns.lab.
@               IN      SOA     ns01.newdns.lab. root.newdns.lab. (
                            2711201432 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.newdns.lab.
                IN      NS      ns02.newdns.lab.

; DNS Servers
ns01                  IN      A       192.168.50.10
ns02                  IN      A       192.168.50.11
; Web client
web           30s     IN      A       192.168.50.15
web           30s     IN      A       192.168.50.16
www                   IN      CNAME   web.newdns.lab.
```
Проверка на вторичном DNS-сервере разрешения имени www
```
[root@ns02 vagrant]# dig www.newdns.lab +short
web.newdns.lab.
192.168.50.16
192.168.50.15
[root@ns02 vagrant]# dig www.newdns.lab +short
web.newdns.lab.
192.168.50.15
192.168.50.16
[root@ns02 vagrant]# dig www.newdns.lab +short
web.newdns.lab.
192.168.50.15
192.168.50.16
[root@ns02 vagrant]# dig www.newdns.lab +short
web.newdns.lab.
192.168.50.16
192.168.50.15
```
### Настройка split-dns
- клиент1 - видит обе зоны (`dns.lab` и `newdns.lab`), но в зоне `dns.lab` только `web1`;
- клиент2 - видит только `dns.lab`;

split-dns реализован через представления (view), прописанные в `/etc/named.conf` на master и slave серверах (см. master-named.conf и slave-named.conf):
- client1;
- client2;
- internal_subnet;

### Проверка split-dns
- Проверка на клиенте1 разрешения имен web1, web2 (не должен разрешать), www
```
[root@client vagrant]# nslookup web1
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web1.dns.lab
Address: 192.168.50.15

[root@client vagrant]# nslookup web2
Server:         192.168.50.10
Address:        192.168.50.10#53

** server can't find web2: NXDOMAIN

[root@client vagrant]# nslookup www
Server:         192.168.50.10
Address:        192.168.50.10#53

www.newdns.lab  canonical name = web.newdns.lab.
Name:   web.newdns.lab
Address: 192.168.50.15
Name:   web.newdns.lab
Address: 192.168.50.16
```
- Проверка на клиенте2 разрешения имен web1, web2, www (не должен разрешать)
```
[root@client2 vagrant]# nslookup web1
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web1.dns.lab
Address: 192.168.50.15

[root@client2 vagrant]# nslookup web2
Server:         192.168.50.10
Address:        192.168.50.10#53

Name:   web2.dns.lab
Address: 192.168.50.16

[root@client2 vagrant]# nslookup www
Server:         192.168.50.10
Address:        192.168.50.10#53

** server can't find www: NXDOMAIN
```