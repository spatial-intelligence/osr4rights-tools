#!/bin/sh

# Creates Ubuntu webserver to run osr4rightstools.org 

# disable auto upgrades by apt - in dev mode only
cd /home/dave

cat <<EOT >> 20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "1";
EOT

sudo mv /home/dave/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades

sudo apt install apache2 -y

cd /home/dave
# could copy files or do this way
sudo git clone https://github.com/djhmateer/osr4rights-tools.git source

# 000-default.conf is the filename created by apache2 on install
# AllowOverride in web root for url rewriting
sudo cp /home/dave/source/fire-map-infra/000-default.conf /etc/apache2/sites-available

# don't need ssl yet

# an example of adding a module
sudo a2enmod rewrite

sudo service apache2 restart

# PHP7.4.3 is included in 20.04 so no need to point to this new repo unless want PHP8
sudo apt install php -y
# install other php modules here - see wordpress install

# for MSSQL
# https://docs.microsoft.com/en-us/sql/connect/php/installation-tutorial-linux-mac?view=sql-server-ver16
sudo apt install php-dev -y
sudo apt install php-xml -y

# ODBC
sudo curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

sudo su -c "curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list > /etc/apt/sources.list.d/mssql-release.list"

sudo apt-get update

sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18

# optional but need for pecl next
sudo apt-get install -y unixodbc-dev

sudo pecl install sqlsrv
sudo pecl install pdo_sqlsrv

sudo su -c "printf \"; priority=20\nextension=sqlsrv.so\n\" > /etc/php/7.4/mods-available/sqlsrv.ini"
sudo su -c "printf \"; priority=30\nextension=pdo_sqlsrv.so\n\" > /etc/php/7.4/mods-available/pdo_sqlsrv.ini"

sudo phpenmod sqlsrv pdo_sqlsrv

# apache
sudo apt install libapache2-mod-php -y


cd /etc/php/7.4/apache2
sudo cp php.ini phpoldini.txt
sudo cp /home/dave/source/fire-map-infra/php74.ini /etc/php/7.4/apache2/php.ini

# delete the apache default index.html
sudo rm /var/www/html/index.html

sudo mkdir /var/www/html/test
sudo cp /home/dave/source/fire-map-infra/index.html /var/www/html/test

