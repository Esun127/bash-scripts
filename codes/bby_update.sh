#!/bin/bash

#description: 从中控服务器拉取网站源码(不含配置文件)
#author: liuliang9835@dingtalk.com



######===============================================================###########
function isMysqlAlive(){
	Pid=`fuser -n tcp 3908 2> /dev/null`
	if [[ -z $Pid ]]; then
		echo "1|mysql has been shutdown"
		return 1
	fi
	return 0
}


function getMysqlBinDir(){
	isMysqlAlive || return 1
	Pid=`echo $Pid | sed s/[[:space:]]//g`
	mysqlBin=`ls -l  /proc/$Pid/exe | awk '{ print $NF }'`
	MysqlBinDir=`dirname $mysqlBin`
	return 0

}



function genpasswdtxt(){
	echo "$password" > $TMP_DIR/pass
	chmod 600 $TMP_DIR/pass
	return 0
}


function createMysqlAuth(){
	cat > $HOME/.my.cnf <<EOF
[client]
user=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
password=xxxxxxxxxxxxxxxxxxxxx
port=xxxxxxxxxxxxxxxxxxxxxxxxxx
host=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF
	getMysqlBinDir || return 1
	exec=$MysqlBinDir/mysqladmin
	if ! $exec ping &> /dev/null; then
		return 2
	fi
	return 0
}



function backupUser(){
	createMysqlAuth || return 1
	$MysqlBinDir/mysqldump  mysql user > /tmp/user.sql || { echo "2|backup user failed." && return 2; }
	echo "0|backup user grants successed."
	return 0

}

