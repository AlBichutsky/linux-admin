# 12. Backup (Bacula)
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
- Лог bconsole с выводом команд list jobs и т.д.:
  - [bconsole.log](bconsole.log)

## Инструкция по запуску тестового стенда (задание без *)

1. С помощью [Vagrantfile](Vagrantfile) развернуть тестовые хосты:
- bacula-server  (имя для ssh-подключения: server).  
- bacula-client1 (имя для ssh-подключения: client1). Бэкапится каталог /etc.
- bacula-client2 (имя для ssh-подключения: client2). Бэкапирование не настроено.

2. После разворачивания хостов необходимо авторизоваться на сервере bacula:
```
vagrant ssh
sudo su
```
Перейти в консоль bacula:
```
bconsole
```
## Доп.информация

Selinux и firewalld отключены для тестирования.

Пароль пользователя bacula БД postgres хранится в файле `.pgpass`:

```
$ cat /var/spool/bacula/.pgpass 
localhost:5432:bacula:bacula:password
```
Настройки подключения к БД хранятся в секции `Generic catalog service` файла bacula-dir.conf:
```
$ cat /etc/bacula/bacula-dir.conf
...
# Generic catalog service
Catalog {
  Name = MyCatalog
  dbname = "bacula"; DB Address = "127.0.0.1"; dbuser = "bacula"; password = "password"
}
...
```
Для проверки подключения к БД posgres от имени пользователя bacula с паролем из файла .pgpass выполнить:
```
$ psql -h 127.0.0.1 -U bacula
```
