#!/bin/bash

# Install the Term::Animation
sudo apt install libcurses-perl
wget https://cpan.metacpan.org/authors/id/K/KB/KBAUCOM/Term-Animation-2.5.tar.gz
tar xzf Term-Animation-2.5.tar.gz
cd Term-Animation-2.5/
perl Makefile.PL
make 
sudo make install

# Install ASCIIaquarium
cd /tmp
wget http://www.robobunny.com/projects/weatherspect/weatherspect.tar.gz
tar -zxvf weatherspect.tar.gz
cd weatherspect_v1.11/
sudo cp weatherspect /usr/local/bin
sudo chmod 0755 /usr/local/bin/weatherspect
