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
VERSION=''
PHPVERSION=''

############## >> Обработка переданных параметров

NO_ARGS=0

if [ $# -eq "$NO_ARGS" ]
then
    echo "ERROR: Incorrect usage"
    exit 0
fi


while getopts "p:h:u:d:v:c:m:t:a:" Option
do
    case $Option in
        p) ROOTPASS=$OPTARG;;
        h) HOST=$OPTARG;;
        u) USERNAME=$OPTARG;;
        d) DOMAIN=$OPTARG;;
        v) VERSION=$OPTARG;;
        c) CONNECTORSNAME=$OPTARG;;
        m) MANAGERNAME=$OPTARG;;
        t) TABLEPREFIX=$OPTARG;;
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
    DOMAIN=`echo "$DOMAIN" | sed 's/\(^www.\)\(.*\)/\2/'` # вырезаем www.
fi

if [ -z "$DOMAIN" ]; then
    DOMAIN="$USERNAME.$HOST"
fi

############## Enter pl version MODX Revo (example: "2.5.0-pl")

if [ -z "$VERSION" ]; then
    VERSION=""
else
    echo -e "$VERSION" | grep "[^A-Za-z0-9.\-]"
    if [ "$?" -ne 1 ]; then
        echo "ERROR: Version bad symbols"
        exit 0
    fi
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

############## Connectors dir name

if [ -z "$CONNECTORSNAME" ]; then
    CONNECTORSNAME=""
else
    echo -e "$CONNECTORSNAME" | grep "[^_a-zA-Z0-9\-]"
    if [ "$?" -ne 1 ]; then
        echo "ERROR: Connectors dir name is bad symbols"
        exit 0
    fi
fi

if [ -z "$CONNECTORSNAME" ]; then
    CONNECTORSNAME="connectors"
fi

############## Manager dir name

if [ -z "$MANAGERNAME" ]; then
    MANAGERNAME=""
else
    echo -e "$MANAGERNAME" | grep "[^_a-zA-Z0-9\-]"
    if [ "$?" -ne 1 ]; then
        echo "ERROR: Manager dir name is bad symbols"
        exit 0
    fi
fi

if [ -z "$MANAGERNAME" ]; then
    MANAGERNAME="manager"
fi

############## Tables prefix

if [ -z "$TABLEPREFIX" ]; then
    TABLEPREFIX=""
else
    echo -e "$TABLEPREFIX" | grep "[^_a-zA-Z0-9\-]"
    if [ "$?" -ne 1 ]; then
        echo "ERROR: Table prefix is bad symbols"
        exit 0
    fi
fi

if [ -z "$TABLEPREFIX" ]; then
    TABLEPREFIX="modx_${USERNAME}_"
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
#listen 443 ssl; # default_server
#listen [::]:443 ssl; # default_server

location ~* ^/\.well-known/ {
    root /var/www/html;
    break;
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

##
#
##
if (\$http_user_agent ~* (SemrushBot|MJ12bot|AhrefsBot|bingbot|DotBot|LinkpadBot|SputnikBot|statdom.ru|MegaIndex.ru|WebDataStats|Jooblebot|Baiduspider|BackupLand|NetcraftSurveyAgent|openstat.ru)) {
    return 444;
}

##
#
##
if (\$request_uri ~* '^/index.php$') {
    return 301 /;
}

##
#
##
location ~* ^/($MANAGERNAME|$CONNECTORSNAME|admin|adminka|manager|mngr|m|connectors|cnnctrs|connectors-[_A-Z-a-z-0-9]+|_build)/ {
    location ~ \.php$ {
        try_files \$uri =404;

        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass backend-$USERNAME;
    }
    break;
}

##
# Remove double slashes in url
##
location ~* .*//+.* {
    rewrite (.*)//+(.*) \$1/\$2 permanent;
}

##
# PHP handler
##
location ~ \.php$ {
    #try_files \$uri =404;
    try_files \$uri \$uri/ @rewrite;

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_pass backend-$USERNAME;

    #fastcgi_read_timeout 180;
}" > /var/www/$USERNAME/main.nginx
ln -s /var/www/$USERNAME/main.nginx /etc/nginx/conf.inc/main/$USERNAME.conf

echo "##
#
##
#location /api/ {
#   try_files \$uri @modx_rest;
#}
#location @modx_rest {
#   rewrite ^/api/(.*)$ /api/index.php?_rest=\$1&\$args last;
#}

##
#
##
error_page 404 = @modx;
location @modx {
    rewrite ^/(.*)$ /index.php?q=\$1&\$args last;
}

##
# Hide modx /core/ directory
##
location ~* ^/core/ {
    return 404;
}

##
# If file and folder not exists -->
##
location / {
    try_files \$uri \$uri/ @rewrite;
}

##
#
##
location ~ .*\.(jpg|jpeg|gif|png|ico|bmp|woff2|txt|xml|pdf|flv|swf)$ {
    add_header Cache-Control \"max-age=31557600, public\";
}
location ~ .*\.(css|js)$ {
    add_header Cache-Control \"max-age=31557600, public\";
}
location ~* ^.+\.(jpg|jpeg|gif|png|ico|bmp|woff2|txt|xml|pdf|flv|swf|css|js)$ {
    try_files \$uri \$uri/ @rewrite;
    access_log off;
    expires 14d;
    break;
}

##
# --> then redirect request to entry modx index.php
##
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
echo -e $PHPCONF > /etc/php/7.4/fpm/pool.d/$USERNAME.conf_

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
if [ "$PHPVERSION" == "7.4" ]; then
    mv -f /etc/php/7.4/fpm/pool.d/$USERNAME.conf_ /etc/php/7.4/fpm/pool.d/$USERNAME.conf
