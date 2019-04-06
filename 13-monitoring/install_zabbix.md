# Установка Zabbix-server

Отключим SELinux:
````
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
````

Отключим временно файервол, после установки его включим
````
systemctl stop firewalld
````
Синхронизируем время и установим часовой пояс Москвы:
````
ntpdate 1.ru.pool.ntp.org
mv /etc/localtime /etc/localtime.bak
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime
````
Назначаем имя хосту:
````
hostnamectl set-hostname srv-zabbix
````
Установим репозиторий zabbix 4.2:
```` 
rpm -i https://repo.zabbix.com/zabbix/4.2/rhel/7/x86_64/zabbix-release-4.2-1.el7.noarch.rpm
````
Обновим репозиторий YUM-пакетов:
````
yum makecache
````
Установим пакеты zabbix:
````
sudo yum install -y zabbix-server-mysql zabbix-web-mysql zabbix-agent
````
Установим СУБД mariadb:
````
yum install -y mariadb mariadb-server
````
Запустим сервис mariadb:
````
systemctl start mariadb
systemctl enable mariadb
````
Установим пароль пользователя root для входа в mariadb с названием "password":
````
/usr/bin/mysql_secure_installation
````
Отвечаем на вопросы:
```
Skip root password for root
# Поскольку пароль не установлен, при запуске скрипта и запросе пароля для root, нажмаем Enter.
# Устанавливаем новый пароль:
Install new password for root: password
# На вопрос о том, удалить ли анонимного пользователя, отвечаем "нет".
Do remove an anonymous user
# Не запрещаем коннект к нашему северу с удаленных серверов:
Do not disallow remote connections. 
# Тестовую БД не удаляем:
Do remove a test database.
# Перегрузим привилегии для их активации:
Do reload the privileges
````
Подключаемся к БД с паролем "password"
````
mysql -u root -p
````
Создаем БД zabbix командой:
````
create database zabbix character set utf8 collate utf8_bin;
````
Назначим все привилегии на базу zabbix пользователю zabbix и установим для него пароль "zabbix":
````
grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbix';
````
Выйдем из консоли MariaDB:
````
quit
````
Создадим необходимые таблицы в новой БД zabbix:
````
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | sudo mysql -uzabbix -Dzabbix -p
````
Ввводим пароль 'zabbix' и нажмем 'Enter'.

Редактируем конфигурационный файл:
````
vi /etc/zabbix/zabbix_server.conf
````
После строчки 
````
DBUser=zabbix
````
добавим новую строчку - пароль пользователя БД:
````
DBPassword=zabbix
````
Редактируем конфигурационный файл:
````
vi /etc/httpd/conf.d/zabbix.conf
````
Раскоментируем строчку и добавим наш часовой пояс вместо Europe/Riga/

Посмотреть можно: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
````
php_value date.timezone Europe/Moscow
````
Перезапустим службы zabbix
````
systemctl restart zabbix-server zabbix-agent httpd
````
Переходим в консоль управления и мониторинга Zabbix:
````
http://srv-zabbix/zabbix/
````
Отвечаем при первичном запуске на вопросы по умолчанию.

# Установка Zabbix-client

Настроим имя хоста:
````
hostnamectl set-hostname host1
````
Отключим selinux и устновим правильный часовой пояс:
````
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
mv /etc/localtime /etc/localtime.bak
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime
````
Настроим файервол: открываем порт 10050 на клиенте для запросов сервера. 

Либо временно отключаем фаервол.
````
firewall-cmd --permanent --new-service=zabbix
firewall-cmd --permanent --service=zabbix --add-port=10050/tcp
firewall-cmd --permanent --service=zabbix --set-short="Zabbix Agent"
firewall-cmd --permanent --add-service=zabbix
firewall-cmd --reload
````
Устанавливаем zabbix-клиент:
````
rpm -i https://repo.zabbix.com/zabbix/4.2/rhel/7/x86_64/zabbix-release-4.2-1.el7.noarch.rpm
yum makecache
yum install -y zabbix-agent
systemctl enable zabbix-agent
systemctl start zabbix-agent
systemctl status zabbix-agent
````
Производим настройки в конфигурационном файле zabbix-client:
````
vi /etc/zabbix/zabbix_agentd.conf
````
Указываем имя/ip-адрес сервера Zabbix для активных и пассивных проверок.

Также указываем значение hostname, которое требуется для активных проверок.
````
Server=192.168.33.14
ServerActive=192.168.33.14
Hostname=host1
````