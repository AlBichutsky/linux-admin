# 28. PostgreSQL репликация  

## Задание

- Настроить hot_standby репликацию с использованием слотов
- Настроить правильное резервное копирование

Для сдачи присылаем postgresql.conf, pg_hba.conf и recovery.conf
А так же конфиг barman, либо скрипт резервного копирования

## Тестовый стенд

Vagrant + Ansible

Для запуска выполнить:

```
vagrant up
```
Запускаемые хосты:

| Роль           | Имя             | IP-адрес          |
|:-------------- |:--------------- |:----------------- |
| master-сервер  | master          | 192.168.100.10/24 |
| standby-сервер | slave           | 192.168.100.11/24 |
| barman-сервер  | backup          | 192.168.100.12/24 |

### Конфигурационные файлы master-сервера

/var/lib/pgsql/11/data/pg_hba.conf
```
# PostgreSQL Client Authentication Configuration File
# ===================================================
# TYPE  DATABASE        USER              ADDRESS                            METHOD
local   all             all                                                  peer
# Разрешаем доступ ко всем БД любому пользователю из своей подсети (проверяется логин-пароль) 
host    all             all               192.168.100.0/24                   md5
# Разрешаем доступ указанным пользователям к репликации с указанных адресов (проверяется логин-пароль)
host    replication     repluser          127.0.0.1/32                       md5
host    replication     repluser          192.168.100.10/32                  md5
host    replication     repluser          192.168.100.11/32                  md5
host    replication     streaming_barman  192.168.100.12/32                  md5
```

/var/lib/pgsql/11/data/postgresql.conf
```
listen_addresses = '*'

max_connections = 50
shared_buffers = 128MB
work_mem = 32MB
dynamic_shared_memory_type = posix

fsync = on
autovacuum = on

hot_standby = on
wal_level = replica
wal_log_hints = on
max_replication_slots = 4
max_wal_senders = 6
wal_keep_segments = 64
min_wal_size = 100MB
max_wal_size = 1GB
archive_mode = on
# Настройка архивации WAL в локальную папку "archive" (при бэкапе забирает barman)
archive_command = 'cp -i %p /var/lib/pgsql/11/data/archive/%f'

# Настройка архивации WAL на сервер barman в папку "incoming"
# Рекомендуемый способ, но требуется настройка ssh-ключей для авторизации
# archive_command = 'barman-wal-archive 192.168.100.12 192.168.100.10 %p'
```

### Конфигурационные файлы standby-сервера 

/var/lib/pgsql/11/data/postgresql.conf
```
listen_addresses = '*'
hot_standby = on
```
/var/lib/pgsql/11/data/recovery.conf
```
standby_mode = 'on'
primary_conninfo = 'user=repluser passfile=''/var/lib/pgsql/.pgpass'' host=192.168.100.10 port=5432 sslmode=prefer sslcompression=0 krbsrvname=postgres target_session_attrs=any'
primary_slot_name = 'standby_slot'
```

### Конфигурационные файлы barman-сервера

/etc/barman.conf
```
[barman]
barman_user = barman
barman_home = /var/lib/barman
configuration_files_directory = /etc/barman.d
log_file = /var/log/barman/barman.log
log_level = INFO
;compression = gzip
```
/etc/barman.d/main.conf
```
[192.168.100.10]
description =  "PostgreSQL Database"
conninfo = host=192.168.100.10 user=barman dbname=postgres
streaming_conninfo = host=192.168.100.10 user=streaming_barman dbname=postgres
backup_method = postgres
streaming_archiver = on
slot_name = barman
path_prefix = /usr/pgsql-11/bin
```

### Проверка репликации

Создаем на master-сервере БД и в ней таблицу:

```sql
vagrant ssh master
sudo -u postgres psql
=# CREATE DATABASE test_db ENCODING='UTF8';
=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test_db   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
(4 rows)
=# \c test_db
test_db=# CREATE TABLE names (John varchar(80));
test_db=#\dt
         List of relations
 Schema | Name  | Type  |  Owner
--------+-------+-------+----------
 public | names | table | postgres
(1 row)
```
Проверяем реплицированную БД на standby-сервере:

```sql
vagrant ssh slave
sudo -u postgres psql
=# \l
                                 List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test_db   | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
(4 rows)
postgres=# \c test_db
You are now connected to database "test_db" as user "postgres".
test_db=# \dt
         List of relations
 Schema | Name  | Type  |  Owner
--------+-------+-------+----------
 public | names | table | postgres
(1 row)
```
### Проверка резервного копирования

Проверим на barman-сервере, правильно ли собраны файлы WAL в целевом каталоге:
```bash
vagrant ssh backup
sudo barman switch-wal --force --archive --archive-timeout 60 192.168.100.10
The WAL file 000000010000000000000003 has been closed on server '192.168.100.10'
Waiting for the WAL file 000000010000000000000003 from server '192.168.100.10' (max: 60 seconds)
Processing xlog segments from streaming for 192.168.100.10
        000000010000000000000003
```
Затем сделаем проверку barman:
```bash
sudo barman check 192.168.100.10
Server 192.168.100.10:
        PostgreSQL: OK
        is_superuser: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: OK (no last_backup_maximum_age provided)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: OK (have 0 backups, expected at least 0)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK
```
Выполним бэкап:
```bash
sudo barman backup 192.168.100.10
Starting backup using postgres method for server 192.168.100.10 in /var/lib/barman/192.168.100.10/base/20190824T211132
Backup start at LSN: 0/5000140 (000000010000000000000005, 00000140)
Starting backup copy via pg_basebackup for 20190824T211132
Copy done (time: 2 seconds)
Finalising the backup.
This is the first backup for server 192.168.100.10
WAL segments preceding the current backup have been found:
        000000010000000000000003 from server 192.168.100.10 has been removed
        000000010000000000000004 from server 192.168.100.10 has been removed
Backup size: 110.0 MiB
Backup end at LSN: 0/7000000 (000000010000000000000006, 00000000)
Backup completed (start time: 2019-08-24 21:11:32.302259, elapsed time: 2 seconds)
Processing xlog segments from streaming for 192.168.100.10
        000000010000000000000005
```
Проверим каталог с резервными копиями master-сервера:
```bash
[root@backup errors]# ls -l /var/lib/barman/192.168.100.10/
total 0
drwxr-xr-x. 3 barman barman 29 Aug 24 21:11 base
drwxr-xr-x. 2 barman barman  6 Aug 24 21:06 errors
drwxr-xr-x. 2 barman barman  6 Aug 24 21:06 incoming
drwxr-xr-x. 2 barman barman 46 Aug 24 21:14 streaming
drwxr-xr-x. 3 barman barman 45 Aug 24 21:12 wals
```

