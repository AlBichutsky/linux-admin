# 12. Backup
## Задание
Настраиваем бэкапы.
Настроить стенд Vagrant с двумя виртуальными машинами server и client.

Настроить политику бэкапа директории /etc с клиента:
1) Полный бэкап - раз в день.
2) Инкрементальный - каждые 10 минут.
3) Дифференциальный - каждые 30 минут.

Запустить систему на два часа. Для сдачи ДЗ приложить list jobs, list files jobid=<id>
и сами конфиги bacula-*

* Настроить доп. опции - сжатие, шифрование, дедупликация.

## Приложены файлы:
- [Vagrantfile](Vagrantfile)
- Конфиги bacula:
  - [bacula-dir.conf](bacula-dir.conf)
  - [bacula-sd.conf](bacula-sd.conf)
  - [bacula-fd.conf](bacula-fd.conf)
  - [bconsole.conf](bconsole.conf)
- Лог bconsole с выводом команд:
  - [bconsole.log](bconsole.log)

## Инструкция по запуску тестового стенда (задание без *)

1. С помощью [Vagrantfile](Vagrantfile) развернуть тестовые хосты:
- bacula-server  (имя для ssh-подключения: server).  
- bacula-client1 (имя для ssh-подключения: client1). Бэкапится каталог /etc.
- bacula-client2 (имя для ssh-подключения: client2). Бэкапирование не настроено.

2. После разворачивания хостов необходимо авторизоваться на сервере bacula:
```
vagrant ssh
```
Cкопировать пароль пользователя bacula БД postgres из файла .pgpass:

```
$ cat /var/spool/bacula/.pgpass 
localhost:5432:bacula:bacula:YjJhMDk2ODI4ZjUwOTI0Y2NmMTE0N2ZiY
```
И заменить его в строчке `password = ` секции `Generic catalog service` файла bacula-dir.conf. Пример:
```
$ cat /etc/bacula/bacula-dir.conf
...
# Generic catalog service
Catalog {
  Name = MyCatalog
  dbname = "bacula"; DB Address = "127.0.0.1"; dbuser = "bacula"; password = "YjJhMDk2ODI4ZjUwOTI0Y2NmMTE0N2ZiY"
}
...
```
3. Для проверки войти в консоль bacula:
```
$ bconsole
```
Для отладки можно попробовать подключиться к БД posgres от имени пользователя bacula (пароль из файла .pgpass):
```
$ psql -h 127.0.0.1 -U bacula
```
Selinux и firewalld отключены для тестирования.
