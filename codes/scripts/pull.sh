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
	cat > /root/.my.cnf <<EOF
[client]
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
	$MysqlBinDir/mysqldump  mysql user > $TMP_DIR/sql/user.sql || { echo "2|backup user failed." && return 2; }
	return 0

}

# 关闭对外连接
function stopOutConn(){

	#test -f $TMP_DIR/serverstatus/closestatus.txt || { echo "missing closestatus.txt"; return 1; }
	# 识别 closestatus.txt 文件
	
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
	echo "0|停外连接成功"	
	return 0
	
}

function restoreUser(){
	createMysqlAuth || return 1
	test -f $TMP_DIR/sql/user.sql || { echo "3|missing user.sql"; return 3; }
	$MysqlBinDir/mysql mysql < $TMP_DIR/sql/user.sql || { echo "4|restore user failed."; return 4; }
	echo "flush privileges;" | $MysqlBinDir/mysql	
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
	return 0
}

# 拉取更新脚本
function pull_sh(){
	
	rsync -q -c -azP --port=6393  ${user}@${ipaddress}::script --password-file=$TMP_DIR/pass ${TMP_DIR}/script/
	if [[ $? -ne 0 ]]; then
		echo "2|pull scripts failed"
		return 2
	fi
	return 0

}


# 拉取前端源码
function pull_frontend(){
	rsync -q -c -azP --exclude={'/config/','/data/system/','/debug/'} --port=6393 ${user}@${ipaddress}::frontend --password-file=$TMP_DIR/pass  ${FRONTEND_TARGET}/
	if [ $? -ne 0 ]; then
		echo "3|pull webcode failed"
		return  3
	fi
	return 0
}

# 拉取后端源码
function pull_backend(){
	rsync -q -c -azP --exclude={'/runtime','/application/database.php','/application/admin/config.php','/application/admin/qiniu.config.php'} --delete --port=6393  ${user}@${ipaddress}::backend   --password-file=$TMP_DIR/pass ${BACKEND_TARGET}/
	if [ $? -ne 0 ]; then
		echo "4|pull admincode failed"
		return  4
	fi
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
function pull_versions(){
	rsync -q -c -azP --port=6393  ${user}@${ipaddress}::versions --password-file=$TMP_DIR/pass ${TMP_DIR}/
	if [[ $? -ne 0 ]]; then
		echo "7|pull versions failed"
		return 7
	fi
	return 0
}

# 执行SQL
function execsql(){
	cp -a $TMP_DIR/sql/sqlexc.php $FRONTEND_TARGET/
	isApacheAlive && ret=`curl -sk 'https://127.0.0.1:446/sqlexc.php?refurl=https://127.0.0.1/'` || { echo "apache异常"; return 1; }
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
	isApacheAlive && ret=`curl -sk 'https://127.0.0.1:446/sqlrefresh.php?refurl=https://127.0.0.1/'` || { echo "apache异常"; return 1; }
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
	test -f /root/.my.cnf && rm -f /root/.my.cnf
	exit $1
}

# 获取closestatus.txt文件中关于新版本是否需要停外连接的信息
function getDBStopConnStatus(){
	statuFile=$TMP_DIR/serverstatus/closestatus.txt
	test -f $statuFile || { echo "$statuFile missing"; exit 1; }
	closeState=`grep "[${newVersion}]" -A2 ${statuFile} | tail -1`
	if [[ $closeState =~ "close" ]]; then
		return 0
	else
		return 1
	fi
}

################# Main ######################

# 判断执行用户
if [[ $EUID -ne 0 ]]; then
	echo "-1|仅支持root用户执行$0"
	exit 1
fi

# 判断参数合法
if [[ $# -lt 6 ]]; then
	echo "-2|传入参数少于6个"
	exit 2
fi


# 目录存在且为空目录
function isEmptyDirAndExists(){ 
	test -d $1 || { mkdir -p $1; return 0; }
	return `{ ls -A $1|wc -w; } 2> /dev/null`
}


function cloneOldFiles(){
	OPPATH=$1
	if isEmptyDirAndExists $OPPATH; then
		# 目录初始化
		for d in web_code admin_code so; do
			test -d $OPPATH/$d || mkdir -p $OPPATH/$d
		done

		# 拷贝当前存在的生产应用文件
		rsync -a --delete $FRONTEND_TARGET/* $OPPATH/web_code/
		rsync -a --delete $BACKEND_TARGET/* $OPPATH/admin_code/
		rsync -a --delete $CLOUDAPP_TARGET/* $OPPATH/so/	
	fi
	return 0
}

user=$1
password=$2
ipaddress=$3
mode=$4
newVersion=$5


HOST_TYPE=$6
# HOST_TYPE合法取值为t_server, webserver, dbserver
if [[ $HOST_TYPE != 't_server' && $HOST_TYPE != 'webserver' && $HOST_TYPE != 'dbserver' ]]; then
	echo "1|主机类型参数传入非法"
	exit 1
fi


(type -a rsync || yum -y install rsync fuser) &> /dev/null



# 各个生产应用的路径
FRONTEND_TARGET='/bby/web/www/kod.baibaoyun.com/web_kod'
BACKEND_TARGET='/bby/web/www/admin.baibaoyun.com/snake'
CLOUDAPP_TARGET='/bby/server'


# 镜像目录
MIRROR_PATH=/bby_mirror

# 副本目录
BACKUP_PATH=/bby_backup


# 初始化 镜像更新目录
cloneOldFiles $MIRROR_PATH

# 建立更新前副本 
rm -rf $BACKUP_PATH
cloneOldFiles $BACKUP_PATH





TMP_DIR=$MIRROR_PATH
test -d $TMP_DIR/sql || mkdir -p $TMP_DIR/sql
test -d $TMP_DIR/script || mkdir -p $TMP_DIR/script
test -d $TMP_DIR/serverstatus || mkdir -p $TMP_DIR/serverstatus


set -e
case $mode in
sql)
	pull_sql || clean_exit $?
	;;
script)
	pull_sh || clean_exit $?
	;;
webcode)
	pull_frontend || clean_exit $?
	;;
admincode)
	pull_backend || clean_exit $?
	;;
cloudapp)
	pull_cloudapp || clean_exit $?
	;;
serverstatus)
	pull_status || clean_exit $?
	;;
versions)
	pull_versions || clean_exit $?
	;;
execsql)
	execsql || clean_exit $?
	;;
refreshsql)
	refreshsql || clean_exit $?
	;;
stopmysqlconn)
	backupUser && stopOutConn || clean_exit $?
	;;
backuser)
	backupUser || clean_exit $?
	;;	
restoreuser)
	restoreUser || clean_exit $?
	;;
all)
	genpasswdtxt
	pull_sql || clean_exit $?
	pull_sh || clean_exit $?
	execsql || clean_exit $?
	pull_cloudapp || clean_exit $?
	pull_frontend || clean_exit $?
	pull_backend || clean_exit $?
	pull_status || clean_exit $?
#	pull_versions || clean_exit $?
	getDBStopConnStatus && { stopOutConn || clean_exit $?; }
	refreshsql || clean_exit $?
	getDBStopConnStatus && { restoreUser || clean_exit $?; }
	;;
*)
	echo "10|usage: $0 <user> <password> <storeserver_ip> all|sql|script|webcode|admincode|cloudapp|serverstatus|versions|execsql|refreshsql"
	exit 10
esac
echo "0|ok"
