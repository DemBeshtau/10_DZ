# Скрипты на Bash #
&ensp;&ensp;Написать скрипт для CRON, который раз в час будет формировать письмо и отправлять на заданную почту.<br/>
&ensp;&ensp;Необходимая информация в письме:<br/>
- Список IP адресов с (наибольшим количеством запросов) с указанием количества запросов с момента последнего<br/>
  запуска скрипта;<br/>
- Список запрашиваемых URL (с наибольшим количеством запросов) с указанием количества запросов с момента<br/>
  последнего запуска скрипта;<br/>
- Ошибки веб-сервера/приложения с момента последнего запуска скрипта;<br/>
- Список всех кодов HTTP ответа с указанием их количества с момента последнего запуска скрипта;<br/>
- Скрипт должен предотвращать одновременный запуск нескольких копий до его завершения;<br/>
- В письме должен быть прописан обрабатываемый временной диапазон.<br/>
### Ход решения ###
1. Подготовка скрипта:<br/>
```shell
#!/bin/bash

# Данный блок предназначен для вывода информации о назначении и работе скрипта
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

# Проверка наличия необходимого количества аргументов скрипта
if [ $# != 1 ]
then
    echo 'Invalid numbers of parameters. Enter path to logfile or --help in parameter'
    exit 1
fi

# Реализация возможности запуска только одной копии данного скрипта до его завершения
LOCK=/tmp/parse_log.lock
if [ -f $LOCK ]
then
    echo -e "The script is already running.\n"
    exit 2
fi
touch $LOCK

# Переключение локали в английскую, для работы выводом команды date с английским названием месяцев
LANG=en_us_88591

# Функция получения даты из строки access-лога
function get_date {
    echo "$1" | awk '{print $4}' | sed -e 's/\[//; s/\// /g; s/:/ /1'
}

# Функция преобразования даты в формат эпохи Unix
function date_to_epoch {
    echo $(date -d "$1" +'%s')
}

# Функция преобразования даты в формате эпохи Unix в стандартный формат
function epoch_to_date {
    echo $(date -d "@$1")
}

# Переустаналиваем значение разделителя для построчного чтения содержимого access-лога в переменную line
IFS=$'\012'
filename=$1

# Сохраняем время начала работы скрипта в формате эпохи Unix
start_time=$(date_to_epoch `date`)
# Вычисление времени начала обработки access-лога. По условию составляет 1 час, так как скрипт запускается раз в час
((end_time=start_time-3600))

# Главный цикл программы, в котором в переменную line построчно считывается содержимое access-лога
for line in $(cat $filename) 
do
    # Условие, в соответствии с которым задаётся дата-временной диапазон анализа access-лога
    # В данном случае, для того, чтобы был проанализирован весь лог (для наглядности), задано условие -le start_time,
    # означающее, что обрабатываться будут только те строки, значение времени в которых, меньше или равно времени старта
    # скрипта.
    # Для обработки "живого" лога необходимо в условии поменять -le start_time на -ge end_time. Это будет означать, что
    # будут обработаны строки со временем больше времени начала обработки лога (по условию 1 час).
    if [[ $(date_to_epoch $(get_date $line)) -le start_time ]]
    then
        # Собираем IP адреса из access-лога
        ip+=$(echo $line | awk '{print $1}')$'\n'
        # Собираем URL из access-лога
        resource+=$(echo $line | awk '{print $7}')$'\n'
        # Собираем коды HTTP ответов
        response=$(echo $line | awk '{print $9}')
        # С помощью данного условия собираем коды 500-х ответов
        if [[ ($response =~ ^([0-9]+[0-9]+[0-9])$) && ($response -ge 500) ]]
        then 
            err+=$response$'\n'
        fi
        # С помощью данного условия собираем коды всех ответов (понадобилось сделать из-за того, что в 9-м поле не всегда бывают ответы)
        if [[ ($response =~ ^([0-9]+[0-9]+[0-9])$) ]]
        then 
            code_resp+=$response$'\n'
        fi
    fi
done

# Вывод дата-временного диапазона обработки acess-лога
echo -e "The processed range:"
echo -e "|$(epoch_to_date $end_time)| - |$(epoch_to_date $start_time)|\n"
# Вывод 20-ти IP адресов с наибольшим количеством запросов
echo -e "######## IP ########\n"
echo -e "Num_req IP's"
echo -e "---------------------------"
echo -e "$ip\n" | sort | uniq -c | sort -r | head -n 20
# Вывод 20-ти URL с наибольшим количеством запросов
echo -e "\n######## Resources ########\n"
echo -e "Num_req Resources"
echo -e "-----------------------------------------"
echo -e "$resource\n" | sort | uniq -c | sort -r | head -n 20
echo -e "\n######## Server Errors ########\n"
# Вывод ошибок сервера
echo -e "Num_err Server_errors"
echo -e "---------------------------"
echo -en "$err" | sort | uniq -c
echo -e "\n######## Response Codes ########\n"
# Вывод кодов HTTP ответов с указанием их количества
echo -e "Num_rsp Response codes"
echo -e "---------------------------"
echo -en "$code_resp" | sort | uniq -c
# Удаление лок-файла перед завершением работы скрипта
rm -f $LOCK
exit 0
```
