#!/usr/bin/env bash

# ОПИСАНИЕ СКРИПТА:
# Скрипт watchdog_script.sh для мониторинга и перезапуска заданного сервиса c защитой от мультизапуска. 
# Интервал мониторинга = 30 сек.
# Скрипт определяет текущее кол-во PID-ов процесса, если значение =  0 (т.е был завершен), то выполняется перезапуск службы и логгирование события.   

LOCKFILE=/tmp/localfile			     # указать файл-блокировщик, создаваемый при запуске скрипта для защиты от мультизапуска	
SERVICE="postgresql"                	     # указать имя перезапускаемой службы, например postgresql (перезапуск будет осуществляться по команде service ... restart)
PROC="postgres"                              # указать имя отслеживаемого родительского процесса, например postgres (посмотреть можно через команду ps aux в колонке COMMAND)
LOG_FILE="/var/log/watchdog_$PROC.log" 	     # указать файл лога для записи информации о последнем перезапуске службы и текущем состоянии

check_process()			             # функция для мониторинга и перезапуска службы	
	{
  	
	  QUANTITY_PROC=$(pidof $PROC | wc -w) # кол-во PID-ов записывается в переменную QUANTITY_PROC

	# либо использовать конструкцию QUANTITY_PROC=$(ps auxw | grep -w $PROC | grep -v grep | wc -l)
        
	if [ $QUANTITY_PROC = 0 ] # если кол-во PID-ов = 0
        then
		echo -n > $LOG_FILE       # пересоздаем и очищаем файл лога
		service $SERVICE restart  # перезапускаем службу
		
		# вывод в лог
                echo "Служба $SERVICE была перезапущена на сервере $HOSTNAME $(date +"%d-%m-%y %T") $@" >> $LOG_FILE
	        echo "Кол-во запущенных процессов - $(pidof $PROC | wc -w) с PID:" >> $LOG_FILE
                echo $(ps aux | grep -w $PROC | grep -v grep | awk '{print $2}') >> $LOG_FILE  # вывести PID-ы, соответствующие заданному имени процесса

		# вывод на экран
		# echo "Служба $SERVICE была перезапущена на сервере $HOSTNAME $(date +"%d-%m-%y %T") $@"
                # echo "Текущее состояние службы: $(service $SERVICE status)"
                # echo "Кол-во запущенных процессов - $(pidof $PROC | wc -w) с PID:"
		# echo $(ps aux | grep -w $PROC | grep -v grep | awk '{print $2}')
        fi
	
	}

# Начало трапа для защиты от мультизапуска скрипта   

if ( set -o noclobber; echo "$$" > "$LOCKFILE") 2> /dev/null;
then
    trap 'rm -f "$LOCKFILE"; exit $?' INT TERM EXIT  # после отправки сигналов INT TERM EXIT, файл блокировки должен удалиться  
    while true
    do
	sleep 30 		# интервал проверки в сек.
	check_process		# добавляем функцию
   done
   rm -f "$LOCKFILE"
   trap - INT TERM EXIT
else
   echo "Не удалось перехватить файл блокировки: $LOCKFILE. Скрипт уже запущен."   # выводится предупреждение при попытке запуска 2-го экземпляра скрипта
   echo "Заблокировано PID-ом $(cat $LOCKFILE) ."
   exit
fi

