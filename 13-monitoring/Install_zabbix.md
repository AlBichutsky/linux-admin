##############################
# Установка Zabbix
##############################

# Отключим SELinux
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config

# Отключим временно файервол, после установки его включим
systemctl stop firewalld

# Синхронизируем время и установим часовой пояс Москвы
# ntpdate 1.ru.pool.ntp.org
mv /etc/localtime /etc/localtime.bak
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime

# Назначаем полное доменное имя (FQDN) клиентскому хосту "srv-zabbix"
hostnamectl set-hostname srv-zabbix

# Установим rpm с Zabbix-репозиторием 
rpm -i https://repo.zabbix.com/zabbix/4.2/rhel/7/x86_64/zabbix-release-4.2-1.el7.noarch.rpm

# Обновим репозиторий YUM-пакетов
yum makecache

# Установим пакеты zabbix
sudo yum install -y zabbix-server-mysql zabbix-web-mysql zabbix-agent

# Установим mariadb
yum install -y mariadb mariadb-server

# Запустим сервис mariadb
systemctl start mariadb
systemctl enable mariadb

# Установим пароль root с названием "password"
/usr/bin/mysql_secure_installation

# Запустится скрипт, с запросами на то или иное действие.
# Skip root password for root
# Мы еще не устанавливали пароль для root, поэтому при запуске скрипта и запросе пароля для root, нажмаем Enter.
# Install new password for root: password

# Do remove an anonymous user
# На вопрос о том, удалить ли анонимного пользователя, отвечаем "нет".

# Do not disallow remote connections.
# Не запрещаем коннект к нашему северу с удаленных серверов (либо запрещаем).

# Do remove a test database.
# Тестовую БД не удаляем.

# Do reload the privileges
# Перегрузим привилегии для их активации (либо нет).

# Подключаемся к БД с паролем "password"
mysql -u root -p

# Создаем БД zabbix командой:
create database zabbix character set utf8 collate utf8_bin;

# Назначим все привилегии на базу zabbix пользователю zabbix и установим для него пароль 'zabbix'
grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbix';

# Выйдем из консоли MariaDB
quit

# Создадим таблицы в новой БД zabbix
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | sudo mysql -uzabbix -Dzabbix -p
# Ввводим пароль 'zabbix' и нажмем 'Enter'

#################################
# Настройка Zabbix
#################################

# Редактируем конфигурационный файл:
vi /etc/zabbix/zabbix_server.conf

# После строчки 
# DBUser=zabbix
# добавим новую строчку - пароль пользователя БД
# DBPassword=zabbix

# Редактируем конфигурационный файл:
vi /etc/httpd/conf.d/zabbix.conf

# Раскоментируем строчку и добавим наш часовой пояс вместо Europe/Riga 
# Посмотреть можно: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
php_value date.timezone Europe/Moscow

# Перезапустим службы zabbix
systemctl restart zabbix-server zabbix-agent httpd

# Переходим в Zabbix
http://192.168.33.14/zabbix/