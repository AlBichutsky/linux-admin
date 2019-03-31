Убедиться что в конфигурационном файле нет ошибок
sudo bacula-dir -tc /etc/bacula/bacula-dir.conf

У юзера bacula пароль в бд bacula в postgres : cat /var/spool/bacula/.pgpass
NTUxZmM4NDg2MTNlYjdmZTU1Zjc2NzVjO

Проверить подключениек бакула:
psql -h 127.0.0.1 -U bacula


Настройки postgres: /var/lib/pgsql/data/pg_hba.conf

Пароль консоли bconsole: 
bconsole.conf NTQ5ZDNjNzU2MjAzYzZiMzlmNGQwODBkZ

Перед настройкой bacula-director необходимо указать используемую БД:
alternatives --config libbaccats.so

Конфиг etc/bacula/bacula-dir.conf

# указываем LabelFormat
# File Pool definition
Pool {
  Name = File
  Pool Type = Backup
  Recycle = yes                       # Bacula can automatically recycle Volumes
  AutoPrune = yes                     # Prune expired volumes
  Volume Retention = 365 days         # one year
  Maximum Volume Bytes = 50G          # Limit Volume size to something reasonable
  Maximum Volumes = 100               # Limit number of Volumes in Pool
  # Добавляем LabelFormat
  LabelFormat = "BackupVol"
}

# Для успешного подключения к БД:
# Generic catalog service
Catalog {
  Name = MyCatalog
  dbname = "bacula"; DB Address = "127.0.0.1"; dbuser = "bacula"; password = "NTUxZmM4NDg2MTNlYjdmZTU1Zjc2NzVjO"
}

Конфиг etc/bacula/bacula-sd.conf
Storage {                             # definition of myself
  Name = bacula-sd
  SDPort = 9103                  # Director's port
  WorkingDirectory = /var/spool/bacula
  Pid Directory = /var/run
  Maximum Concurrent Jobs = 20
  # Настройка Storage Daemon
  SDAddress = 192.168.111.10
}


Перезапуск служб:

systemctl restart bacula-sd
systemctl restart bacula-dir

sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config

# Отключим временно файервол, после установки включим обратно:
systemctl stop firewalld

# Синхронизируем время и установим часовой пояс Москвы:
# ntpdate 1.ru.pool.ntp.org
mv /etc/localtime /etc/localtime.bak
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime