#!/bin/bash

############## >> Функция удаления юзера с сайтом. Используется, если что-то пойдёт не так

function site_remove {
    echo "ERROR: Delete everything that was added."
    echo "$SCRIPTPATH/remove.sh $ROOTPASS $USERNAME"

    $SCRIPTPATH/remove.sh $ROOTPASS $USERNAME
}

##############

MAXLENGTH=16
TIMEZONE='Europe/Moscow'
MYSQLPASS=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12`
SFTPPASS=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12`
PASSWORD=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12`
CONFIGKEY=`< /dev/urandom tr -dc _a-z-0-9 | head -c4`
DOMAIN=''
PHPVERSION=''

############## >> Обработка переданных параметров

NO_ARGS=0

if [ $# -eq "$NO_ARGS" ]
then
    echo "ERROR: Incorrect usage"
    exit 0
fi


while getopts "p:h:u:d:v:a:" Option
do
    case $Option in
        p) ROOTPASS=$OPTARG;;
        h) HOST=$OPTARG;;
        u) USERNAME=$OPTARG;;
        d) DOMAIN=$OPTARG;;
        a) PHPVERSION=$OPTARG;;
        *) echo "ERROR: Invalid key";;
    esac
done
shift $(($OPTIND - 1))

############## <<

##############

if [ -z "$SCRIPTPATH" ]; then
    SCRIPTPATH=`dirname $0`
fi

############## MySQL root password

echo -e "$ROOTPASS" | grep "*"
if [ "$?" -ne 1 -o -z "$ROOTPASS" ]; then
    echo "ERROR: Enter MySQL root password"
    exit 0
fi

##############

echo -e "$HOST" | grep "[^A-Za-z0-9.\-]"
if [ "$?" -ne 1 -o -z "$HOST" ]; then
    echo "ERROR: Host domain bad symbols"
    exit 0
fi

##############

echo -e "$USERNAME" | grep "[^A-Za-z0-9]"
if [ "$?" -ne 1 -o -z "$USERNAME" ]; then
    echo "ERROR: Username bad symbols"
    exit 0
fi
if [ "${#USERNAME}" -gt "$MAXLENGTH" ]; then
    echo "ERROR: Username length more $MAXLENGTH"
    exit 0
fi

##############

if [ -z "$DOMAIN" ]; then
    DOMAIN=""
else
    echo -e "$DOMAIN" | grep "[^A-Za-z0-9.\-]"
    if [ "$?" -ne 1 ]; then
        echo "ERROR: Domain bad symbols"
        exit 0
    fi
    $DOMAIN=`echo "$DOMAIN" | sed 's/\(^www.\)\(.*\)/\2/'` # вырезаем www.
fi

if [ -z "$DOMAIN" ]; then
    DOMAIN="$USERNAME.$HOST"
fi

############## Enter PHP version

if [ -z "$PHPVERSION" ]; then
    PHPVERSION="7.0"
else
    echo -e "$PHPVERSION" | grep "[^0-9.]"
    if [ "$?" -ne 1 ]; then
        echo "ERROR: PHP version bad symbols"
        exit 0
    fi
fi

##############

echo "Creating user and home directory..."

useradd $USERNAME -m -G sftp -s "/bin/bash" -d "/var/www/$USERNAME"
if [ "$?" -ne 0 ]; then
    echo "ERROR: Can't add user"
    exit 0
fi
echo $SFTPPASS > /var/www/$USERNAME/tmp
echo $SFTPPASS >> /var/www/$USERNAME/tmp
cat /var/www/$USERNAME/tmp | passwd $USERNAME
rm /var/www/$USERNAME/tmp

##############

mkdir /var/www/$USERNAME/www
mkdir /var/www/$USERNAME/tmp
chmod -R 755 /var/www/$USERNAME/
chown -R $USERNAME:$USERNAME /var/www/$USERNAME/
chown root:root /var/www/$USERNAME

echo "Creating vhost files"

echo "upstream backend-$USERNAME {server unix:/var/run/php-$USERNAME.sock;}
include /etc/nginx/conf.inc/domains/$USERNAME.conf;" > /etc/nginx/sites-available/$USERNAME.conf
ln -s /etc/nginx/sites-available/$USERNAME.conf /etc/nginx/sites-enabled/$USERNAME.conf

echo "listen 80;
listen 443 ssl; # default_server
listen [::]:443 ssl; # default_server

location /.well-known {
    root /var/www/html;
}

charset utf-8;
root /var/www/$USERNAME/www;
access_log /var/log/nginx/$USERNAME-access.log;
error_log /var/log/nginx/$USERNAME-error.log;
index index.php index.html;
rewrite_log on;

# HTTPS / Redirects
set \$redirect_https '0';
if (\$scheme = 'http') {
    set \$redirect_https '1';
}
if (\$request_uri ~ \"^/\.well-known\") {
    set \$redirect_https '0';
}
if (\$is_https = '0') {
    set \$redirect_https '0';
}
if (\$redirect_https = '1') {
    return 301 https://\$host\$request_uri;
}

# HTTPS / Include SSL
#include /etc/nginx/ssl/$DOMAIN.conf;
#add_header Strict-Transport-Security \"max-age=31536000\"; # исключим возврат на http
#add_header Content-Security-Policy \"img-src https: data:; upgrade-insecure-requests\"; ## ломаем картинки с http

#
if (\$request_uri ~* '^/index.php$') {
    return 301 /;
}

location ~* ^/(admin|adminka|manager|mngr|m|connectors|cnnctrs|connectors-[_A-Z-a-z-0-9]+|_build)/ {
    location ~ \.php$ {
        try_files \$uri =404;

        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass backend-$USERNAME;
    }
    break;
}

# Remove double slashes in url
location ~* .*//+.* {
    rewrite (.*)//+(.*) \$1/\$2 permanent;
}

# PHP handler
location ~ \.php$ {
    #try_files \$uri =404;
    try_files \$uri \$uri/ @rewrite;

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_pass backend-$USERNAME;

    #fastcgi_read_timeout 180;
}" > /var/www/$USERNAME/main.nginx
ln -s /var/www/$USERNAME/main.nginx /etc/nginx/conf.inc/main/$USERNAME.conf

echo "error_page 404 = @modx;
location @modx {
    rewrite ^/(.*)$ /index.php?q=\$1&\$args last;
}

# Hide modx /core/ directory
location ~* ^/core/ {
    return 404;
}

# If file and folder not exists -->
location / {
    try_files \$uri \$uri/ @rewrite;
}

#
location ~ .*\.(jpg|jpeg|gif|png|ico|bmp|woff2|txt|xml|pdf|flv|swf)$ {
    add_header Cache-Control \"max-age=31536000, public\";
}
location ~ .*\.(css|js)$ {
    add_header Cache-Control \"max-age=31536000, public\";
}
location ~* ^.+\.(jpg|jpeg|gif|png|ico|bmp|woff2|txt|xml|pdf|flv|swf|css|js)$ {
    try_files           \$uri \$uri/ @rewrite;
    access_log          off;
    expires             10d;
    break;
}

# --> then redirect request to entry modx index.php
location @rewrite {
    #rewrite ^/((ru|en|kz)/assets/(.*))$ /assets/\$3 last;
    #rewrite ^/((ru|en|kz)/(.*)/?)$ /index.php?q=\$1 last;
    #rewrite (.*)/$ \$scheme://\$host\$1 permanent;
    rewrite ^/(.*)$ /index.php?q=\$1 last;
}" > /var/www/$USERNAME/access.nginx
ln -s /var/www/$USERNAME/access.nginx /etc/nginx/conf.inc/access/$USERNAME.conf

if [ -z "$DOMAIN" ]; then
    echo "" > /var/www/$USERNAME/domains.nginx
else
    echo "server {
    set \$is_https '0';
    set \$main_host '$DOMAIN';

    server_name
        $DOMAIN
        www.$DOMAIN
    ;

    if (\$host != \$main_host) {
        return 301 \$scheme://\$main_host\$request_uri;
    }

    # Include site config
    include /etc/nginx/conf.inc/main/$USERNAME.conf;
    include /etc/nginx/conf.inc/access/$USERNAME.conf;
}" > /var/www/$USERNAME/domains.nginx
fi
ln -s /var/www/$USERNAME/domains.nginx /etc/nginx/conf.inc/domains/$USERNAME.conf

##############

#echo "Creating phpX.X-fpm config"

PHPCONF="[$USERNAME]\n\
\n\
listen = /var/run/php-$USERNAME.sock\n\
listen.mode = 0666\n\
user = $USERNAME\n\
group = $USERNAME\n\
chdir = /var/www/$USERNAME\n\
\n\
php_admin_value[upload_tmp_dir] = /var/www/$USERNAME/tmp\n\
php_admin_value[soap.wsdl_cache_dir] = /var/www/$USERNAME/tmp\n\
php_admin_value[upload_max_filesize] = 100M\n\
php_admin_value[post_max_size] = 100M\n\
php_admin_value[open_basedir] = /var/www/$USERNAME/\n\
php_admin_value[cgi.fix_pathinfo] = 0\n\
php_admin_value[date.timezone] = $TIMEZONE\n\
php_admin_value[session.gc_probability] = 1\n\
php_admin_value[session.gc_divisor] = 100\n\
\n\
pm = dynamic\n\
pm.max_children = 10\n\
pm.start_servers = 2\n\
pm.min_spare_servers = 2\n\
pm.max_spare_servers = 4"
echo -e $PHPCONF > /etc/php/5.6/fpm/pool.d/$USERNAME.conf_
echo -e $PHPCONF > /etc/php/7.0/fpm/pool.d/$USERNAME.conf_
echo -e $PHPCONF > /etc/php/7.1/fpm/pool.d/$USERNAME.conf_
echo -e $PHPCONF > /etc/php/7.2/fpm/pool.d/$USERNAME.conf_
echo -e $PHPCONF > /etc/php/7.3/fpm/pool.d/$USERNAME.conf_

if [ "$PHPVERSION" == "5.6" ]; then
    mv -f /etc/php/5.6/fpm/pool.d/$USERNAME.conf_ /etc/php/5.6/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "7.0" ]; then
    mv -f /etc/php/7.0/fpm/pool.d/$USERNAME.conf_ /etc/php/7.0/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "7.1" ]; then
    mv -f /etc/php/7.1/fpm/pool.d/$USERNAME.conf_ /etc/php/7.1/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "7.2" ]; then
    mv -f /etc/php/7.2/fpm/pool.d/$USERNAME.conf_ /etc/php/7.2/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "7.3" ]; then
    mv -f /etc/php/7.3/fpm/pool.d/$USERNAME.conf_ /etc/php/7.3/fpm/pool.d/$USERNAME.conf
fi

#############

#echo "Creating dumper.yaml"

echo "enabled: true
database:
    type: mysql
    port: 3306
    host: localhost
    name: $USERNAME
    user: $USERNAME
    pass: $MYSQLPASS
exclude: {  }
" > /var/www/$USERNAME/dumper.yaml

##############

echo "Restarting php5.6-fpm"
service php5.6-fpm restart

echo "Restarting php7.0-fpm"
service php7.0-fpm restart

echo "Restarting php7.1-fpm"
service php7.1-fpm restart

echo "Restarting php7.2-fpm"
service php7.2-fpm restart

echo "Restarting php7.3-fpm"
service php7.3-fpm restart

echo "Reloading nginx"
service nginx reload

##############

echo "Creating database"

Q1="CREATE DATABASE IF NOT EXISTS $USERNAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
Q2="GRANT ALTER,DELETE,DROP,CREATE,INDEX,INSERT,SELECT,UPDATE,CREATE TEMPORARY TABLES,LOCK TABLES ON $USERNAME.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$MYSQLPASS';"
Q3="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}"

mysql -uroot --password=$ROOTPASS -e "$SQL"

##############

echo "#!/bin/bash

echo \"Set permissions for /var/www/$USERNAME/www...\";
echo \"CHOWN files...\";
chown -R $USERNAME:$USERNAME \"/var/www/$USERNAME/www\";
echo \"CHMOD directories...\";
find \"/var/www/$USERNAME/www\" -type d -exec chmod 0755 '{}' \;
echo \"CHMOD files...\";
find \"/var/www/$USERNAME/www\" -type f -exec chmod 0644 '{}' \;
" > /var/www/$USERNAME/chmod
chmod +x /var/www/$USERNAME/chmod

echo "Manager:
http://$DOMAIN/

SFTP:
User: $USERNAME
Pass: $SFTPPASS

MySQL:
User: $USERNAME
Pass: $MYSQLPASS" > /var/www/$USERNAME/pass.txt

#cat /var/www/$USERNAME/pass.txt

######### >> Выводим инфу для обработки в даймоне
echo "## INFO >>"

echo "##SITE##$DOMAIN##SITE_END##"

echo "##SFTP_PORT##22##SFTP_PORT_END##"
echo "##SFTP_USER##$USERNAME##SFTP_USER_END##"
echo "##SFTP_PASS##$SFTPPASS##SFTP_PASS_END##"

echo "##MYSQL_SITE##pma.$HOST##MYSQL_SITE_END##"
echo "##MYSQL_DB##$USERNAME##MYSQL_DB_END##"
echo "##MYSQL_USER##$USERNAME##MYSQL_USER_END##"
echo "##MYSQL_PASS##$MYSQLPASS##MYSQL_PASS_END##"

echo "##PATH##/var/www/$USERNAME/www/##PATH_END##"

echo "## << INFO"
######### << Выводим инфу для обработки в даймоне

echo "Done!"