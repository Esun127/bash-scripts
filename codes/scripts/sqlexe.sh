#!/bin/bash


GIT_PATH=/bby/git

FRONTEND_ROOT=/bby/web/www/kod.baibaoyun.com/web_kod

cp -a $GIT_PATH/script/sqlexc.php $FRONTEND_ROOT/

ret=`curl -sk https://127.0.0.1:446/sqlexc.php?refurl=https://127.0.0.1/`
if [[ ! $ret =~ '执行成功' ]]; then
	echo "1|execute failed related with sql"
	rm -f $FRONTEND_ROOT/sqlexc.php
	exit 1
fi
echo "0|$ret"
rm -f $FRONTEND_ROOT/sqlexc.php