fi

##############

#echo "Creating config.xml"

echo "<modx>
    <database_type>mysql</database_type>
    <database_server>localhost</database_server>
    <database>$USERNAME</database>
    <database_user>$USERNAME</database_user>
    <database_password>$MYSQLPASS</database_password>
    <database_connection_charset>utf8mb4</database_connection_charset>
    <database_charset>utf8mb4</database_charset>
    <database_collation>utf8mb4_general_ci</database_collation>
    <table_prefix>$TABLEPREFIX</table_prefix>
    <https_port>443</https_port>
    <http_host>$USERNAME.$HOST</http_host>
    <cache_disabled>0</cache_disabled>

    <inplace>1</inplace>

    <unpacked>0</unpacked>

    <language>ru</language>

    <cmsadmin>$USERNAME</cmsadmin>
    <cmspassword>$PASSWORD</cmspassword>
    <cmsadminemail>admin@$USERNAME.$HOST</cmsadminemail>

    <core_path>/var/www/$USERNAME/www/core/</core_path>

    <context_mgr_path>/var/www/$USERNAME/www/$MANAGERNAME/</context_mgr_path>
    <context_mgr_url>/$MANAGERNAME/</context_mgr_url>
    <context_connectors_path>/var/www/$USERNAME/www/$CONNECTORSNAME/</context_connectors_path>
    <context_connectors_url>/$CONNECTORSNAME/</context_connectors_url>
    <context_web_path>/var/www/$USERNAME/www/</context_web_path>
    <context_web_url>/</context_web_url>

    <remove_setup_directory>1</remove_setup_directory>
</modx>" > /var/www/$USERNAME/config.xml

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
exclude:
    - '/www/core/cache/*'
" > /var/www/$USERNAME/dumper.yaml

#############

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

echo "Restarting php7.4-fpm"
service php7.4-fpm restart

echo "Reloading nginx"
service nginx reload

##############

echo "Creating database"

Q1="CREATE DATABASE IF NOT EXISTS $USERNAME DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
Q2="GRANT ALTER,DELETE,DROP,CREATE,INDEX,INSERT,SELECT,UPDATE,CREATE TEMPORARY TABLES,LOCK TABLES ON $USERNAME.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$MYSQLPASS';"
Q3="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}"

mysql -uroot --password=$ROOTPASS -e "$SQL"

##############

echo "Installing MODX Revo"

cd /var/www/$USERNAME/www/

echo "Getting file from modx.com..."
if [ -z "$VERSION" ]; then
    sudo -u $USERNAME wget -O modx.zip http://modx.com/download/latest/
else
    sudo -u $USERNAME wget -O modx.zip https://ilyaut.ru/modx/modx-$VERSION.zip
fi

# Имитируем неудачную загрузку modx.zip
#touch modx.zip

############## Проверка скачанного архива на нулевой размер

ZIPSIZE=`ls -l ./modx.zip | cut -f 5 -d " "`
if [ "${ZIPSIZE}" = "0" ]; then
    if [ -z "$VERSION" ]; then
        echo "ERROR: Zip file is zero." && site_remove
        exit 0
    else
        sudo -u $USERNAME wget -O modx.zip https://modx.com/download/direct?id=modx-$VERSION.zip

        ZIPSIZE=`ls -l ./modx.zip | cut -f 5 -d " "`
        if [ "${ZIPSIZE}" = "0" ]; then
            echo "ERROR: Zip file is zero." && site_remove
            exit 0
        fi
    fi
fi

##############

echo "Unzipping file..."
sudo -u $USERNAME unzip "./modx.zip" -d ./ > /dev/null

##############

ZDIR=`ls -F | grep "\/" | head -1`
if [ "${ZDIR}" = "/" ]; then
    echo "ERROR: Failed to find directory." && site_remove
    exit 0
fi

if [ -d "${ZDIR}" ]; then
    cd ${ZDIR}
    echo "Moving out of temp dir..."
    sudo -u $USERNAME mv ./* ../
    cd ../
    #mv ./core/ ../core/
    sudo -u $USERNAME mv ./manager/ ./$MANAGERNAME/
    sudo -u $USERNAME mv ./connectors/ ./$CONNECTORSNAME/
    rm -r "./${ZDIR}"

    echo "Removing zip file..."
    rm "./modx.zip"

    cd "setup"
    echo "Running setup..."
    sudo -u $USERNAME php$PHPVERSION ./index.php --core_path=/var/www/$USERNAME/www/core/  --installmode=new --config=/var/www/$USERNAME/config.xml

    echo "Done!"
else
    echo "ERROR: Failed to find directory: ${ZDIR}" && site_remove
    exit 0
fi

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
http://$DOMAIN/$MANAGERNAME/
User: $USERNAME
Pass: $PASSWORD

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
echo "##MYSQL_TABLE_PREFIX##$TABLEPREFIX##MYSQL_TABLE_PREFIX_END##"
echo "##MYSQL_DB##$USERNAME##MYSQL_DB_END##"
echo "##MYSQL_USER##$USERNAME##MYSQL_USER_END##"
echo "##MYSQL_PASS##$MYSQLPASS##MYSQL_PASS_END##"

echo "##CONNECTORS_SITE##/$CONNECTORSNAME/##CONNECTORS_SITE_END##"
echo "##MANAGER_SITE##/$MANAGERNAME/##MANAGER_SITE_END##"
echo "##MANAGER_USER##$USERNAME##MANAGER_USER_END##"
echo "##MANAGER_PASS##$PASSWORD##MANAGER_PASS_END##"

echo "##PATH##/var/www/$USERNAME/www/##PATH_END##"

echo "## << INFO"
######### << Выводим инфу для обработки в даймоне