#!/bin/bash

##############

MAXLENGTH=16

##############

USERNAME=$1

echo -e "$USERNAME" | grep "[^A-Za-z0-9]"
if [ "$?" -ne 1 -o -z "$USERNAME" ]; then
	echo "ERROR: Username bad symbols"
	exit 0
fi
if [ "${#USERNAME}" -gt "$MAXLENGTH" ]; then
	echo "ERROR: Username length more $MAXLENGTH"
	exit 0
fi

############## PHP version

PHPVERSION=$2

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

#mv -f /etc/php/5.6/fpm/pool.d/$USERNAME.conf /etc/php/5.6/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/7.0/fpm/pool.d/$USERNAME.conf /etc/php/7.0/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/7.1/fpm/pool.d/$USERNAME.conf /etc/php/7.1/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/7.2/fpm/pool.d/$USERNAME.conf /etc/php/7.2/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/7.3/fpm/pool.d/$USERNAME.conf /etc/php/7.3/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/7.4/fpm/pool.d/$USERNAME.conf /etc/php/7.4/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/8.0/fpm/pool.d/$USERNAME.conf /etc/php/8.0/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/8.1/fpm/pool.d/$USERNAME.conf /etc/php/8.1/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/8.2/fpm/pool.d/$USERNAME.conf /etc/php/8.2/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/8.3/fpm/pool.d/$USERNAME.conf /etc/php/8.3/fpm/pool.d/$USERNAME.conf_
mv -f /etc/php/8.4/fpm/pool.d/$USERNAME.conf /etc/php/8.4/fpm/pool.d/$USERNAME.conf_

#echo "Restarting php5.6-fpm"
#service php5.6-fpm restart

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

echo "Restarting php8.0-fpm"
service php8.0-fpm restart

echo "Restarting php8.1-fpm"
service php8.1-fpm restart

echo "Restarting php8.2-fpm"
service php8.2-fpm restart

echo "Restarting php8.3-fpm"
service php8.3-fpm restart

echo "Restarting php8.4-fpm"
service php8.4-fpm restart

echo "Reloading nginx"
service nginx reload

#if [ "$PHPVERSION" == "5.6" ]; then
#    mv -f /etc/php/5.6/fpm/pool.d/$USERNAME.conf_ /etc/php/5.6/fpm/pool.d/$USERNAME.conf
#fi
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
if [ "$PHPVERSION" == "8.0" ]; then
    mv -f /etc/php/8.0/fpm/pool.d/$USERNAME.conf_ /etc/php/8.0/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "8.1" ]; then
    mv -f /etc/php/8.1/fpm/pool.d/$USERNAME.conf_ /etc/php/8.1/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "8.2" ]; then
    mv -f /etc/php/8.2/fpm/pool.d/$USERNAME.conf_ /etc/php/8.2/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "8.3" ]; then
    mv -f /etc/php/8.3/fpm/pool.d/$USERNAME.conf_ /etc/php/8.3/fpm/pool.d/$USERNAME.conf
fi
if [ "$PHPVERSION" == "8.4" ]; then
    mv -f /etc/php/8.4/fpm/pool.d/$USERNAME.conf_ /etc/php/8.4/fpm/pool.d/$USERNAME.conf
fi

##############

#echo "Restarting php5.6-fpm"
#service php5.6-fpm restart

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

echo "Restarting php8.0-fpm"
service php8.0-fpm restart

echo "Restarting php8.1-fpm"
service php8.1-fpm restart

echo "Restarting php8.2-fpm"
service php8.2-fpm restart

echo "Restarting php8.3-fpm"
service php8.3-fpm restart

echo "Restarting php8.4-fpm"
service php8.4-fpm restart

echo "Reloading nginx"
service nginx reload

echo "Done!"