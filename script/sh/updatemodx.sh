#!/bin/bash

##############

MAXLENGTH=16

##############

USERNAME=$1

#echo -e "$USERNAME" | grep "[^A-Za-z0-9]"
echo "$USERNAME" | grep "[^A-Za-z0-9]"
if [ "$?" -ne 1 -o -z "$USERNAME" ]; then
    echo "ERROR: Username bad symbols"
    exit 0
fi
if [ "${#USERNAME}" -gt "$MAXLENGTH" ]; then
    echo "ERROR: Username length more $MAXLENGTH"
    exit 0
fi

############## Enter pl version MODX Revo (example: "2.5.2-pl")

VERSION=$2

#echo -e "$VERSION" | grep "[^a-zA-Z0-9.-]"
echo "$VERSION" | grep "[^a-zA-Z0-9.-]"
if [ "$?" -ne 1 -o -z "$VERSION" ]; then
    echo "ERROR: Version bad symbols"
    exit 0
fi

##############

############## Replace connectors url to new

# sed -i -e "s/\(.*\)<context_connectors_url>.*<\/context_connectors_url>.*/\1<context_connectors_url>\/${NEW_CONNECTORS_NAME}\/<\/context_connectors_url>/" ./config.xml

##############

echo "Updating MODx"

cd /var/www/$USERNAME/www/

echo "Getting file from modx.com..."
#sudo -u $USERNAME wget -O modx.zip http://modx.com/download/latest/
sudo -u $USERNAME wget -O modx.zip http://modx.com/download/direct/modx-$VERSION.zip

echo "Unzipping files..."
sudo -u $USERNAME unzip "./modx.zip" -d ./ > /dev/null

ZDIR=`ls -F | grep "modx-" | head -1`
if [ "${ZDIR}" = "/" ]; then
    echo "ERROR: Failed to find directory."
    exit 0
fi

if [ -d "${ZDIR}" ]; then
    cd ${ZDIR}
    echo "Moving out of temp dir..."
    sudo -u $USERNAME cp -r ./* ../
    cd ../
    rm -r "./${ZDIR}"

    echo "Removing zip file..."
    rm "./modx.zip"

    echo "Parsing config.xml..."
    MANAGER_DIR="`cat ./../config.xml | grep 'context_mgr_url' | sed 's/.*<context_mgr_url>\(.*\)<\/context_mgr_url>.*/\1/'`"
    CONNECTORS_DIR="`cat ./../config.xml | grep 'context_connectors_url' | sed 's/.*<context_connectors_url>\(.*\)<\/context_connectors_url>.*/\1/'`"

    echo "Replace connectors dir..."
    rm -r ".${MANAGER_DIR}"
    rm -r ".${CONNECTORS_DIR}"
    sudo -u $USERNAME mv ./manager/ ".${MANAGER_DIR}"
    sudo -u $USERNAME mv ./connectors/ ".${CONNECTORS_DIR}"

    cd "setup"
    echo "Running setup..."
    sudo -u $USERNAME php ./index.php --installmode=upgrade --config=/var/www/$USERNAME/config.xml --core_path=/var/www/$USERNAME/core/

    echo "Done!"
else
    echo "ERROR: Failed to find directory: ${ZDIR}"
    exit 0
fi