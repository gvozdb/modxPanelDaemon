#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Не забыть поставить PIP:
# apt-get install pip
или
# apt-get install python3-pip

И модули "pyyaml" и "pymysql":
# pip install pyyaml
# pip install pymysql
или
# pip3 install pyyaml
# pip3 install pymysql
"""

__author__ = "Pavel Gvozdb"
__created_date__ = "05.10.15"
__version__ = "1.5.6-beta"

import os
import sys
import glob
import socket
import argparse
import logging, logging.handlers
import time
import subprocess
import importlib
import lib
import yaml
import pymysql
import re

from lib.classic_daemon import Daemon


######### >> Параметры
current_path = os.path.dirname( sys.argv[0] ) # директория размещения скрипта
if not current_path:
    current_path = '.'

config_f = open( current_path +"/config.yaml" )
config = yaml.load( config_f, yaml.Loader )

SECRET = config['secret']
MYSQL_ROOT = config['mysql_root']
HOST_DOMAIN = config['host_domain']
#TASK_DIR = current_path +"/task/"
PORT = config['socket_port']
TIMEOUT = config['socket_timeout']
TIMER = config['timer']
TMP_DIR = current_path +"/tmp/"
PROCESS_NAME = "modxpanel"
PID_FILE = TMP_DIR +".modxpanel-daemon.pid"
STATUS_FILE = TMP_DIR +".modxpanel-daemon.status"
LOG_FILE = current_path +"/log/access.log"
ERROR_FILE = current_path +"/log/error.log"
ACTION_FILE = current_path +"/log/action.log"
SCRIPT_SH_DIR = current_path +"/script/sh/"
SCRIPT_PHP_DIR = current_path +"/script/php/"
POST_FIELD = "__task__="

config_f.close()
######### <<

######### >> Настраиваем логирование
logging.basicConfig(level=logging.INFO)
log_formatter = logging.Formatter("%(levelname)-8s [%(asctime)s]  %(message)s")
log_error_formatter = logging.Formatter("%(filename)s[LINE:%(lineno)d]# %(levelname)-8s [%(asctime)s]  %(message)s")
logging.ACTION = logging.INFO + 1
logging.addLevelName(logging.ACTION, 'ACTION')

log_info = logging.getLogger('__info__')
log_info.propagate = False
log_info_stream = logging.FileHandler(os.path.abspath(LOG_FILE), 'a')
log_info_stream.setLevel(logging.INFO)
log_info_stream.setFormatter(log_formatter)
log_info.addHandler(log_info_stream)

log_error = logging.getLogger('__error__')
log_error.propagate = False
log_error_stream = logging.FileHandler(os.path.abspath(ERROR_FILE), 'a')
log_error_stream.setLevel(logging.INFO)
log_error_stream.setFormatter(log_error_formatter)
log_error.addHandler(log_error_stream)

log_action = logging.getLogger('__action__')
log_action.propagate = False
log_action_stream = logging.FileHandler(os.path.abspath(ACTION_FILE), 'a')
log_action_stream.setLevel(logging.INFO)
log_action_stream.setFormatter(log_formatter)
log_action.addHandler(log_action_stream)
######### <<

try:
    sock = socket.socket()
    sock.bind( ("", PORT) )
    sock.listen(4)
except BaseException as e:
    """print(e)"""


class Daemonizer(Daemon):

    def __init__(self, pidfile):
        super().__init__(pidfile, "modxpanel_daemon")
        self.is_iterrupted = False

    def main_processing_unit(self):
        """
        Функция запускающаяся каждые TIMER секунд
        """

        ######### >> создаём сокет, слушаем и выполняем задания
        try:
            while 1: # работаем постоянно
                conn, addr = sock.accept()
                conn.settimeout(3.0)
                log_action.log(logging.ACTION, "Новое подключение к сокету с адреса "+ addr[0] )
                try:
                    task_yaml = socket_parse(conn, addr)

                    if (task_yaml != 'Empty'):
                        tasks = yaml.load(task_yaml)

                        if( tasks != None and isinstance(tasks, dict) and tasks['data'] and tasks['task'] ):
                            data = tasks['data']
                            task = tasks['task']

                            for i in range(len(task)):
                                for action in task[i].keys():
                                    #log_error.error( action )
                                    set_status(action) # ставим статус, чтобы даймона не закрыли, пока он трудится

                                    if data['secret'] == SECRET:
                                        try:
                                            if not 'wait' in data:
                                                socket_send(conn, data="Done. OK")
                                        except:
                                            """ соединение закрыто """

                                        #### >> выполняем задание
                                        if action == 'addplace':
                                            status = add_place( task=task[i][action], data=data )

                                        elif action == 'addmodx':
                                            status = add_modx( task=task[i][action], data=data )

                                        elif action == 'updatemodx':
                                            status = update_modx( task=task[i][action], data=data )

                                        elif action == 'password':
                                            status = password( task=task[i][action], data=data )

                                        elif action == 'packages':
                                            status = packages( username=task[i][action]['user'] )

                                        elif action == 'remove':
                                            status = remove_site( username=task[i][action]['user'], data=data )

                                        elif action == 'php':
                                            status = php_version( task=task[i][action], data=data )

                                        elif action == 'demo' or action == 'test' or action == 'lala':
                                            log_error.error( action )
                                            log_error.error( task[i] )
                                            status = demo( task[i][action] )
                                        #### <<
                                    else:
                                        socket_send(conn, data="ERROR: Secret key bad")

                                    if 'wait' in data:
                                        socket_send(conn, data="Done. OK")
                        else:
                            socket_send(conn, data="ERROR: Task incorrect")

                        del tasks
                except:
                    log_error.error( "500. Внутренняя ошибка сокета." )
                finally:
                    conn.close() # при любой ошибке сокет закроем корректно
                    set_status() # чистим статус
        finally:
            sock.close()
            set_status() # чистим статус
        ######### <<

    def run(self):
        """
        Method that call main method and
        sleeps time spicified in settings
        """
        while not self.is_iterrupted:
            self.main_processing_unit()
            time.sleep(TIMER)


######### >> Работа с сокетами
def socket_data(conn, data=""):
    """
    Получает данные из сокета отправленные либо обычным образом через коннект к сокету, либо через POST
    """
    if( data.find(POST_FIELD) != -1 ):
        start = data.find(POST_FIELD) + len(POST_FIELD)
        data = data[start:]
    return data

def socket_send(conn, status="200 OK", type="text/plain; charset=utf-8", data=""):
    """
    Отсылка браузеру статуса 200
    """
    data = data.encode("utf-8")
    conn.send(b"HTTP/1.1 "+ status.encode("utf-8") +b"\r\n")
    conn.send(b"Server: simplehttp\r\n")
    conn.send(b"Connection: close\r\n")
    conn.send(b"Content-Type: "+ type.encode("utf-8") +b"\r\n")
    conn.send(b"Content-Length: "+ bytes(len(data)) +b"\r\n")
    conn.send(b"\r\n")
    conn.send(data)

def socket_parse(conn, addr):
    """
    Обработка соединения с сокетом
    """
    if( addr[0] != '127.0.0.1' and addr[0] != 'localhost' ):
        log_error.error("Кто-то пронюхивает порт даймона")
        socket_send(conn, data="Ты не тот, кого я жду")
        return "Empty"

    data = b""
    while not data: # ждём первую строку
        tmp = conn.recv(16384)
        if not tmp: # пустой объект - сокет закрыли
            break
        else:
            data += tmp

    if not data: return # данные не пришли - не обрабатываем

    return socket_data(conn, data=data.decode("utf-8"))
######### <<


def check_process(part_of_name):
    """
    Сhecking the existence of the process
    :return: True and process count if process loaded else False
    """
    command = "pgrep "+ part_of_name[1:-1] +" | wc -l"
    #command = "pgrep -c "+ part_of_name[1:-1]
    response = subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
    response = int(response.decode())
    if response == 0:
        return False
    else:
        return True, response


######### >> Проверка статуса
def get_status():
    status_f = open( STATUS_FILE, 'r')
    status = status_f.read()
    status_f.close()
    return status
######### <<

######### >> Запись статуса
def set_status( status="" ):
    r = False
    status_f = open( STATUS_FILE, 'w')
    r = status_f.write(status)
    status_f.close()
    return r
######### <<


######### >> Тестовая функция для проверки работы даймона
def demo( data={} ):
    status = False
    log_error.error( "Тестовый запуск." )
    log_error.error( data )
    time.sleep(4)
    return status
######### <<

######### >> Добавление места под сайт
def add_place( data={}, task={} ):
    status = False
    try_ = True
    try_i = 1

    if not 'user' in task or not 'domain' in task or not 'table' in data:
        log_error.error( "Ошибка при добавлении пустого сайта. Переданные параметры:\n\ttask: "+ str(task) +"\n\tdata: "+ str(data) )
    else:
        while try_ != False and try_i <= 5:
            command = "/bin/bash "+ os.path.abspath(SCRIPT_SH_DIR) +"/addplace.sh -p \""+ MYSQL_ROOT +"\" -h "+ (task['host'] if task['host'] else HOST_DOMAIN) +" -u "+ task['user'] +" "+ ("-d "+ task['domain'] if task['domain'] else "") +" "+ ("-a "+ task['php'] if task['php'] else "")
            #log_error.error(command)

            r = subprocess.Popen(command, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True)
            r = str( r.communicate()[0] )
            #log_error.error( r.replace('\n','\n\t') )

            if r.find('ERROR') != -1:
                status = False
                log_error.error( "Ошибка при добавлении пустого сайта "+ task['domain'] +": /var/www/"+ task['user'] +"/\n\tПопытка: "+ str(try_i) +"\n\tРезультат выполнения: "+ r.replace('\n','\n\t') )
                time.sleep(10)
                try_i += 1
                continue

            elif r.find('Done!') != -1:
                status = True
                log_action.log(logging.ACTION, "Добавили пустой сайт "+ task['domain'] +": /var/www/"+ task['user'] +"/" )

                if r.find('## INFO >>') != -1:
                    #info_str = r[r.find('## INFO >>'):r.find('## << INFO')]
                    item = {}
                    item['site'] = r[r.find('##SITE##'):r.find('##SITE_END##')].replace('##SITE##','')
                    item['sftp_port'] = r[r.find('##SFTP_PORT##'):r.find('##SFTP_PORT_END##')].replace('##SFTP_PORT##','')
                    item['sftp_user'] = r[r.find('##SFTP_USER##'):r.find('##SFTP_USER_END##')].replace('##SFTP_USER##','')
                    item['sftp_pass'] = r[r.find('##SFTP_PASS##'):r.find('##SFTP_PASS_END##')].replace('##SFTP_PASS##','')
                    item['mysql_site'] = r[r.find('##MYSQL_SITE##'):r.find('##MYSQL_SITE_END##')].replace('##MYSQL_SITE##','')
                    item['mysql_db'] = r[r.find('##MYSQL_DB##'):r.find('##MYSQL_DB_END##')].replace('##MYSQL_DB##','')
                    item['mysql_user'] = r[r.find('##MYSQL_USER##'):r.find('##MYSQL_USER_END##')].replace('##MYSQL_USER##','')
                    item['mysql_pass'] = r[r.find('##MYSQL_PASS##'):r.find('##MYSQL_PASS_END##')].replace('##MYSQL_PASS##','')
                    item['path'] = r[r.find('##PATH##'):r.find('##PATH_END##')].replace('##PATH##','')

                    dbconn = pymysql.connect(user='root', passwd=MYSQL_ROOT, db=data['dbname'])
                    dbcur = dbconn.cursor()
                    sql = "\
                        UPDATE `"+ data['table'] +"`\
                            SET\
                                status='run',\
                                site=%s,\
                                sftp_port=%s,\
                                sftp_user=%s,\
                                sftp_pass=%s,\
                                mysql_site=%s,\
                                mysql_db=%s,\
                                mysql_user=%s,\
                                mysql_pass=%s,\
                                path=%s\
                            WHERE\
                                id=%s\
                    "
                    dbcur.execute(sql, (item['site'], item['sftp_port'], item['sftp_user'], item['sftp_pass'], item['mysql_site'], item['mysql_db'], item['mysql_user'], item['mysql_pass'], item['path'], data['id']))
                    dbcur.close()
                    dbconn.close()

            try_ = False

    return status
######### <<

######### >> Добавление MODX сайта
def add_modx( data={}, task={} ):
    status = False
    try_ = True
    try_i = 1

    if not 'user' in task or not 'domain' in task or not 'table' in data:
        log_error.error( "Ошибка при добавлении MODX сайта. Переданные параметры:\n\ttask: "+ str(task) +"\n\tdata: "+ str(data) )
    else:
        while try_ != False and try_i <= 5:
            command = "/bin/bash "+ os.path.abspath(SCRIPT_SH_DIR) +"/addmodx.sh -p \""+ MYSQL_ROOT +"\" -h "+ (task['host'] if task['host'] else HOST_DOMAIN) +" -u "+ task['user'] +" "+ ("-d "+ task['domain'] if task['domain'] else "") +" "+ ("-v "+ task['version'] if task['version'] else "") +" "+ ("-a "+ task['php'] if task['php'] else "") +" "+ ("-c "+ task['modxconnectors'] if task['modxconnectors'] else "") +" "+ ("-m "+ task['modxmanager'] if task['modxmanager'] else "") +" "+ ("-t "+ task['modxtableprefix'] if task['modxtableprefix'] else "")
            #log_error.error(command)

            r = subprocess.Popen( command, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True )
            r = str( r.communicate()[0] )
            #log_error.error( r.replace('\n','\n\t') )

            if r.find('ERROR') != -1 and r.find('zero') != -1:
                log_error.error( "Ошибка при добавлении MODX сайта "+ task['domain'] +": /var/www/"+ task['user'] +"/\n\tНекорректно скачался modx.zip.\n\tПопытка: "+ str(try_i) )
                time.sleep(10)
                try_i += 1
                continue

            elif r.find('ERROR') != -1:
                status = False
                log_error.error( "Ошибка при добавлении MODX сайта "+ task['domain'] +": /var/www/"+ task['user'] +"/\n\tПопытка: "+ str(try_i) +"\n\tРезультат выполнения: "+ r.replace('\n','\n\t') )
                time.sleep(10)
                try_i += 1
                continue

            elif r.find('Done!') != -1:
                status = True
                log_action.log(logging.ACTION, "Добавили MODX сайт "+ task['domain'] + (" версии "+ task['version'] if task['version'] else "") +": /var/www/"+ task['user'] +"/" )

                if r.find('## INFO >>') != -1:
                    #info_str = r[r.find('## INFO >>'):r.find('## << INFO')]
                    item = {}
                    item['site'] = r[r.find('##SITE##'):r.find('##SITE_END##')].replace('##SITE##','')
                    item['sftp_port'] = r[r.find('##SFTP_PORT##'):r.find('##SFTP_PORT_END##')].replace('##SFTP_PORT##','')
                    item['sftp_user'] = r[r.find('##SFTP_USER##'):r.find('##SFTP_USER_END##')].replace('##SFTP_USER##','')
                    item['sftp_pass'] = r[r.find('##SFTP_PASS##'):r.find('##SFTP_PASS_END##')].replace('##SFTP_PASS##','')
                    item['mysql_site'] = r[r.find('##MYSQL_SITE##'):r.find('##MYSQL_SITE_END##')].replace('##MYSQL_SITE##','')
                    item['mysql_table_prefix'] = r[r.find('##MYSQL_TABLE_PREFIX##'):r.find('##MYSQL_TABLE_PREFIX_END##')].replace('##MYSQL_TABLE_PREFIX##','')
                    item['mysql_db'] = r[r.find('##MYSQL_DB##'):r.find('##MYSQL_DB_END##')].replace('##MYSQL_DB##','')
                    item['mysql_user'] = r[r.find('##MYSQL_USER##'):r.find('##MYSQL_USER_END##')].replace('##MYSQL_USER##','')
                    item['mysql_pass'] = r[r.find('##MYSQL_PASS##'):r.find('##MYSQL_PASS_END##')].replace('##MYSQL_PASS##','')
                    item['connectors_site'] = r[r.find('##CONNECTORS_SITE##'):r.find('##CONNECTORS_SITE_END##')].replace('##CONNECTORS_SITE##','')
                    item['manager_site'] = r[r.find('##MANAGER_SITE##'):r.find('##MANAGER_SITE_END##')].replace('##MANAGER_SITE##','')
                    item['manager_user'] = r[r.find('##MANAGER_USER##'):r.find('##MANAGER_USER_END##')].replace('##MANAGER_USER##','')
                    item['manager_pass'] = r[r.find('##MANAGER_PASS##'):r.find('##MANAGER_PASS_END##')].replace('##MANAGER_PASS##','')
                    item['path'] = r[r.find('##PATH##'):r.find('##PATH_END##')].replace('##PATH##','')

                    dbconn = pymysql.connect(user='root', passwd=MYSQL_ROOT, db=data['dbname'])
                    dbcur = dbconn.cursor()
                    sql = "\
                        UPDATE `"+ data['table'] +"`\
                            SET\
                                status='run',\
                                site=%s,\
                                sftp_port=%s,\
                                sftp_user=%s,\
                                sftp_pass=%s,\
                                mysql_site=%s,\
                                mysql_table_prefix=%s,\
                                mysql_db=%s,\
                                mysql_user=%s,\
                                mysql_pass=%s,\
                                connectors_site=%s,\
                                manager_site=%s,\
                                manager_user=%s,\
                                manager_pass=%s,\
                                path=%s\
                            WHERE\
                                id=%s\
                    "
                    dbcur.execute(sql, (item['site'], item['sftp_port'], item['sftp_user'], item['sftp_pass'], item['mysql_site'], item['mysql_table_prefix'], item['mysql_db'], item['mysql_user'], item['mysql_pass'], item['connectors_site'], item['manager_site'], item['manager_user'], item['manager_pass'], item['path'], data['id']))
                    dbcur.close()
                    dbconn.close()

            try_ = False

    return status
######### <<

######### >> Обновление версии MODX
def update_modx( data={}, task={} ):
    status = False
    #log_error.error(data)

    if not 'user' in task or not 'version' in task or not 'table' in data:
        log_error.error( "Ошибка при обновлении MODX. Переданные параметры:\n\ttask: "+ str(task) +"\n\tdata: "+ str(data) )
    else:
        command = "/bin/bash "+ os.path.abspath(SCRIPT_SH_DIR) +"/updatemodx.sh "+ task['user'] +" "+ task['version']

        r = subprocess.Popen( command, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True )
        r = str( r.communicate()[0] )

        if r.find('ERROR') != -1:
            log_error.error( "Ошибка при обновлении MODX"+ (" до версии "+ task['version'] if task['version'] else "") +": /var/www/"+ task['user'] +"/\n\tРезультат выполнения: "+ r.replace('\n','\n\t') )

        elif r.find('Done!') != -1:
            status = True
            log_action.log(logging.ACTION, "Обновили MODX"+ (" до версии "+ task['version'] if task['version'] else "") +" для: /var/www/"+ task['user'] +"/" )

            dbconn = pymysql.connect(user='root', passwd=MYSQL_ROOT, db=data['dbname'])
            dbcur = dbconn.cursor()
            sql = "\
                UPDATE `"+ data['table'] +"`\
                    SET\
                        status='run',\
                        version=%s\
                    WHERE\
                        id=%s\
            "
            dbcur.execute(sql, (task['version'], data['id']))
            dbcur.close()
            dbconn.close()

    return status
######### <<

######### >> Смена пароля админа MODX
def password(data={}, task={}):
    status = False
    #log_error.error(data)

    if not 'user' in task or not 'password' in task or not 'base_path' in task or not 'id' in data or not 'table' in data:
        log_error.error( "Ошибка при смене пароля MODX. Переданные параметры:\n\ttask: "+ str(task) +"\n\tdata: "+ str(data) )
    else:
        command = "php "+ os.path.abspath(SCRIPT_PHP_DIR) +"/password.php "+ task['base_path'] +" "+ task['user'] +" "+ task['password']

        r = subprocess.Popen( command, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True )
        r = str( r.communicate()[0] )

        if r.find('ERROR') != -1:
            log_error.error( "Ошибка при смене пароля MODX: "+ task['base_path'] +"/\n\tРезультат выполнения: "+ r.replace('\n','\n\t') )

        elif r.find('Done!') != -1:
            status = True
            log_action.log(logging.ACTION, "Сменили пароль на MODX для: "+ task['base_path'])

            dbconn = pymysql.connect(user='root', passwd=MYSQL_ROOT, db=data['dbname'])
            dbcur = dbconn.cursor()
            sql = "\
                UPDATE `"+ data['table'] +"`\
                    SET\
                        status='run',\
                        manager_pass=%s\
                    WHERE\
                        id=%s\
            "
            dbcur.execute(sql, (task['password'], data['id']))
            dbcur.close()
            dbconn.close()

    return status
######### <<

######### >> Установка/обновление пакетов для MODX
def packages( username="" ):
    status = False
    #command = "sudo -u "+ username +" php "+ os.path.abspath(SCRIPT_PHP_DIR) +"/packages.php /var/www/"+ username +"/www/"
    command = "php "+ os.path.abspath(SCRIPT_PHP_DIR) +"/packages.php /var/www/"+ username +"/www/"

    r = subprocess.Popen( command, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True )
    r = str( r.communicate()[0] )

    if r.find('ERROR') != -1:
        status = False
        log_error.error( "Ошибка при установке пакетов: /var/www/"+ username +"/\n\tРезультат выполнения: "+ r.replace('\n','\n\t') )

    elif r.find('Done!') != -1:
        status = True
        log_action.log(logging.ACTION, "Установили пакеты для: /var/www/"+ username +"/")

        subprocess.Popen( os.path.abspath(SCRIPT_SH_DIR) +"/chmod.sh "+ username, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True ).communicate()

    elif r.find('Already exists') != -1:
        status = True

    return status
######### <<

######### >> Удаление сайта, каталога, юзера, базы и т.д.
def remove_site( username="", data={} ):
    status = False
    command = "/bin/bash "+ os.path.abspath(SCRIPT_SH_DIR) +"/remove.sh \""+ MYSQL_ROOT +"\" "+ username

    r = subprocess.Popen( command, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True )
    r = str( r.communicate()[0] )

    if r.find('ERROR') != -1:
        status = False
        log_error.error( "Ошибка при удалении сайта, юзера, БД, каталога: /var/www/"+ username +"/\n\tРезультат выполнения: "+ r.replace('\n','\n\t') )

    elif r.find('Done!') != -1:
        status = True
        log_action.log(logging.ACTION, "Удалили сайт, юзера, БД, каталог: /var/www/"+ username +"/")

        dbconn = pymysql.connect(user='root', passwd=MYSQL_ROOT, db=data['dbname'])
        dbcur = dbconn.cursor()
        sql = "\
            UPDATE `"+ data['table'] +"`\
                SET\
                    status='deleted'\
                WHERE\
                    id=%s\
        "
        dbcur.execute(sql, (data['id']))
        dbcur.close()
        dbconn.close()

    return status
######### <<

######### >> Смена версии PHP
def php_version( data={}, task={} ):
    status = False

    if not 'user' in task or not 'php' in task or not 'table' in data:
        log_error.error( "Ошибка при смене версии PHP. Переданные параметры:\n\ttask: "+ str(task) +"\n\tdata: "+ str(data) )
    else:
        command = "/bin/bash "+ os.path.abspath(SCRIPT_SH_DIR) +"/php.sh "+ task['user'] +" "+ task['php']

        r = subprocess.Popen( command, stderr=subprocess.PIPE, stdout=subprocess.PIPE, shell=True, universal_newlines=True )
        r = str( r.communicate()[0] )

        if r.find('ERROR') != -1:
            status = False
            log_error.error( "Ошибка при смене версии PHP: /var/www/"+ task['user'] +"/\n\tРезультат выполнения: "+ r.replace('\n','\n\t') )

        elif r.find('Done!') != -1:
            status = True
            log_action.log(logging.ACTION, "Сменили версию PHP на "+ task['php'] +": /var/www/"+ task['user'] +"/")

            dbconn = pymysql.connect(user='root', passwd=MYSQL_ROOT, db=data['dbname'])
            dbcur = dbconn.cursor()
            sql = "\
                UPDATE `"+ data['table'] +"`\
                    SET\
                        status='run',\
                        php=%s\
                    WHERE\
                        id=%s\
            "
            dbcur.execute(sql, (task['php'], data['id']))
            dbcur.close()
            dbconn.close()

    return status
######### <<


if __name__ == "__main__":
    if not check_process(PROCESS_NAME):
        if os.path.exists(os.path.abspath(PID_FILE)):
            os.remove(os.path.abspath(PID_FILE))

    daemon = Daemonizer(os.path.abspath(PID_FILE))
    parser = argparse.ArgumentParser(description='"MODXPanel" - a small daemon for run commands added site place and MODX sites.')
    subparsers = parser.add_subparsers(help="List of available command", dest="command")
    subparsers.add_parser("start", help="Start daemon")
    subparsers.add_parser("stop", help="Stop daemon")
    subparsers.add_parser("restart", help="Restart daemon")
    subparsers.add_parser("purge", help="Purge hardlinks, database and restart if needed")
    subparsers.add_parser("statusreset", help="Resets the status so that you can stop the daemon")
    subparsers.add_parser("addplace", help="Добавить место под сайт")
    subparsers.add_parser("addmodx", help="Добавить сайт на MODX")
    subparsers.add_parser("updatemodx", help="Обновить версию MODX")
    subparsers.add_parser("packages", help="Установить пакеты в MODX")
    subparsers.add_parser("remove", help="Удалить сайт, юзера, БД и любые другие следы существования сайта")
    subparsers.add_parser("php", help="Сменить версию PHP для сайта")
    parser.add_argument("-V", action="version", version="%(prog)s " + __version__)
    parser.add_argument('--user', '--name', '-u', '-n', action="store")
    parser.add_argument('--domain', '--site', '-d', '-s', action="store")
    parser.add_argument('--version', '--modx', '-v', '-m', action="store")
    parser.add_argument('--status', action="store")
    args = parser.parse_args()


    if len(sys.argv) == 1:
        parser.print_help()

    elif args.command == "addplace" or args.command == "addmodx" or args.command == "updatemodx" or args.command == "packages" or args.command == "remove" or args.command == "php":
        status = False
        if status:
            print( "Done!" )
        else:
            print( "Error!" )

    elif args.command == "start":
        log_info.info("Daemon has been started")
        set_status() # сбрасываем статус работы
        daemon.start()

    elif args.command == "stop" or args.command == "restart":
        if not get_status():
            if args.command == "stop":
                log_info.info("Daemon has been stoped")
                daemon.stop()

            """elif args.command == "restart":
                log_info.info("Daemon has been restarted")
                daemon.restart()"""

            set_status() # сбрасываем статус работы
        else:
            print( "Error! Can't stop. I work" )

    elif args.command == "purge":
        # Purge if daemon offline else purge and restart
        if check_process(PROCESS_NAME):
            if os.path.exists(PID_FILE):
                daemon.stop()
                while check_process(PROCESS_NAME)[1] > 1:
                    time.sleep(0.3)
                daemon.start()

    else:
        if args.command == "statusreset" or args.status == "reset":
            #print( args )
            set_status() # сбрасываем статус работы