# 关闭对外连接
function stopOutConn(){

	createMysqlAuth || return 1
	backupUser || return 2
	# 修改对外授权
	$MysqlBinDir/mysql mysql <<EOF
UPDATE \`user\` SET Host='127.0.0.1' WHERE Host='%';
flush privileges;
EOF
	if [[ $? -ne 0 ]]; then
		echo "3|update user failed for mysql"
		return 3
	fi
	# 关闭已经打开的对外连接
	for tid in `$MysqlBinDir/mysqladmin processlist | sed -re '/localhost|127.0.0.1|Id|-/d'| cut -d'|' -f2`; do
			$MysqlBinDir/mysqladmin kill $tid || { echo "4|close $tid conn failde"; return 4; }
	done
	echo "0|stop user grants successed."	
	return 0
	
}

function restoreUser(){
	createMysqlAuth || return 1
	test -f /tmp/user.sql || { echo "3|missing user.sql"; return 3; }
	$MysqlBinDir/mysql mysql < /tmp/user.sql || { echo "4|restore user failed."; return 4; }
	echo "flush privileges;" | $MysqlBinDir/mysql	
	echo "0|restore user grants successed."
	return 0
}

######===============================================================###########	

# 拉取SQL更新
function pull_sql(){
	
	rsync -q -c -azP --port=6393 ${user}@${ipaddress}::sql --password-file=$TMP_DIR/pass $TMP_DIR/sql/
	if [[ $? -ne 0 ]]; then
		echo "1|pull sql failed"
		return 1
	fi
	echo "0|pull php scripts for sql successed."
	return 0
}

# 拉取更新脚本
function pull_sh(){
	
	rsync -q -c -azP --port=6393  ${user}@${ipaddress}::script --password-file=$TMP_DIR/pass ${TMP_DIR}/script/
	if [[ $? -ne 0 ]]; then
		echo "2|pull scripts failed"
		return 2
	fi
	echo "0|pull scripts successed."
	return 0

}


# 拉取前端源码
function pull_frontend(){
	rsync -q -c -azP --exclude={'/config/','/data/system/','/debug/'} --port=6393 ${user}@${ipaddress}::frontend --password-file=$TMP_DIR/pass  ${FRONTEND_TARGET}/
	if [ $? -ne 0 ]; then
		echo "3|pull webcode failed"
		return  3
	fi
	echo "0|pull pub_code update successed." 
	return 0
}

# 拉取后端源码
function pull_backend(){
	rsync -q -c -azP --exclude={'/runtime','/application/database.php','/application/admin/config.php','/application/admin/qiniu.config.php'} --delete --port=6393  ${user}@${ipaddress}::backend   --password-file=$TMP_DIR/pass ${BACKEND_TARGET}/
	if [ $? -ne 0 ]; then
		echo "4|pull admincode failed"
		return  4
	fi
	echo "0|pull admin_code update successed."
	return 0
}

# 拉取云应用或so
function pull_cloudapp(){
	rsync -q -c -azP --port=6393  ${user}@${ipaddress}::cloudapp --password-file=$TMP_DIR/pass ${CLOUDAPP_TARGET}/
	if [[ $? -ne 0 ]]; then
		echo "5|pull cloudapp failed"
		return 5
	fi
	ln -sf $CLOUDAPP_TARGET/*.so* /usr/lib/
	ldconfig
	echo "0|pull T_server update successed."
	return 0
}



# 拉取服务重启记录文件
function pull_status(){
	
	rsync -q -c -azP --port=6393  ${user}@${ipaddress}::status --password-file=$TMP_DIR/pass ${TMP_DIR}/serverstatus/
	if [[ $? -ne 0 ]]; then
		echo "6|pull serverstatus failed"
		return 6
	fi
	return 0
}


# 拉取版本历史记录文件
# function pull_versions(){
	# rsync -q -c -azP --port=6393  ${user}@${ipaddress}::versions --password-file=$TMP_DIR/pass ${TMP_DIR}/
	# if [[ $? -ne 0 ]]; then
		# echo "7|pull versions failed"
		# return 7
	# fi
	# return 0
# }

# 执行SQL
function execsql(){
	cp -a $TMP_DIR/sql/sqlexc.php $FRONTEND_TARGET/
	isApacheAlive || service httpd start &> /dev/null
	ret=`curl -sk 'https://127.0.0.1:446/sqlexc.php?refurl=https://127.0.0.1/'`
	if [[ ! $ret =~ '执行成功' ]]; then
		echo "1|$ret"
		rm -f $FRONTEND_TARGET/sqlexc.php
		return 2
	fi
	echo "0|$ret"
	rm -f $FRONTEND_TARGET/sqlexc.php
	return 0
}

function isApacheAlive(){
	if service httpd status &> /dev/null; then
		return 0
	fi
	return 1
}

function refreshsql(){
	cp -a $TMP_DIR/sql/sqlrefresh.php $FRONTEND_TARGET/
	isApacheAlive || service httpd start &> /dev/null
	ret=`curl -sk 'https://127.0.0.1:446/sqlrefresh.php?refurl=https://127.0.0.1/'`
	if [[ ! $ret =~ '执行成功' ]]; then
		echo "1|$ret"
		rm -f $FRONTEND_TARGET/sqlrefresh.php
		return 2
	fi
	echo "0|$ret"
	rm -f $FRONTEND_TARGET/sqlrefresh.php
	return 0
}

function clean_exit(){
	test -f $TMP_DIR/pass && rm -f $TMP_DIR/pass
	test -f $HOME/.my.cnf && rm -f $HOME/.my.cnf
	exit $1
}

# 获取closestatus.txt文件中关于新版本是否需要停外连接的信息
#function getDBStopConnStatus(){
#	statuFile=$TMP_DIR/serverstatus/closestatus.txt
#	test -f $statuFile || { echo "$statuFile missing"; exit 1; }
#		closeState=`grep "[${newVersion}]" -A2 ${statuFile} | tail -1`
#	if [[ $closeState =~ "close" ]]; then
#		return 0
#	else
#		return 1
#	fi
#}

################# Main ######################

# 判断执行用户
if [[ $EUID -ne 0 ]]; then
	echo "-1|$0 executed by root only."
	exit 1
fi

# 判断参数合法
if [[ $# -lt 5 ]]; then
	echo "-2|params less than 5"
	exit 2
fi

(type -a rsync || yum -y install rsync fuser) &> /dev/null


user=$1
password=$2
ipaddress=$3
mode=$4
TMP_DIR=$5



test -d $TMP_DIR || mkdir -p $TMP_DIR
test -d $TMP_DIR/sql || mkdir -p $TMP_DIR/sql
test -d $TMP_DIR/script || mkdir -p $TMP_DIR/script
test -d $TMP_DIR/serverstatus || mkdir -p $TMP_DIR/serverstatus

FRONTEND_TARGET='/bby/web/www/kod.baibaoyun.com/web_kod'
BACKEND_TARGET='/bby/web/www/admin.baibaoyun.com/snake'
CLOUDAPP_TARGET='/bby/server'

set -e
genpasswdtxt
pull_sh || clean_exit $?

old_ifs=$IFS
IFS='|'
mode=$mode


#
for op in $mode; do
	# 执行SQL
	if [[ $op == 'exec_sql' ]]; then
		pull_sql || clean_exit $?
		execsql || clean_exit $?
	fi
	# 刷新业务数据
	if [[ $op == 'refresh_sql' ]]; then
		pull_sql || clean_exit $?
		refreshsql || clean_exit $?
	fi
	#  拉取更新数据
	if [[ $op == 'pull_update' ]]; then
		pull_frontend || clean_exit $?
		pull_backend || clean_exit $?
		pull_cloudapp || clean_exit $?
	fi
	# 适合集成式服务器
	if [[ $op == 'all' ]]; then
		pull_sql || clean_exit $?
		execsql || clean_exit $?
		pull_cloudapp || clean_exit $?
		pull_frontend || clean_exit $?
		pull_backend || clean_exit $?
		pull_status || clean_exit $?
		stopOutConn || clean_exit $?
		refreshsql || clean_exit $?
		restoreUser || clean_exit $?
	fi
	# 停止数据库对外授权
	if [[ $op == 'stop_grant' ]]; then
		stopOutConn || { echo "1|close mysql connections failed."; clean_exit 1; }
		echo "0|close mysql connections successed."
	fi
	# 恢复数据库用户授权
	if [[ $op == 'restore_grant' ]]; then
		backupUser || { echo "2|restore user privileges failed."; clean_exit 2; }
		echo "0|restore user privileges successed."
	fi
	 
done
IFS="$old_ifs"
echo "0|ok"
clean_exit 0
