## Инструкция по установке FreeIPA Server

**Ссылки:**

[https://sevo44.ru/freeipa-ustanovka-na-centos-7/](https://sevo44.ru/freeipa-ustanovka-na-centos-7/)

[https://www.certdepot.net/rhel7-configure-freeipa-server/](https://www.certdepot.net/rhel7-configure-freeipa-server/)

[https://github.com/freeipa/ansible-freeipa](https://github.com/freeipa/ansible-freeipa)


Отключаем SELinux:

    sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config

Отключаем firewalld

    systemctl stop firewalld
    systemctl disable firewalld

Либо разрешает необходимые порты:

    firewall-cmd --permanent --add-service={ntp,http,https,ldap,ldaps,kerberos,kpasswd,dns}
    firewall-cmd --reload

Синхронизируем время:

    ntpdate 1.ru.pool.ntp.org

Если необходимо поменять временные зоны, то делаем следующее:

    mv /etc/localtime /etc/localtime.bak
    ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime

Указываем имя сервера.
Должно быть указано полное доменное имя (FQDN). В противном случае, Kerberos не будет работать! 

    hostnamectl set-hostname ipaserver.test.lab

Добавляем в файле /etc/hosts в конце строчку 

    192.168.33.10 ipaserver.test.lab ipaserver    

Устанавливаем epel-репозиторий, затем обновляем систему и перегружаемся:    

    yum install -y epel-release
    yum update -y
    reboot

Устаналиваем freeipa server с dns
    yum -y install ipa-server ipa-server-dns bind bind-dyndb-ldap

Запускаем настройку сервера ipa:

    ipa-server-install 

или запускаем настройку сервера с автоответом:

    ipa-server-install -a password --hostname=ipaserver.test.lab -r TEST.LAB -p password -n test.lab -U

Проверить и перезапустить сервер ipa

    ipactl status
    ipactl restart

Если все правильно установилась, то сервер будет доступен по адресу:

    https://ipaserver.test.lab/ipa/ui/