sudo cp /home/dave/source/fire-map-infra/*.php /var/www/html/test

# sudo chmod 755 /var/www

# checks for syntax errors in apache conf
#sudo apache2ctl configtest

sudo systemctl restart apache2

# PB HERE
cd /home/dave

git clone https://github.com/spatial-intelligence/firemapscanner.git 
sudo cp -r /home/dave/firemapscanner/firemapweb/. /var/www/html/

# install postgres and postgis extension
sudo apt -y install gnupg2
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" |sudo tee  /etc/apt/sources.list.d/pgdg.list
sudo apt update
sudo apt install postgis postgresql-13-postgis-3 -y

# create Db, User etc..
# https://www.postgresql.org/docs/current/app-psql.html

# copy from local /secrets/postgres-create-db.sql

cd /home/dave
sudo -u postgres psql --echo-all --file=postgres-create-db.sql

cd /home/dave/source/fire-map-infra
sudo -u postgres psql --echo-all --dbname=nasafiremap --file=postgres-populate-db.sql

sudo apt install php7.4-pgsql -y
sudo service apache2 restart

cd /var/www/html
sudo mkdir uploads
sudo chmod 777 uploads

# install ogr2ogr tools for spatial data conversions
sudo apt install gdal-bin -y
sudo apt install unzip -y

sudo apt update
sudo apt upgrade -y

# fix for PB's version has firemapweb hard coded
# sudo cp /home/dave/source/fire-map-infra/do_fileupload.php /var/www/html
# fix for PB's version put in our cookie auth 
# sudo cp /home/dave/source/fire-map-infra/header_alerts.php /var/www/html

# don't want files in the /test directory as would be confusing
# sudo rm /var/www/html/test/header_alerts.php
# sudo rm /var/www/html/test/do_fileupload.php


# copy new version of ph_hba.conf
sudo mv /etc/postgresql/13/main/pg_hba.conf /etc/postgresql/13/main/OLD_pg_hba.conf
sudo cp /home/dave/source/fire-map-infra/pg_hba.conf /etc/postgresql/13/main

# update postgres.conf to allow connections from anywhere (default is localhost)
# \x27 is hex for '
sudo sed -i -e 's/#listen_addresses = \x27localhost\x27/listen_addresses = \x27*\x27 /g' /etc/postgresql/13/main/postgresql.conf

# https://pgtune.leopard.in.ua/
sudo sed -i -e 's/shared_buffers = 128MB/shared_buffers = 2GB/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#effective_cache_size = 4GB/effective_cache_size = 6GB/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#maintenance_work_mem = 64MB/maintenance_work_mem = 512MB/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#checkpoint_completion_target = 0.5/checkpoint_completion_target = 0.9/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#wal_buffers = -1/wal_buffers = 16MB/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#default_statistics_target = 100/default_statistics_target = 100/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#random_page_cost = 4.0/random_page_cost = 1.1/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#effective_io_concurrency = 1/effective_io_concurrency = 200/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#work_mem = 4MB/work_mem = 20971kB/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/min_wal_size = 80MB/min_wal_size = 1GB/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/max_wal_size = 1GB/max_wal_size = 4GB/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#max_worker_processes = 8/max_worker_processes = 2/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#max_parallel_workers_per_gather = 2/max_parallel_workers_per_gather = 1/g' /etc/postgresql/13/main/postgresql.conf
sudo sed -i -e 's/#max_parallel_workers = 8/max_parallel_workers = 2/g' /etc/postgresql/13/main/postgresql.conf

sudo sed -i -e 's/#max_parallel_maintenance_workers = 2/max_parallel_maintenance_workers = 1/g' /etc/postgresql/13/main/postgresql.conf

sudo service postgresql restart





# postgres client authentication file
# phil do we need the extra in ipv4
# host    all             all             all                     md5
# top 2 go from peer to md5 and user posgres



# go with newer apt which gets dependency updates too (like linux-azure)
# sudo apt update -y
# sudo apt upgrade -y
  
# # Install packages for .NET for Ubutu 20.04 LTS
# wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
# sudo dpkg -i packages-microsoft-prod.deb
# rm packages-microsoft-prod.deb

# # nginx
# sudo apt-get install nginx -y

# # .NET 6 SDK
# sudo apt-get update; \
#   sudo apt-get install -y apt-transport-https && \
#   sudo apt-get update && \
#   sudo apt-get install -y dotnet-sdk-6.0

# # create document root for published files 
# sudo mkdir /var/www

# # create gitsource folder and clone
# sudo mkdir /gitsource
# cd /gitsource
# sudo git clone https://github.com/osr4rightstools/osr4rights-tools .

# # nginx config
# # ssl certs will already be in /certs
# # copied in with create-kestrel-osr-with-secrets.sh file
# sudo cp /gitsource/infra/nginx.conf /etc/nginx/sites-available/default
# sudo nginx -s reload

# # compile and publish the web app
# sudo dotnet publish /gitsource/src/OSR4Rights.Web --configuration Release --output /var/www

# # change ownership of the published files to what it will run under
# sudo chown -R www-data:www-data /var/www
# # allow exective permissions
# sudo chmod +x /var/www

# # cookie keys to allow machine to restart and for it to 'remember' cookies
# # todo - store these in blob storage?
# sudo mkdir /var/osr-cookie-keys
# sudo chown -R www-data:www-data /var/osr-cookie-keys
# # allow read and write
# sudo chmod +rw /var/osr-cookie-keys

# # fileStores
# sudo mkdir /tusFileStore
# sudo chown -R www-data:www-data /tusFileStore
# # todo - make less
# # sudo chmod +rwx /tusFileStore
# # sudo chmod +rw /tusFileStore

# sudo mkdir /osrFileStore
# sudo chown -R www-data:www-data /osrFileStore
# # todo - make less
# # sudo chmod +rwx /osrFileStore

# # auto start on machine reboot
# sudo systemctl enable kestrel-osr.service

# # start the Kestrel web app using systemd using kestrel-blc.service text files
# sudo systemctl start kestrel-osr.service

# # https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-5.0#configure-the-firewall
# sudo apt-get install ufw

# sudo ufw allow 22/tcp
# sudo ufw allow 80/tcp
# sudo ufw allow 443/tcp

# sudo ufw enable

#   # a nice shortcut sym link
# # sudo ln -s /usr/local/openresty/nginx/ /home/dave/nginx
# sudo ln -s /var/www/logs/ /home/dave/logs

# # sudo snap install bpytop

