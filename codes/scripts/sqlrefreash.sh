#!/bin/bash

GIT_PATH=/bby/git

FRONTEND_ROOT=/bby/web/www/kod.baibaoyun.com/web_kod

cp -a $GIT_PATH/script/sqlrefresh.php $FRONTEND_ROOT/

curl -sk https://127.0.0.1:446/sqlrefresh.php?refurl=https://127.0.0.1/
if [[ $? -ne 0 ]]; then
	echo "1|execute failed related with sql"
	rm -f $FRONTEND_ROOT/sqlrefresh.php
	exit 1
fi
echo "0|execute succeed related with sql"
rm -f $FRONTEND_ROOT/sqlrefresh.php