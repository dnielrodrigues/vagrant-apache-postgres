#!/usr/bin/env bash

# Use single quotes instead of double quotes to make it work with special-character passwords
PASSWORD='rodrigues'
PROJECTFOLDER='html'

# create project folder
sudo mkdir "/var/www/${PROJECTFOLDER}"

# update / upgrade
sudo apt-get update
sudo apt-get -y upgrade

# install apache 2.5 and php 5.5
sudo apt-get install -y apache2
sudo apt-get install -y php5

# postgres
sudo apt-get install -y postgresql postgresql-contrib

POSTGRE_VERSION=9.3

# listen for localhost connections
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/$POSTGRE_VERSION/main/postgresql.conf

# identify users via "md5", rather than "ident", allowing us to make postgres
# users separate from system users. "md5" lets us simply use a password
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$POSTGRE_VERSION/main/pg_hba.conf
sudo service postgresql start

# create new user "root" with defined password "root" not a superuser
sudo -u postgres psql -c "CREATE ROLE root LOGIN UNENCRYPTED PASSWORD '$PASSWORD' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;"

# create new database "database"
sudo -u postgres psql -c "CREATE DATABASE database"

# restart postgres
sudo service postgresql restart

# install PDO postgres
sudo apt-get install php5-pgsql

# config postgres PDO
POSTGREPDOCONFIG=$(cat<<EOF
extension=pdo.so
extension=php_pgsql.so
EOF
)
sudo echo "${APACHECONFIGFILE}" >> /etc/php5/apache2/php.ini

# restart postgres
sudo service postgresql restart

# install mysql and give password to installer
#sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $PASSWORD"
#sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $PASSWORD"
#sudo apt-get -y install mysql-server
#sudo apt-get install php5-mysql

# install phpmyadmin and give password(s) to installer
# for simplicity I'm using the same password for mysql and phpmyadmin
#sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
#sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PASSWORD"
#sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $PASSWORD"
#sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PASSWORD"
#sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
#sudo apt-get -y install phpmyadmin

# setup hosts file
VHOST=$(cat <<EOF
<VirtualHost *:80>
    DocumentRoot "/var/www/${PROJECTFOLDER}"
    <Directory "/var/www/${PROJECTFOLDER}">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf

# setup hosts vagrant.app file
VHOSTVAGRANT=$(cat <<EOF
<VirtualHost *:80>
        ServerName vagrant.app
        ServerAlias www.vagrant.app
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/vagrant.app/public
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        <Directory "/var/www/vagrant.app/public">
        AllowOverride All
        </Directory>
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
)
echo "${VHOSTVAGRANT}" > /etc/apache2/sites-available/vagrant.app.conf

# create folder
mkdir /var/www/vagrant.app
mkdir /var/www/vagrant.app/public

# enable host vagrant.app
sudo a2ensite /etc/apache2/sites-available/vagrant.app.conf

# change apache user to "vagrant"
sudo cp /etc/apache2/envvars /etc/apache2/envvars-bkp
APACHECONFIGFILE=$(cat<<EOF
unset HOME
if [ "${APACHE_CONFDIR##/etc/apache2-}" != "${APACHE_CONFDIR}" ] ; then
        SUFFIX="-${APACHE_CONFDIR##/etc/apache2-}"
else
        SUFFIX=
fi
export APACHE_RUN_USER=vagrant
export APACHE_RUN_GROUP=vagrant
export APACHE_PID_FILE=/var/run/apache2/apache2$SUFFIX.pid
export APACHE_RUN_DIR=/var/run/apache2$SUFFIX
export APACHE_LOCK_DIR=/var/lock/apache2$SUFFIX
export APACHE_LOG_DIR=/var/log/apache2$SUFFIX
export LANG=C
export LANG
EOF
)
echo "${APACHECONFIGFILE}" > /etc/apache2/envvars

# enable mod_rewrite
sudo a2enmod rewrite

# resolve apache ServerName bug
sudo echo "ServerName localhost" >> /etc/apache2/httpd.conf

# restart apache
sudo service apache2 reload
sudo service apache2 restart

# install git
sudo apt-get -y install git

# install Composer
curl -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
