#!/bin/bash
mb_server=`dirname $0`/..
cd $mb_server

eval $(perl -Mlocal::lib)

echo `date` : "Checking dependencies (if this fails on libintl-perl, don't worry)"
cpanm --notest --installdeps .

echo `date` : "Rebuilding resources"
npm install
UGLIFY=1 node_modules/.bin/gulp

echo `date` : "Building and installing translations"
make -C po all_quiet && make -C po deploy

echo `date` : Update complete
