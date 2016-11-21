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

############## >> Обработка переданных параметров

NO_ARGS=0

if [ $# -eq "$NO_ARGS" ]
then
    echo "ERROR: Incorrect usage"
    exit 0
fi


while getopts "p:h:u:d:v:" Option
do
    case $Option in
        p) ROOTPASS=$OPTARG;;
        h) HOST=$OPTARG;;
        u) USERNAME=$OPTARG;;
        d) DOMAIN=$OPTARG;;
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

echo "upstream backend-$USERNAME {server unix:/var/run/php7.0-$USERNAME.sock;}

#server {
#    #server_name pma.$USERNAME.$HOST;
#    #root /var/www/pma/www;
#    #location / {
#    #    proxy_pass http://pma.$HOST/;
#    #}
#
#    # Remove double slashes in url
#    location ~* .*//+.* {
#        rewrite (.*)//+(.*) \$1/\$2 permanent;
#    }
#}
server {
    server_name www.$USERNAME.$HOST;
    return 301 \$scheme://$USERNAME.$HOST\$request_uri;
}
server {
    server_name $USERNAME.$HOST;

    # Include site config
    include /etc/nginx/conf.inc/main/$USERNAME.conf;
    include /etc/nginx/conf.inc/access/$USERNAME.conf;
}
include /etc/nginx/conf.inc/domains/$USERNAME.conf;" > /etc/nginx/sites-available/$USERNAME.conf
ln -s /etc/nginx/sites-available/$USERNAME.conf /etc/nginx/sites-enabled/$USERNAME.conf

echo "listen 80;
charset utf-8;
root /var/www/$USERNAME/www;
access_log /var/log/nginx/$USERNAME-access.log;
error_log /var/log/nginx/$USERNAME-error.log;
index index.php index.html;
rewrite_log on;

location ~* ^/(admin|adminka|manager|mngr|connectors|cnnctrs|connectors-[_A-Z-a-z-0-9]+|_build)/ {
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
    try_files \$uri =404;

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_pass backend-$USERNAME;
}" > /var/www/$USERNAME/main.nginx
ln -s /var/www/$USERNAME/main.nginx /etc/nginx/conf.inc/main/$USERNAME.conf

echo "# Hide modx /core/ directory
location ~* ^/core/ {
    return 404;
}

# If file and folder not exists -->
location / {
    try_files \$uri \$uri/ @rewrite;
}
# --> then redirect request to entry modx index.php
location @rewrite {
    rewrite ^/((ru|en|kz)/assets/(.*))$ /assets/\$3 last;
    rewrite ^/((ru|en|kz)/(.*)/?)$ /index.php?q=\$1 last;
    rewrite (.*)/$ \$scheme://\$host\$1 permanent;
    rewrite ^/(.*)$ /index.php?q=\$1 last;
}" > /var/www/$USERNAME/access.nginx
ln -s /var/www/$USERNAME/access.nginx /etc/nginx/conf.inc/access/$USERNAME.conf

if [ -z "$DOMAIN" ]; then
    echo "" > /var/www/$USERNAME/domains.nginx
else
    echo "server {
    server_name www.$DOMAIN;
    return 301 \$scheme://$DOMAIN\$request_uri;
}
server {
    server_name $DOMAIN;

    # Include site config
    include /etc/nginx/conf.inc/main/$USERNAME.conf;
    include /etc/nginx/conf.inc/access/$USERNAME.conf;
}" > /var/www/$USERNAME/domains.nginx
fi
ln -s /var/www/$USERNAME/domains.nginx /etc/nginx/conf.inc/domains/$USERNAME.conf

##############

#echo "Creating php7.0-fpm config"

echo "[$USERNAME]

listen = /var/run/php7.0-$USERNAME.sock
listen.mode = 0666
user = $USERNAME
group = $USERNAME
chdir = /var/www/$USERNAME

php_admin_value[upload_tmp_dir] = /var/www/$USERNAME/tmp
php_admin_value[soap.wsdl_cache_dir] = /var/www/$USERNAME/tmp
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[open_basedir] = /var/www/$USERNAME/
php_admin_value[cgi.fix_pathinfo] = 0
php_admin_value[date.timezone] = $TIMEZONE
php_admin_value[session.gc_probability] = 1
php_admin_value[session.gc_divisor] = 100

pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 4" > /etc/php/7.0/fpm/pool.d/$USERNAME.conf

##############

echo "Reloading nginx"
service nginx reload

echo "Restarting php7.0-fpm"
service php7.0-fpm restart

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