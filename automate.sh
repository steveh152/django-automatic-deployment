#!/bin/bash

#-----------------------------------------------
# Django Sample App Setup
#-----------------------------------------------

echo "#############################################################"
echo "#"
echo "# Django Sample App Deployment Automation"
echo "#"
echo "#############################################################"
echo "#"
echo "# Enter sudo password if prompted to install dependencies:"

# Clear all firewall rules; will configure firewall after app setup
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -t raw -F
sudo iptables -t raw -X
sudo iptables -t security -F
sudo iptables -t security -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# Install dependencies
sudo apt-get install git
sudo pip install virtualenvwrapper

echo "#"
echo "Dependencies installed, continuing with deployment..."
echo "#"

# Set up VirtualEnvWrapper
export WORKON_HOME=/home/$USER/Envs
mkdir -p $WORKON_HOME			# make directory for virtualenv
source /usr/local/bin/virtualenvwrapper.sh		# needed for virtualenv to work

mkvirtualenv --clear CoolDjangoApp		# create project space

# Download Django Sample App code into virtual env
git clone git://github.com/kirpit/django-sample-app.git /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp
cd /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp	
pip install -r requirements.txt			# don't need sudo b/c we're in virtualenv

# Replace default 'projectname' text with our own project name, 'CoolDjangoApp'
sed -i -e 's/projectname/CoolDjangoApp/g' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/wsgihandler.py

# Set up database
echo "#"
echo "# Setting up database..."
echo "#"

# Create local.py by copying template file
cp /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings/local.template.py /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings/local.py

# Use sqlite3 for database
sed -i -e 's/backends.postgresql_psycopg2/backends.sqlite3/g' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings/local.py
sed -i -e 's/backends.postgresql_psycopg2/backends.sqlite3/g' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings/default.py
sed -i -e 's/dev_database_name/CoolDjangoApp_DB/g' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings/local.py
sed -i -e 's/prod_database_name/CoolDjangoApp_DB/g' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings/default.py

# Fix outdated toolbar names to avoid errors
sed -i -e '/version.VersionDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/.TimerDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/.HeaderDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/_vars.RequestVarsDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/.TemplateDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/.SQLDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/.SignalDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/.settings_vars.SettingsVarsDebugPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py
sed -i -e '/.logger.LoggingPanel/d' /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.local.py

# Finish up database setup and start server
cd /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname
./manage.py syncdb
./manage.py migrate

#----------------------------------------------
# Firewall Setup
#----------------------------------------------

sudo iptables -P OUTPUT ACCEPT		# allow all outbound traffic

sudo iptables -P FORWARD DROP			# drop all incoming traffic initially;
sudo iptables -P INPUT DROP				# will open up valid ports after

# allow traffic over ICMP and TCP ports 80 and 443 from everywhere
sudo iptables -A INPUT -p icmp -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# accept SSH from subnets 10.0.0.0/8, 192.168.0.0/16, & 172.0.0.0/8
sudo iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/16 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -s 172.0.0.0/8 -j ACCEPT

# accept RDP from subnets 10.0.0.0/8, 192.168.0.0/16, & 172.0.0.0/8
sudo iptables -A INPUT -p tcp --dport 3389 -s 10.0.0.0/8 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3389 -s 192.168.0.0/16 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3389 -s 172.0.0.0/8 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 3389 -s 10.0.0.0/8 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 3389 -s 192.168.0.0/16 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 3389 -s 172.0.0.0/8 -j ACCEPT

echo "#"
echo "# Firewall successfully configured"
echo "#"
echo "# Launching App..."
echo "#"

# Generate secret key
secret_key=$(python -c 'import random; import string; print "".join([random.SystemRandom().choice(string.digits + string.letters + string.punctuation) for i in range(100)])')
sed -i -e "s/!!! paste your own secret key here !!!/$secret_key/g" /home/$USER/Envs/CoolDjangoApp/CoolDjangoApp/projectname/settings.default.py

# Start Server
nohup ./manage.py runserver &			# run server in background

echo "########################################################"
echo "#"
echo "# Django Sample App deployed successfully."
echo "#"
echo "########################################################"
