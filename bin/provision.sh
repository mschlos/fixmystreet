#!/bin/sh
set -e

# Update apt-get first
apt-get update -y

# Run the install script
sh /vagrant/fixmystreet/commonlib/bin/install-site.sh fixmystreet vagrant localhost

# Update the general.yml config file with vagrant specific values
sed "s/^MAPIT_URL: ''/MAPIT_URL: 'http:\/\/mapit.mysociety.org'/" -i /var/www/localhost/fixmystreet/conf/general.yml
sed "s/^  - cobrand_one/  - fixmystreet/" -i /var/www/localhost/fixmystreet/conf/general.yml
sed "s/^  - cobrand_two: 'hostname_substring2'/  - fixmystreet: 'localhost'/" -i /var/www/localhost/fixmystreet/conf/general.yml

# Switch the url to make the tests pass
# Note that this assumes you'll be browsing the site on the HOST machine
# not the guest (because the port is 8080 on your host, but 80 on the guest)
sed "s/^BASE_URL: 'http:\/\/www.example.org'/BASE_URL: 'http:\/\/localhost:8080'/" -i /var/www/localhost/fixmystreet/conf/general.yml

# Generate Welsh and Norweigian locales so i8n tests pass
locale-gen cy_GB.UTF-8
locale-gen nb_NO.UTF-8

echo "You can now ssh into your vagrant box: vagrant ssh"
echo "The website code is found in: /var/www/localhost/fixmystreet or ~/fixmystreet"
echo "Note: to get a fully up and running system, you may want to run bin/cron-wrapper bin/update-all-reports after you login"