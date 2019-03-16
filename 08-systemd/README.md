# 8. SystemD
## Задание

1. Написать сервис, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова. Файл и слово должны задаваться в /etc/sysconfig
2. Из epel установить spawn-fcgi и переписать init-скрипт на unit-файл. Имя сервиса должно так же называться.
3. Дополнить юнит-файл apache httpd возможностью запустить несколько инстансов сервера с разными конфигами.
4. *Скачать демо-версию Atlassian Jira и переписать основной скрипт запуска на unit-файл.

## Решение
Подготовлен [Vagrantfile](Vagrantfile) с реализацией п.1-4 и описанием.

Для тестирования настроен маппинг портов на localhost с гостевой машины на хостовую машину:

Apache httpd (п.3):
- 1-й инстанс: http://localhost:8008 / Управление юнитом: systemctl (stop/start/restart/status) httpd@first
- 2-й инстанс: http://localhost:8080 / Управление юнитом: systemctl (stop/start/restart/status) httpd@second

*Atlassian Jira (п.4):
- http://localhost:8081 / управление юнитом: systemctl (stop/start/restart/status) jira
 
