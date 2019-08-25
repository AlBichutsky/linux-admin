## Настройка репликации postgresql: master, slave (hotstandby). 
## Настройка резервного копирования с помощью barman.

```
Серверы:  
master: 192.168.100.10
slave:  192.168.100.11
barman: 192.168.100.12
```

### Настройка master

1.
Устанавливаем пакеты `postgres 11`, а также `barman-cli` для возможности передачи архивов WAL на сервер barman:
```bash
yum install https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-centos11-11-2.noarch.rpm
yum install -y postgresql11-server postgresql11
yum install epel-release
yum install barman-cli
``` 

2.
Настриваем автозапуск службы `postgresql`
```bash
systemctl start postgresql 
systemctl enable postgresql 
```

3. 
Инициализируем БД командой
```bash
/usr/pgsql-11/bin/postgresql-11-setup initdb
```
4.
Настриваем клиентскую аутентификацию в `/var/lib/pgsql/11/data/pg_hba.conf`

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
5. 
Создаем  пользователя `repluser` для репликации на slave (пример создания через консоль)
```sql
# su postgres
$ psql
# CREATE USER repluser WITH REPLICATION LOGIN CONNECTION LIMIT 2 ENCRYPTED PASSWORD 'ReplPass';
# \q
# exit
```
Создаем пользователя `barman` для управления резервным копированием (интерактивно):
```sql
psql postgres -c "CREATE USER barman WITH SUPERUSER PASSWORD 'BarmanPass';"
```
Создаем пользователя `barman_streaming` для стримингового бэкапирования (интерактивно):

```sql
psql postgres -c "CREATE USER streaming_barman WITH REPLICATION PASSWORD 'StrBarmanPass';"
```
6.
Забэкапим postgresql.conf перед редактированием

```bash
cd /var/lib/pgsql/11/data/
cp postgresql.conf postgresql.conf.back
```
Очистим содержимое `postgresql.conf` и добавим наш конфиг (для реального сервера могут быть скорректированы):
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
7.
Если реплика отстаёт, то её можно потерять навсегда из-за того, что
сервер отротировал WAL. Для того, что бы этого не происходило
создали механизм обратной связи слейва с мастером - replication
slots.
Для создания используем команду: 
```sql
psql postgres -c "SELECT pg_create_physical_replication_slot('standby_slot');"
```
8. 
Создаем каталог `archive` в папке `data` для хранения архивов WAL и сделаем владельцем `postgres`. Важно: предпочтительнее и надежнее сразу настроить копирование архивов WAL на сервер barman, а не в локальную папку. В этом случае необходимо настроить авторизацию по ssh ключам между сервером master и barman.
```bash
mkdir /var/lib/pgsql/11/data/archive
chown postgres:postgres /var/lib/pgsql/11/data/archive
```
9. 
Перезапускаем master
```bash
systemctl restart postgresql-11.service
```
На этом настройка мастера закончена

### Настройка slave

1.
Устанавливаем пакеты `postgres 11`
```bash
yum install https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-centos11-11-2.noarch.rpm
yum install -y postgresql11-server postgresql11
yum install epel-release
``` 

2.
Настриваем автозапуск службы `postgresql`
```bash
systemctl start postgresql 
systemctl enable postgresql 
```

3. 
Инициализируем БД команндой
```bash
/usr/pgsql-11/bin/postgresql-11-setup initdb
```

4. 
Останавливаем сервер
```bash
systemctl stop postgresql-11.service
```
5. 
Забэкапим postgresql.conf перед редактированием

```bash
cd /var/lib/pgsql/11/data/
cp postgresql.conf /tmp/postgresql.conf.back
```
6.
Удалим содержимое папки `/lib/pgsql/11/data/` 
```bash
rm -Rf /var/lib/pgsql/11/data/* 
```
7.
Укажем пароли пользователя postgres `repluser`, чтобы не вводить их при выполнении команд (от имени локальной учетной записи `postgresql`)
```bash
su - postgres
cd ~
touch .pgpass
chmod 0600 .pgpass
echo "*:*:*:repluser:ReplPass" >> .pgpass
```
8.
Копируем содержимое каталога `/var/lib/pgsql/11/data/` с master на slave методом репликации c помощью утилиты `pg_basebackup`. В процессе также генерируется файл `recovery.conf`
```bash
pg_basebackup --username=repluser --pgdata=/var/lib/pgsql/11/data --host=192.168.100.10 --wal-method=stream --write-recovery-conf --progress
```

