#!/bin/bash

if [ $1 = "--help" ]
then
    echo 'ИМЯ'
    echo '  parse_log - скрипт осуществляет обработку access-лога'
    echo -e '\nСИНТАКСИС'
    echo '  ./parse_log.sh [ПАРАМЕТР1]'
    echo  -e '\nОПИСАНИЕ'
    echo '  Получает на вход путь к access-логу. Далее обрабатывается access-лог:'
    echo '  - выводится список IP-адресов с указанием количества запросов с момента последнего'
    echo '    запуска скрипта;'
    echo '  - выводится список запрашиваемых URL с указанием количества запросов с момента'
    echo '    последнего запуска скрипта;'
    echo '  - выводятся ошибки веб-сервера/приложения с момента последнего запуска скрипта;'
    echo '  - выводится список всех кодов HTTP-ответов с указанием их количества с момента'
    echo '    последнего запуска скрипта;'
    echo '  - предусмотрена возможность предотвращения одновременного запуска нескольких'
    echo '    копий скрипта до его завершения. Cоздаётся lock-файл в /tmp/parse_log.lock.'
    echo -e '\n --help - выводит справку'
    echo -e '\n ПАРАМЕТР задаётся в формате ЛОГ-ФАЙЛ'
    echo -e '\nПРИМЕРЫ'
    echo '  ./parse_log.sh access-4560-644067.log'
    exit 0
fi 

if [ $# != 1 ]
then
    echo 'Invalid numbers of parameters. Enter path to logfile or --help in parameter'
    exit 1
fi

LOCK=/tmp/parse_log.lock
if [ -f $LOCK ]
then
    echo -e "The script is already running.\n"
    exit 2
fi
touch $LOCK

LANG=en_us_88591

function get_date {
    echo "$1" | awk '{print $4}' | sed -e 's/\[//; s/\// /g; s/:/ /1'
}

function date_to_epoch {
    echo $(date -d "$1" +'%s')
}

function epoch_to_date {
    echo $(date -d "@$1")
}

IFS=$'\012'
filename=$1
start_time=$(date_to_epoch `date`)
((end_time=start_time-3600))

for line in $(cat $filename) 
do
    if [[ $(date_to_epoch $(get_date $line)) -le start_time ]]
    then
        ip+=$(echo $line | awk '{print $1}')$'\n'
        resource+=$(echo $line | awk '{print $7}')$'\n'
        response=$(echo $line | awk '{print $9}')
        if [[ ($response =~ ^([0-9]+[0-9]+[0-9])$) && ($response -ge 500) ]]
        then 
            err+=$response$'\n'
        fi
        if [[ ($response =~ ^([0-9]+[0-9]+[0-9])$) ]]
        then 
            code_resp+=$response$'\n'
        fi
    fi
done

echo -e "The processed range:"
echo -e "|$(epoch_to_date $end_time)| - |$(epoch_to_date $start_time)|\n"
echo -e "######## IP ########\n"
echo -e "Num_req IP's"
echo -e "---------------------------"
echo -e "$ip\n" | sort | uniq -c | sort -r | head -n 20
echo -e "\n######## Resources ########\n"
echo -e "Num_req Resources"
echo -e "-----------------------------------------"
echo -e "$resource\n" | sort | uniq -c | sort -r | head -n 20
echo -e "\n######## Server Errors ########\n"
echo -e "Num_err Server_errors"
echo -e "---------------------------"
echo -en "$err" | sort | uniq -c
echo -e "\n######## Response Codes ########\n"
echo -e "Num_rsp Response codes"
echo -e "---------------------------"
echo -en "$code_resp" | sort | uniq -c

rm -f $LOCK
exit 0

