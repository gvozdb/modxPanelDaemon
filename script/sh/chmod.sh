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

##############

echo "Set permissions for /var/www/$USERNAME/www/";

echo "CHOWN files...";
chown -R $USERNAME:$USERNAME "/var/www/$USERNAME/www";

echo "CHMOD directories...";
find "/var/www/$USERNAME/www" -type d -exec chmod 0755 '{}' \;

echo "CHMOD files...";
find "/var/www/$USERNAME/www" -type f -exec chmod 0644 '{}' \;

echo "Done!"