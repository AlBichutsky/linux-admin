### Пример настройки кластера

Все действия производятся на хосте mysql-shell

```bash
sudo mysqlsh --uri admin@node1 -e "dba.createCluster('clTest');
```
```bash
sudo mysqlsh --uri admin@node1 -e "dba.getCluster().addInstance('admin@node2');"
```
```bash
sudo mysqlsh --uri admin@node1 -e "dba.getCluster().addInstance('admin@node3');"
```

Просмотр состояния
```bash
sudo mysqlsh --uri admin@node1 -e "dba.getCluster().status()"
```
Инициализация и запуск mysql-router
```
mysqlrouter --bootstrap admin@node1 --user=mysqlrouter mysqlrouter&
```
Подключение к кластеру
```
mysql -u admin -p -P6446 -h 127.0.0.1
```