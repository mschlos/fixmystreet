# Using Vagrant
Vagrant provides any easy method to setup virtual development environments, for further information see [their website](http://www.vagrantup.com).

The basic process is to create a "base" vm, and then "provision" it with the software packages and setup needed. There are several ways to do this, including Chef and Puppet, but these instructions utilise the existing FixMyStreet install script, in order to keep this in line with other developments on FMS. The supplied scripts will create you a Vagrant vm based on the server edition of Ubuntu 12.04 LTS that contains everything you need to work on FMS.

1. [Install VirtualBox](http://www.virtualbox.org/wiki/Downloads) and [Vagrant](http://downloads.vagrantup.com/), create a folder somewhere that you'll be doing your work from and clone [fixmystreet](https://github.com/mysociety/fixmystreet) into it.

2. From your newly cloned `fixmystreet` directory, run `cp conf/Vagrantfile.example ../Vagrantfile` to move the Vagrant config file to the right place.

3. Run `vagrant up` in the same directory you just moved `Vagrantfile` into.

4. Wait... (probably 15 minutes or so depending on your internet connection speed). Vagrant will run `bin/provision.sh`, which in turn runs `commonlib/bin/install-site.sh`, and then configures a few extra things to make the tests run.

5. When the install process has finished, you should be able to `vagrant ssh` into your new development environment. You'll find the website in `/var/www/localhost/fixmystreet`. You can either start up the site on the development server, or run the tests from the command line.

6. Enjoy! Once you've started the site running on the development server, you can visit `http://localhost:3000` from your host computer as if it was running locally, except all the server config and versioning are nicely contained in a virtual environment.
