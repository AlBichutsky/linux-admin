# 11. LDAP
## Задание
1. Установить FreeIPA
2. Написать playbook для конфигурации клиента
3. *Настроить авторизацию по ssh-ключам

В git - результирующий playbook

## Инструкция по запуску тестового стенда (п.1, 2)

### 1. Установить FreeIPA

VM сервера с FreeIPA Server разворачивается с помощью [Vagrantfile](FreeIPA-server/Vagrantfile):
* имя: ipaserver.test.lab (домен test.lab);
* ip-адрес: 192.168.33.10
* DNS-сервер не установлен (хосты резолвятся через /etc/hosts);
* после установки консоль администрирования FreeIPA доступна с хостовой машины по адресу: https://192.168.33.10 или https://ipaserver.test.lab (если настроен резолвинг). Логин: admin, пароль: password.

VM клиента разорачивается с помощью [Vagrantfile](FreeIPA-client/Vagrantfile):
* имя: host1.test.lab;
* ip-адрес: 192.168.33.14
* хосты резолвятся через /etc/hosts.

### 2. Написать playbook для конфигурации клиента

Для установки клиента FreeIPA используется playbook [install-client.yml](FreeIPA-client/install-client.yml). 

Файлы взяты из официального репо проекта [https://github.com/freeipa/ansible-freeipa](https://github.com/freeipa/ansible-freeipa)
и лежат во [FreeIPA-client/](FreeIPA-client/).

Файл инвентори [hosts](FreeIPA-client/inventory/hosts), в котором перечислены хосты и параметры конфигурации:
````
[ipaclients]
host1.test.lab ansible_host=192.168.33.14 ansible_ssh_user=vagrant ansible_port=22 ansible_private_key_file=.vagrant/machines/default/virtualbox/private_key

[ipaservers]
ipaserver.test.lab ansible_host=192.168.33.10 ansible_ssh_user=vagrant ansible_port=22 ansible_private_key_file=.vagrant/machines/default/virtualbox/private_key

[ipaclients:vars]
#ipaclient_keytab=/tmp/krb5.keytab
ipaclient_domain=test.lab
ipaclient_realm=TEST.LAB
ipaadmin_principal=admin
ipaadmin_password=password
#ipaclient_use_otp=yes
ipaclient_force_join=yes
#ipaclient_kinit_attempts=3
ipaclient_mkhomedir=yes
ipaclient_allow_repair=yes
````
Для запуска playbook выполнить команду из каталога ../FreeIPA_client:

````
ansible-playbook -v -i inventory/hosts install-client.yml
````

После установки можно перейти в консоль адинистрироования https://192.168.33.10 и убедиться, что новый хост host1.test.lab был автоматически добавлен на сервере каталогов. 

Затем для проверки с host1.test.lab подключиться по ssh к ipaserver.test.lab от имени admin:

    ssh admin@192.168.33.10