9.
Необходимо убедиться, что создался файл `recovery.conf`
```
cat /var/lib/pgsql/11/data/recovery.conf
standby_mode = 'on'
primary_conninfo = 'user=repluser passfile=''/var/lib/pgsql/.pgpass'' host=192.168.100.10 port=5432 sslmode=prefer sslcompression=0 krbsrvname=postgres target_session_attrs=any'
```
Добавляем в конец файла строчку
```
primary_slot_name = 'standby_slot'
```

10.
Запустим службу `postgresql`:
```bash
systemctl start postgresql-11.service
```
На это настройка slave закончена.

### Проверка репликации

На master:
```sql
su - postgres
psql
=# select * from pg_stat_replication;
```
На slave:
```sql
su - postgres
psql
=# select * from pg_stat_wal_receiver;
```
Создаем тестовую БД на master:
```sql
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
После этого проверяем на slave нашу реплицированную БД:
```sql
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
```
Получить сведения о клиентах потоковой репликации на master:
```sql
SELECT *,pg_wal_lsn_diff(s.sent_lsn,s.replay_lsn) AS byte_lag FROM pg_stat_replication s;
```

### Настройка резервного копирования barman
Подробнее: http://docs.pgbarman.org/release/2.9/

Будем настривать резервное копирование методом потоковой репликации

1.
Установим `barman` из `epel`
```
yum install `epel-release`
yum install `barman`
```

2. 
Укажем пароли пользователей postgres `barman`,`barman_streaming`  в `.pgpass`, чтобы не вводить их при выполнении команд (от имени локальной учетной записи `barman`)
```bash
cd /var/lib/barman/
touch .pgpass
chmod 0600 .pgpass
chown barman:barman .pgpass
echo "192.168.100.10:5432:*:barman:BarmanPass" >> .pgpass
echo "192.168.100.10:5432:*:streaming_barman:StrBarmanPass" >> .pgpass
```

3.
После проверяем подключение к серверу master от имени созданных пользователей:
```bash
su - barman -c "psql -c 'SELECT version()' -U barman -h 192.168.100.10 postgres"
su - barman -c "psql -U streaming_barman -h 192.168.100.10 \-c "IDENTIFY_SYSTEM" \replication=1"
```

4. 
Создадим файл `main.conf` в /etc/barman.d/
В нем будет конфигурация резервного копирования:
```bash
[192.168.100.10]
description =  "PostgreSQL Database"
conninfo = host=192.168.100.10 user=barman dbname=postgres
streaming_conninfo = host=192.168.100.10 user=streaming_barman dbname=postgres
backup_method = postgres
streaming_archiver = on
slot_name = barman
path_prefix = /usr/pgsql-11/bin
```

6) Забэкапим конфиг barman: /etc/barman.conf и пересоздадим:
```bash
cd /etc
mv barman.conf barman.conf.backup
touch barman.conf
chmod 0644 barman.conf
chown barman:barman barman.conf
vi barman.conf
```
Добавим содержимое:
```
[barman]
barman_user = barman
barman_home = /var/lib/barman
configuration_files_directory = /etc/barman.d
log_file = /var/log/barman/barman.log
log_level = INFO
;compression = gzip
```
7. 
Создадим слот репликации:
```bash
barman receive-wal --create-slot 192.168.100.10
```
8. 
Чтобы проверить, что непрерывное архивирование включено и правильно работает, необходимо проверить как сервер PostgreSQL, так и сервер резервного копирования. В частности, нам необходимо проверить, правильно ли собраны файлы WAL в целевом каталоге. Для этой цели и для облегчения проверки процесса используем команду:
```bash
barman switch-wal --force --archive 192.168.100.10
```
можно увеличить таймаут получения WAL до 60 сек:
```
barman switch-wal --force --archive --archive-timeout 60 192.168.100.10
```
Проверяем настройку бармена:
```bash
barman check 192.168.100.10
```
Запускаем бэкап:
```
barman backup 192.168.100.10
```
Бэкап будет создан в папке `/var/lib/barman/192.168.100.10/...`

Важно: если бэкап стартует, но не завершается, необходимо проверить на master опцию
архивирования WAL:
```
archive_command = 
```
Архивация WAL должна проходить без ошибок. Соответственно, если master отправляет архивы на удаленный сервер barman, должна быть настроена авторизация по ssh-ключам. В нашем примере, архивы складываются в локальную папку `archive`, которая копируется вместе с `data`

Проверить отправку архивов WAL на сервер barman можно командой:
```bash
barman-wal-archive --test 192.168.100.12 192.168.100.10 DUMMY
```
