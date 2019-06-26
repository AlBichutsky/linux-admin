# 28. MySQL InnoDB-cluster

## Установка Docker Compose

После установки Docker можно приступать к установке Docker Compose. 

Для начала установим python-pip:

```
sudo yum install epel-release
sudo yum install -y python-pip
```

Установим Docker Compose через pip:

```
sudo pip install docker-compose
```

Также нужно обновить пакеты Python системы CentOS 7:

```
sudo yum upgrade python*
```


## Запуск

Разворачиваем контейнеры из образов (указано в файле docker-compose.yml):
```
docker-compose up
docker compose down
```
Проверяем контейнеры и номера портов, на которых работет mysql:
```
docker-compose ps
```

Подключение к серверам mysql в контейнерах выполняем так:

УЗнать ip
```
docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq)
```

### mysql-shell

Запустить оболочку контейнера:
```
docker exec -ti innodb_mysql-shell_1 bash
```
Проверить состояние кластера
```
bash-4.2# mysqlsh --uri root@node1
dba.getCluster().status()
```

### node1
Узнать ip
```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' innodb_node1_1
```
Запустить оболочку контейнера:
```bash
docker exec -ti innodb_node1_1 bash
```
Войти в mysql
```bash
mysql -h 127.0.0.1 -P 3301 -uroot -pmysql

```

### node2
```
docker exec -ti node2 bash
```
```
mysql -h 127.0.0.1 -P 3302 -uroot -pmysql

```

### node3
```
docker exec -ti node3 bash
```
```
mysql -h 127.0.0.1 -P 3303 -uroot -pmysql

```

Создаем свой образ из контейнера и пушим на хаб:
```bash
docker commit -m "innodb_mysql-shell 1-th commit" -a "Alexey B." 3a1cc1d7e359 abichutsky/mysql-shell:v1
docker images
docker push abichutsky/mysql-shell
```

Инициализация кластера

```bash
bash-4.2# mysqlsh --uri root@node1
Creating a session to 'root@node1'
Please provide the password for 'root@node1': *****
Fetching schema names for autocompletion... Press ^C to stop.
Your MySQL connection id is 26 (X protocol)
Server version: 8.0.12 MySQL Community Server - GPL
No default schema selected; type \use <schema> to set one.
MySQL Shell 8.0.12

Copyright (c) 2016, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type '\help' or '\?' for help; '\quit' to exit.


 MySQL  node1:33060+ ssl  JS > dba.createCluster('ClusterTest');
A new InnoDB cluster will be created on instance 'root@node1:3306'.

Validating instance at node1:3306...

This instance reports its own address as 012c4181acc3

Instance configuration is suitable.
Creating InnoDB cluster 'ClusterTest' on 'root@node1:3306'...
Adding Seed Instance...

Cluster successfully created. Use Cluster.addInstance() to add MySQL instances.
At least 3 instances are needed for the cluster to be able to withstand up to
one server failure.

<Cluster:ClusterTest>

 MySQL  node1:33060+ ssl  JS > dba.getCluster().addInstance('root@node2');
A new instance will be added to the InnoDB cluster. Depending on the amount of
data on the cluster this might take from a few seconds to several hours.

Adding instance to the cluster ...

Please provide the password for 'root@node2': *****
Validating instance at node2:3306...

This instance reports its own address as c5fb77a2df82

Instance configuration is suitable.
The instance 'root@node2' was successfully added to the cluster.


 MySQL  node1:33060+ ssl  JS > dba.getCluster().addInstance('root@node3');
A new instance will be added to the InnoDB cluster. Depending on the amount of
data on the cluster this might take from a few seconds to several hours.

Adding instance to the cluster ...

Please provide the password for 'root@node3': *****
Validating instance at node3:3306...

This instance reports its own address as 105f6a97d2a7

Instance configuration is suitable.
The instance 'root@node3' was successfully added to the cluster.


 MySQL  node1:33060+ ssl  JS > dba.getCluster().status()
{
    "clusterName": "ClusterTest",
    "defaultReplicaSet": {
        "name": "default",
        "primary": "node1:3306",
        "ssl": "REQUIRED",
        "status": "OK",
        "statusText": "Cluster is ONLINE and can tolerate up to ONE failure.",
        "topology": {
            "node1:3306": {
                "address": "node1:3306",
                "mode": "R/W",
                "readReplicas": {},
                "role": "HA",
                "status": "ONLINE"
            },
            "node2:3306": {
                "address": "node2:3306",
                "mode": "R/O",
                "readReplicas": {},
                "role": "HA",
                "status": "ONLINE"
            },
            "node3:3306": {
                "address": "node3:3306",
                "mode": "R/O",
                "readReplicas": {},
                "role": "HA",
                "status": "ONLINE"
            }
        }
    },
    "groupInformationSourceMember": "mysql://root@node1:3306"
}

 MySQL  node1:33060+ ssl  JS > dba.configureLocalInstance()
The instance 'node1:3306' belongs to an InnoDB cluster.
Calling this function on a cluster member is only required for MySQL versions 8.0.4 or earlier.

 MySQL  node1:33060+ ssl  JS >

```