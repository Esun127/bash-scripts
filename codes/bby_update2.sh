#!/bin/bash

#description: 从中控服务器拉取网站源码(不含配置文件)
#author: liuliang9835@dingtalk.com



set -e
######===============================================================###########
function isMysqlAlive(){
        Pid=`fuser -n tcp 3908 2> /dev/null`
        if [[ -z $Pid ]]; then
                echo "1|mysql未运行"
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
user=
password=
port=
host=
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
		test -s $grantBackupPath || { echo "用户授权表已经备份"; return 0; }
        $MysqlBinDir/mysqldump mysql user > $grantBackupPath  && echo "flush privileges;" >> $grantBackupPath || { echo "2|备份用户授权表失败." && return 2; }
        echo "0|备份用户授权表成功."
        return 0

}

# 停止对外授权
function stopOutConn(){

        createMysqlAuth || return 1
        backupUser || return 2
        # 修改对外授权
        $MysqlBinDir/mysql mysql <<EOF
UPDATE \`user\` SET Host='127.0.0.1' WHERE Host='%';
flush privileges;
EOF
        if [[ $? -ne 0 ]]; then
                echo "3|临时修改授权表失败."
                return 3
        fi
        # 关闭已经打开的对外连接
        for tid in `$MysqlBinDir/mysqladmin processlist | sed -re '/localhost|127.0.0.1|Id|-/d'| cut -d'|' -f2`; do
                        $MysqlBinDir/mysqladmin kill $tid || { echo "4|关闭连接线程${tid}失败."; return 4; }
        done
        echo "0|停止对外授权成功."
        return 0

}

function restoreUser(){
        createMysqlAuth || return 1
        test -f $grantBackupPath || { echo "3|丢失user.sql"; return 3; }
        $MysqlBinDir/mysql mysql < $grantBackupPath || { echo "4|还原用户授权表失败."; return 4; }
        echo "0|还原用户授权表成功."
        return 0
}

######===============================================================###########

# 拉取SQL更新
function pull_sql(){

        rsync -q -c -azP --port=6393 ${user}@${ipaddress}::sql --password-file=$TMP_DIR/pass $TMP_DIR/sql/
        if [[ $? -ne 0 ]]; then
                echo "1|拉取数据相关php脚本失败."
                return 1
        fi
        echo "0|拉取数据相关php脚本成功."
        return 0
}

# 拉取更新脚本
function pull_sh(){

        rsync -q -c -azP --port=6393  ${user}@${ipaddress}::script --password-file=$TMP_DIR/pass ${TMP_DIR}/script/
        if [[ $? -ne 0 ]]; then
                echo "2|拉取shell脚本失败."
                return 2
        fi
        echo "0|拉取shell脚本成功."
        return 0

}


# 拉取前端源码
function pull_frontend(){
		let count=0
		while ! checkFrontendUpdated $1 && [[ $count -lt 3 ]]; do
			let count+=1			
			rsync -q -c -azP --exclude={'/config/','/data/system/','/debug/'} --port=6393 ${user}@${ipaddress}::frontend --password-file=$TMP_DIR/pass  $1/
			if [ $? -ne 0 ]; then
				continue
			fi
		done
		
		if ! checkFrontendUpdated $1; then
			echo "1|拉取前台更新失败."
			return  1
		fi
      
		echo "0|拉取前台更新成功."
        return 0
}

# 拉取后端源码
function pull_backend(){
		let count=0
		while ! checkBackendUpdated $1 && [[ $count -lt 3 ]]; do
			let count+=1
			rsync -q -c -azP --exclude={'/runtime','/application/database.php','/application/admin/config.php','/application/admin/qiniu.config.php'} --port=6393  ${user}@${ipaddress}::backend   --password-file=$TMP_DIR/pass $1/
			if [[ $? -ne 0 ]]; then
				continue
			fi			
		done
		
		if ! checkBackendUpdated $1; then
			echo "1|拉取后台管理更新失败."
			return 1
		fi
		
        echo "0|拉取后台管理更新成功."
        return 0
}

# 拉取云应用或so
function pull_cloudapp(){
		let count=0
		while ! checkCloudAppUpdated $1 && [[ $count -lt 3 ]]; do
			let count+=1
			rsync -q -c -azP --port=6393  ${user}@${ipaddress}::cloudapp --password-file=$TMP_DIR/pass $1/
			if [[ $? -ne 0 ]]; then
				continue
			fi
		done
		
		if ! checkCloudAppUpdated $1; then
			echo "1|拉取云应用更新失败."
			return 1
		fi
        ln -sf $CLOUDAPP_TARGET/*.so* /usr/lib/
        ldconfig
        echo "0|拉取云应用更新成功."
        return 0
}


# 拉取服务重启记录文件
function pull_status(){

        rsync -q -c -azP --port=6393  ${user}@${ipaddress}::status --password-file=$TMP_DIR/pass ${TMP_DIR}/serverstatus/
        if [[ $? -ne 0 ]]; then
                echo "6|拉取serverstatus文件失败."
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

# 刷新业务数据
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

# 退出前清理隐私文件
function clean_exit(){
        test -f $TMP_DIR/pass && rm -f $TMP_DIR/pass
        test -f $HOME/.my.cnf && rm -f $HOME/.my.cnf
        exit $1
}


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


function checkFrontendUpdated(){
	return `rsync -rcn --exclude={'/config/','/data/system/','/debug/'} --port=6393 --password-file=$TMP_DIR/pass --out-format="%n" ${user}@${ipaddress}::frontend $1/ | wc -l`
}

function checkBackendUpdated(){
	return `rsync -rcn --exclude={'/runtime','/application/database.php','/application/admin/config.php','/application/admin/qiniu.config.php'} --port=6393 --password-file=$TMP_DIR/pass --out-format="%n" ${user}@${ipaddress}::backend $1/ | wc -l`
}

function checkCloudAppUpdated(){
	return `rsync -rcn --port=6393 --password-file=$TMP_DIR/pass --out-format="%n" ${user}@${ipaddress}::cloudapp $1/ | wc -l`
}


function mirrorCheck(){
		
	# 镜像环境目录
	MIRROR_PATH=/bby_mirror

	# 副本环境目录
	BACKUP_PATH=/bby_backup

	# 初始化 镜像环境
	cloneOldFiles $MIRROR_PATH

	# 建立副本环境
	rm -rf $BACKUP_PATH
	cloneOldFiles $BACKUP_PATH
	
	# 拉取更新到镜像环境
	pull_backend $MIRROR_PATH/admin_code || { echo "1|对镜像环境前台源码更新的一致性检测失败"; return 1; }
	pull_frontend $MIRROR_PATH/web_code || { echo "2|对镜像环境前台源码更新的一致性检测失败"; return 2; }
	pull_cloudapp $MIRROR_PATH/so || { echo "3|对镜像环境前台源码更新的一致性检测失败"; return 3; }
	
	echo "0|已通过镜像环境的一致性检测"
	return 0
	
}
# 
function pullUpdate(){

	
	#### 开始更新生产环境 ####
	rsync -q -azP $MIRROR_PATH/admin_code/*  $BACKEND_TARGET/
	rsync -q -azP $MIRROR_PATH/web_code/*  $FRONTEND_TARGET/
	rsync -q -azP $MIRROR_PATH/so/*  $CLOUDAPP_TARGET/
	echo "0|完成生产环境的文件更新"
	return 0
}





################# Main ######################

# 判断执行用户
if [[ $EUID -ne 0 ]]; then
        echo "-1|仅允许root用户执行."
        exit 1
fi

# 判断参数合法
if [[ $# -lt 6 ]]; then
        echo "2|传入参数少于6个"
		echo -e "
<参数说明>
param1: 	--- 参与rsync拉取数据时候的用户认证
param2: 	--- 参与rsync拉取数据时候的用户认证
param3: 	--- 指定rsync拉取数据的数据源服务器
param4: 	--- 指定本次脚本执行的任务
param5: 	--- 临时工作目录
</参数说明>"
        exit 2
fi

(type -a rsync || yum -y install rsync fuser) &> /dev/null


user=$1
password=$2
ipaddress=$3
mode=$4
TMP_DIR=$5


# mode合法取值判断
# let match=0
# for MODE in exec_sql refresh_sql stop_grant restore_grant pull_update all; do
	# if [[ $MODE == $mode ]]; then
		# break
	# fi
	# let match+=1
# done 
# if [[ $match -eq 6 ]]; then
	# echo "2|mode参数非法"
	# exit 2
# fi



test -d $TMP_DIR || mkdir -p $TMP_DIR
test -d $TMP_DIR/sql || mkdir -p $TMP_DIR/sql
test -d $TMP_DIR/script || mkdir -p $TMP_DIR/script
test -d $TMP_DIR/serverstatus || mkdir -p $TMP_DIR/serverstatus

FRONTEND_TARGET='/bby/web/www/kod.baibaoyun.com/web_kod'
BACKEND_TARGET='/bby/web/www/admin.baibaoyun.com/snake'
CLOUDAPP_TARGET='/bby/server'

grantBackupPath=/tmp/user.sql



genpasswdtxt
pull_sh || clean_exit $?
pull_status || clean_exit $?

old_ifs=$IFS
IFS='|'
mode=$mode


# 分析mode
for op in $mode; do
			# 执行镜像环境的更新和一致性检测
			if [[ $op == 'mirror_update' ]]; then
				mirrorCheck || clean_exit $?
			fi
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
			# 停止数据库对外授权
			if [[ $op == 'stop_grant' ]]; then
					stopOutConn || clean_exit $?
			fi
			# 恢复数据库用户授权
			if [[ $op == 'restore_grant' ]]; then
					restoreUser || clean_exit 2
			fi
			#  应用更新数据
			if [[ $op == 'pull_update' ]]; then
					pullUpdate || clean_exit $?
			fi

			if [[ $op == 'all' ]]; then
			# 适合集成式服务器
				pull_sql || clean_exit $?
				execsql || clean_exit $?
				mirrorCheck || clean_exit $?
				pullUpdate || clean_exit $?
				stopOutConn || clean_exit $?
				refreshsql || clean_exit $?
				restoreUser || clean_exit $?
			fi
done
IFS="$old_ifs"
echo "0|ok"
clean_exit 0
