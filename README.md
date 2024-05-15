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
1. Подготовка скрипта<br/>
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
    # Для обработки "живого" лога необходимо в условии поменять -le start_time на -ge end_time. Это означает, что
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
2. Проверка работы скрипта<br/>
   Обрабатываемый диапазон выводится для демонстрации работы. Однако, данные выводятся на основании<br/>
   содержимого всего access-лога. Причины указаны в описании скрипта (88-93 строки).
```shell
dem@calculate ~/vagrant/10_DZ $ ./parse_log.sh access-4560-644067.log 
The processed range:
|Wed May 15 18:13:51 MSK 2024| - |Wed May 15 19:13:51 MSK 2024|

######## IP ########

Num_req IP's
---------------------------
     45 93.158.167.130
     39 109.236.252.130
     37 212.57.117.19
     33 188.43.241.106
     31 87.250.233.68
     24 62.75.198.172
     22 148.251.223.21
     20 185.6.8.9
     17 217.118.66.161
     16 95.165.18.146
     12 95.108.181.93
     12 62.210.252.196
     12 185.142.236.35
     12 162.243.13.195
      8 163.179.32.118
      7 87.250.233.75
      6 167.99.14.153
      6 165.22.19.102
      5 71.6.199.23
      5 5.45.203.12

######## Resources ########

Num_req Resources
-----------------------------------------
    157 /
    120 /wp-login.php
     57 /xmlrpc.php
     26 /robots.txt
     12 /favicon.ico
     11 400
      9 /wp-includes/js/wp-embed.min.js?ver=5.0.4
      7 /wp-admin/admin-post.php?page=301bulkoptions
      7 /1
      6 /wp-content/uploads/2016/10/robo5.jpg
      6 /wp-content/uploads/2016/10/robo4.jpg
      6 /wp-content/uploads/2016/10/robo3.jpg
      6 /wp-content/uploads/2016/10/robo2.jpg
      6 /wp-content/uploads/2016/10/robo1.jpg
      6 /wp-content/uploads/2016/10/aoc-1.jpg
      6 /wp-content/uploads/2016/10/agreed.jpg
      6 /wp-content/themes/llorix-one-lite/style.css?ver=1.0.0
      6 /wp-admin/admin-ajax.php?page=301bulkoptions
      5 /wp-includes/js/wp-emoji-release.min.js?ver=5.0.4
      5 /wp-includes/css/dist/block-library/style.min.css?ver=5.0.4

######## Server Errors ########

Num_err Server_errors
---------------------------
      3 500

######## Response Codes ########

Num_rsp Response codes
---------------------------
    498 200
     95 301
      1 304
      7 400
      1 403
     51 404
      1 405
      2 499
      3 500

```
3. Подготовка crontab-файла<br/>
```shell
calculate dem # crontab -e
...
calculate dem # crontab -l
SHELL=/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin

*/2 * * * * parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonkmv@yandex.ru
```
Скрипт предварительно перенесён в /bin. Для быстрой проверки работоспособности отправка осуществлялась<br/> 
каждую вторую минуту часа. Для соответствия заданию (отправка каждый час) строка должна иметь вид:<br/>
```shell
0 * * * * parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonkmv@yandex.ru
```
4. Проверка работоспособности CRON<br/>
```shell
calculate dem # cat /var/log/messages
...
May 15 14:12:00 calculate crond[2841]: (root) RELOAD (/var/spool/cron/crontabs/root)
May 15 14:12:00 calculate crond[4655]: pam_ldap: missing file "/etc/ldap.conf"
May 15 14:12:00 calculate crond[4655]: pam_unix(crond:session): session opened for user root(uid=0) by root(uid=0)
May 15 14:12:00 calculate CROND[4657]: (root) CMD (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonkmv@>
May 15 14:12:15 calculate mutt[4659]: DIGEST-MD5 common mech free
May 15 14:12:15 calculate CROND[4655]: (root) CMDEND (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonk>
May 15 14:12:15 calculate CROND[4655]: pam_unix(crond:session): session closed for user root
May 15 14:14:00 calculate crond[14768]: pam_ldap: missing file "/etc/ldap.conf"
May 15 14:14:00 calculate crond[14768]: pam_unix(crond:session): session opened for user root(uid=0) by root(uid=0)
May 15 14:14:00 calculate CROND[14771]: (root) CMD (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonkmv>
May 15 14:14:10 calculate mutt[14773]: DIGEST-MD5 common mech free
May 15 14:14:10 calculate CROND[14768]: (root) CMDEND (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimon>
May 15 14:14:10 calculate CROND[14768]: pam_unix(crond:session): session closed for user root
May 15 14:16:00 calculate crond[25044]: pam_ldap: missing file "/etc/ldap.conf"
May 15 14:16:00 calculate crond[25044]: pam_unix(crond:session): session opened for user root(uid=0) by root(uid=0)
May 15 14:16:00 calculate CROND[25047]: (root) CMD (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonkmv>
May 15 14:16:10 calculate mutt[25049]: DIGEST-MD5 common mech free
May 15 14:16:10 calculate CROND[25044]: (root) CMDEND (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimon>
May 15 14:16:10 calculate CROND[25044]: pam_unix(crond:session): session closed for user root
May 15 14:18:00 calculate crond[2748]: pam_ldap: missing file "/etc/ldap.conf"
May 15 14:18:00 calculate crond[2748]: pam_ldap: missing file "/etc/ldap.conf"
May 15 14:18:00 calculate crond[2748]: pam_unix(crond:session): session opened for user root(uid=0) by root(uid=0)
May 15 14:18:00 calculate CROND[2751]: (root) CMD (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonkmv@>
May 15 14:18:09 calculate mutt[2753]: DIGEST-MD5 common mech free
May 15 14:18:09 calculate CROND[2748]: (root) CMDEND (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonk>
May 15 14:18:09 calculate CROND[2748]: pam_unix(crond:session): session closed for user root
May 15 14:19:17 calculate crontab[13448]: (root) BEGIN EDIT (root)
May 15 14:20:00 calculate crond[13452]: pam_ldap: missing file "/etc/ldap.conf"
May 15 14:20:00 calculate crond[13452]: pam_unix(crond:session): session opened for user root(uid=0) by root(uid=0)
May 15 14:20:00 calculate CROND[13455]: (root) CMD (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimonkmv>
May 15 14:20:10 calculate mutt[13457]: DIGEST-MD5 common mech free
May 15 14:20:10 calculate CROND[13452]: (root) CMDEND (parse_log /home/dem/vagrant/10_DZ/access-4560-644067.log | mutt -s report_"`date`" -- dimon>
May 15 14:20:10 calculate CROND[13452]: pam_unix(crond:session): session closed for user root
...
```
![изображение](https://github.com/DemBeshtau/10_DZ/assets/149678567/7ca3490e-8be1-47e6-bf64-3553295b1768)
![изображение](https://github.com/DemBeshtau/10_DZ/assets/149678567/f4df9374-93bc-415b-a4b2-bc55912f52c9)

