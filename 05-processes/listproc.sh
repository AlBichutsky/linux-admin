#!/usr/bin/env bash

# Скрипт listproc.sh анализирует виртуальную файловую систему /proc и выводит на экран список текущих запущенных процессов в виде колонок:
# PID (id процесса)   STAT(текущий статус процесса)  COMMAND (имя команды c аргументами) 

# Выводим названия колонок:
echo "PID   STAT            COMMAND"    

# Поскольку имена подкаталогов /proc изменяются на лету в связи со сменой pid-ов, скрипт может попытаться обработать 
# устаревшие неактуальные данные. Убираем сообщения об ошибках при выводе не найденных записей. 
exec 2>/dev/null

# В каталоге /proc находим имена всех подкаталогов $num_pid, начинающихся с цифр 1..9
# Каждый подкаталог - это id процесса (pid)
for num_pid in `find /proc -maxdepth 1 -name "[1-9]*" -type d ` 

do

# Собираем данные путем парсинга файлов внутри найденных подкаталогов /proc/$num_pid/

# Получение записей Pid из /proc/$num_pid/status (PID) 
number_pid=$(cat /$num_pid/status | awk '/^Pid/{print $2}')  

# Получение записей State из /proc/$num_pid/status (STAT)       
state_proc=$(cat /$num_pid/status | awk '/^State/{print $2,$3}')        

# Получение записей Name из /proc/$num_pid/status (COMMAND - короткое имя процесса)
short_name_proc=$(cat /$num_pid/status | awk '/^Name/{print $2}')

# Получение записей из /proc/$num_pid/cmdline (COMMAND - имя команды с аргументами)
# Т.к. аргументов команды может быть много, ограничим вывод 170 символами
command_proc=$(cat /$num_pid/cmdline | cut -c 1-170)         

# Имя команды с аргументами есть не всех процессов, например она есть у systemd, chrome и т.д. 
# Ее можно получить из файла /proc/$num_pid/cmdline. Если запись в файле присутствует (т.е встречаются символы), 
# то будет парситься имя команды с аргументами, если отсутствует - то короткое имя (Name) из файла /proc/$num_pid/status.
# Короткое имя процесса поместим в квадратные скобки, как в утилите ps (по факту - это потоки ядра, запланированные в качестве процессов).
# Задаем условие для обработки данных: 
command_proc_show=$(if grep -q "[a-z,A-Z,0-9]" $num_pid/cmdline; then echo $command_proc; else echo "[$short_name_proc]"; fi)

# Выводим информацию на экран:
echo "$number_pid     $state_proc    $command_proc_show" 

done
