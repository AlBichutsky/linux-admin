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
Инициализируем БД команндой
```bash
/usr/pgsql-11/bin/postgresql-11-setup initdb
```
4.
Настриваем аутентификацию:  
- разрешаем slave коннектиться к master под пользователем `repluser`.
- разрешаем barman коннектиться к master под любым пользователем (у нас будет пользователь barman для управления).
- разрешаем барману коннектиться к мастеру под пользователем `barman_streaming` для выполнения стимингового бэкапа. 

Добавляем в `/var/lib/pgsql/11/data/pg_hba.conf`

```
host    replication     repluser           127.0.0.1/32       md5
host    replication     repluser           192.168.100.10/32  md5
host    replication     repuser            192.168.100.11/32  md5
host    all             all                192.168.100.12/32  trust
host    replication     barman_streaming   192.168.100.12/32  md5
```
5. 
Создаем  пользователя `repluser` для репликации на slave (пример создания через консоль)
```bash
# su postgres
$ psql
# CREATE USER repluser WITH REPLICATION LOGIN CONNECTION LIMIT 2 ENCRYPTED PASSWORD 'ReplPass';
# \q
# exit
```
Создаем пользователя `barman` для управления резервным копированием (интерактивно):
```bash
psql postgres -c "CREATE USER barman WITH SUPERUSER PASSWORD 'BarmanPass';"
```
Создаем пользователя `barman_streaming` для стримингового бэкапирования (интерактивно):

```bash
psql postgres -c "CREATE USER streaming_barman WITH REPLICATION PASSWORD 'StrBarmanPass';"
```
6.
Забэкапим postgresql.conf перед редактированием

```bash
cd /var/lib/pgsql/11/data/
cp postgresql.conf postgresql.conf.back
```
Очистим содержимое `postgresql.conf` и добавим конфиг:
```
listen_addresses = '*'
hot_standby = on
wal_level = replica
wal_log_hints = on
max_replication_slots = 4
max_wal_senders = 6
wal_keep_segments = 64
archive_mode = on
# выполнять архивирование WAL на удаленный сервер по ssh
# archive_command = 'barman-wal-archive 192.168.100.12 192.168.100.10 %p'
# выполнять архивирование WAL в локальную папку archive
archive_command = 'cp -i %p /var/lib/pgsql/11/data/archive/%f'
```
7. 
Создаем каталог `archive` в папке `data` для хранения архивов WAL и сделаем владельцем `postgres`. Важно: предпочтительнее и надежнее сразу настроить копирование архивов WAL на сервер barman, а не в локальную папку. В этом случае необходимо настроить авторизацию по ssh ключам между сервером master и barman.
```bash
mkdir /var/lib/pgsql/11/data/archive
chown postgres:postgres /var/lib/pgsql/11/data/archive
```
8. 
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
Запустим службу `postgresql`:
```bash
systemctl start postgresql-11.service
```
На это настройка slave закончена.

## Проверка репликации

На master:
```bash
su - postgres
psql
=# select * from pg_stat_replication;
```
На slave:
```bash
su - postgres
psql
=# select * from pg_stat_wal_receiver;
```
Создаем тестовую БД на master:
```bash
sudo -u postgres psql
=# CREATE DATABASE repltest ENCODING='UTF8';
```
После этого проверяем на slave нашу реплицированную БД:
```bash
sudo -u postgres psql
=# \l
```
Получить сведения о клиентах потоковой репликации на master:
```bash
SELECT *,pg_wal_lsn_diff(s.sent_lsn,s.replay_lsn) AS byte_lag FROM pg_stat_replication s;
```

## Настройка barman
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
Архивация WAL должна проходить без ошибок. Соответственно, если master отправляет архивы на удаленный сервер barman, должна быть настроена авторизация по ssh-ключам. В нашем примере, архивы складываются в локальную папку 'archive`, которая копируется вместе с `data`

Проверить отправку архивов WAL на сервер barman можно командой:
```bash
barman-wal-archive --test 192.168.100.12 192.168.100.10 DUMMY
```
