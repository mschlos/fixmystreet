# Update apt-get first
apt-get update -y

# Run the install script
sh /vagrant/fixmystreet/commonlib/bin/install-site.sh fixmystreet vagrant localhost

# Install compass
gem install compass

# Make the css
/var/www/localhost/fixmystreet/bin/make_css

# Run the update-all-reports script
/var/www/localhost/fixmystreet/bin/cron-wrapper /var/www/localhost/fixmystreet/bin/update-all-reports

# Switch general.yml to a localhost-dev friendly version
cp /vagrant/fixmystreet/conf/general.yml-vagrant /var/www/localhost/fixmystreet/conf/general.yml

# Install the translation files we need and set them all up
# so that all the i8n tests pass
/var/www/localhost/fixmystreet/commonlib/bin/gettext-makemo -quiet FixMyStreet-EmptyHomes
/var/www/localhost/fixmystreet/bin/make_po FixMyStreet-EmptyHomes
/var/www/localhost/fixmystreet/bin/make_emptyhomes_welsh_po

# Generate Welsh and Norweigian locales
locale-gen cy_GB.UTF-8
locale-gen nb_NO.UTF-8

echo "You can now ssh into your vagrant box: vagrant ssh"
echo "The website code is found in: /var/www/localhost/fixmystreet"