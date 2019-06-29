# 28. MySQL InnoDB-cluster

Развернуть InnoDB кластер в docker 
*в docker swarm

В качестве ДЗ принимает репозиторий с docker-compose, который по кнопке разворачивает кластер и выдает порт наружу.

## Установка Docker Compose

После установки Docker выполняется установка Docker Compose по инструкции 
```https://docs.docker.com/compose/install/``` 

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```
## Описание тестового стенда

Для запуска контейнеров используются официальные образы mysql:
- ```mysql/mysql-server:8.0.12```
- ```mysql/mysql-router:8.0```

Кластер InnoDB состоит из контейнеров:
- ```mysql-shell``` - консоль mysqlsh для управления кластером
- ```mysql-router``` - обеспечивает маршрутизацию соединений к серверам MySQL в кластере для повышения производительности и надежности,
при настройке роутера указывается главная нода (Primary instance), чтобы он увидел все существующие ноды в кластере
- ```node1``` - 1-я нода кластера (Primary instance, в режиме R/W)
- ```node2``` - 2-я нода кластера (Secondary instance, в режиме R/O)
- ```node3``` - 3-я нода кластера (Secondary instance, в режиме R/O)

На всех серверах: логин: ```root```, пароль: ```mysql```

В каталоге /data хранятся тома, которые монтируются в контейнерах и служат для хранения данных mysql (БД, логи и т.д.).

Пример маппинга томов в docker-compose.yml:
```
 volumes:
      - ./data/node1:/var/lib/mysql
```
Порты для соединений: 
- `mysql-router`: tcp 6446
- `mysql-shell`, `node`,`node2`,`node3`: tcp 3306. Между собой общаются по порту tcp 33060.

## Запуск докера

Запускаем контейнеры в docker-compose:
```bash
docker-compose up -d
```
Проверяем состояние контейнеров и номера открытых портов:
```bash
root@alexhome innodb]# docker-compose ps
        Name                       Command                  State                               Ports
------------------------------------------------------------------------------------------------------------------------------
innodb_mysql-router_1   /run.sh mysqlrouter              Up (healthy)   0.0.0.0:6446->6446/tcp, 64460/tcp, 6447/tcp, 64470/tcp
innodb_mysql-shell_1    /entrypoint.sh mysqld            Up (healthy)   3306/tcp, 33060/tcp
innodb_node1_1          /entrypoint.sh mysqld --se ...   Up (healthy)   0.0.0.0:3301->3306/tcp, 33060/tcp
innodb_node2_1          /entrypoint.sh mysqld --se ...   Up (healthy)   0.0.0.0:3302->3306/tcp, 33060/tcp
innodb_node3_1          /entrypoint.sh mysqld --se ...   Up (healthy)   0.0.0.0:3303->3306/tcp, 33060/tcp
```
В случае ошибок пересоздаем контейнеры с очисткой данных томов от mysql:
```bash
sudo su
docker-compose down && sudo rm -rf data/mysql-shell/* && rm -rf data/node1/* && rm -rf data/node2/* && rm -rf data/node3/* && docker-compose up -d
```
## Проверка работы кластера

Соединения в кластере будет принимать `mysql-router` на порту 6446. Роутер будет перенаправлять все запросы на главную ноду, остальные ноды - это реплика.
Если главная нода стала недоступной, то в процессе перевыборов назначается новая главная нода.

Заливаем дамп базы `bet` на кластер:
```bash
# создаем чистую БД bet
[Alexey@alexhome innodb]$ docker exec -i innodb_mysql-router_1 mysql -uroot -pmysql -e "CREATE DATABASE bet;"
# заливаем в нее дамп
[Alexey@alexhome innodb]$ docker exec -i innodb_mysql-router_1 mysql -uroot -pmysql bet < ./scripts/bet.dmp
# проверяем созданные таблицы
[Alexey@alexhome innodb]$ docker exec -i innodb_mysql-router_1 mysql -uroot -pmysql -e "USE bet; SHOW TABLES;"
Tables_in_bet
bookmaker
competition
events_on_demand
market
odds
outcome
v_same_event
```
Проверяем, что БД залилась на все ноды кластера:
```bash
[Alexey@alexhome innodb]$ docker exec -i innodb_node1_1 mysql -uroot -pmysql -e "USE bet; SHOW TABLES;"
Tables_in_bet
bookmaker
competition
events_on_demand
market
odds
outcome
v_same_event
```
```bash
[Alexey@alexhome innodb]$ docker exec -i innodb_node2_1 mysql -uroot -pmysql -e "USE bet; SHOW TABLES;"
Tables_in_bet
bookmaker
competition
events_on_demand
market
odds
outcome
v_same_event
```
```bash
[Alexey@alexhome innodb]$ docker exec -i innodb_node3_1 mysql -uroot -pmysql -e "USE bet; SHOW TABLES;"
Tables_in_bet
bookmaker
competition
events_on_demand
market
odds
outcome
v_same_event
```
Проверяем откзоустойчивость кластера, отключив главную ноду ```node1```.
```
docker-compose stop node1
```
Узнаем ip-адрес mysql-router (docker выдает динамически)
```bash
docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq)
```
Проверяем доступность БД ```bet```, подключившись к ```mysql-router``` со своего хоста и создав новую запись ```test``` в таблице ```bookmaker```:
```bash
[Alexey@alexhome innodb]$ mysql -h 172.18.0.6 -u root -pmysql -P 6446
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MySQL connection id is 216
Server version: 8.0.12 MySQL Community Server - GPL

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MySQL [(none)]> use bet; show tables;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.00 sec)

MySQL [bet]> insert into bookmaker (bookmaker_name) value ('test');
Query OK, 1 row affected (0.08 sec)

MySQL [bet]> select * from bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  7 | test           |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```
Проверяем, что запись ```test``` создалась на работающих нодах ```node2``` и ```node3```:
```bash
[Alexey@alexhome innodb]$ mysql -h 172.18.0.2 -u root -pmysql -P 3306 -e "USE bet; select * from bookmaker;"
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  7 | test           |
|  3 | unibet         |
+----+----------------+
```
```bash
[Alexey@alexhome innodb]$ mysql -h 172.18.0.4 -u root -pmysql -P 3306 -e "USE bet; select * from bookmaker;"
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  7 | test           |
|  3 | unibet         |
+----+----------------+
```

### Дополнительные команды

Запускаем консоль mysqlsh в контейнере ```mysql-shell```:
```bash
# запускаем шелл контейнера
docker exec -ti innodb_mysql-shell_1 bash
# делаем запрос к 1-й ноде (соответственно, может быть выбрана 2-я и 3-я)
bash-4.2# mysqlsh --uri root@node1
# вводим комманды js, проверяем статус кластера
dba.getCluster().status()
```

Запускаем консоль mysql в контейнере ```mysql-shell```:
```bash
docker exec -ti innodb_mysql-shell_1 bash
mysql -u root -pmysql
```

Создать свой образ из текущего контейнера ```mysql-shell``` и запушить его в свой репозиторий на docker-hub:
```bash
docker commit -m "innodb_mysql-shell v.1" -a "Alexey B." 3a1cc1d7e359 abichutsky/mysql-shell:v1
docker images
docker push abichutsky/mysql-shell
```