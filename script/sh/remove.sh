#!/bin/bash

##############

MAXLENGTH=16

############## MySQL root password

ROOTPASS=$1

echo -e "$ROOTPASS" | grep "*"
if [ "$?" -ne 1 -o -z "$ROOTPASS" ]; then
	echo "ERROR: Enter MySQL root password"
	exit 0
fi

##############

USERNAME=$2

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

mysql -uroot --password=$ROOTPASS -e "DROP USER $USERNAME@localhost"
mysql -uroot --password=$ROOTPASS -e "DROP DATABASE $USERNAME"
rm -f /etc/nginx/sites-enabled/$USERNAME.conf
rm -f /etc/nginx/sites-available/$USERNAME.conf
rm -f /etc/nginx/conf.inc/domains/$USERNAME.conf
rm -f /etc/nginx/conf.inc/main/$USERNAME.conf
rm -f /etc/nginx/conf.inc/access/$USERNAME.conf
rm -f /etc/php/5.6/fpm/pool.d/$USERNAME.conf
rm -f /etc/php/5.6/fpm/pool.d/$USERNAME.conf_
rm -f /etc/php/7.0/fpm/pool.d/$USERNAME.conf
rm -f /etc/php/7.0/fpm/pool.d/$USERNAME.conf_
rm -f /etc/php/7.1/fpm/pool.d/$USERNAME.conf
rm -f /etc/php/7.1/fpm/pool.d/$USERNAME.conf_
rm -f /etc/php/7.2/fpm/pool.d/$USERNAME.conf
rm -f /etc/php/7.2/fpm/pool.d/$USERNAME.conf_
find /var/log/nginx/ -type f -name "$USERNAME-*" -exec rm '{}' \;

service nginx reload
service php5.6-fpm restart
service php7.0-fpm restart
service php7.1-fpm restart
service php7.2-fpm restart

#pkill -U $USERNAME
userdel -rf $USERNAME

echo "Done!"