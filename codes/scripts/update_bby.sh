#!/bin/bash



GIT_PATH=/bby/git
FRONTEND_GIT_PATH=$GIT_PATH/web_code
BACKEND_GIT_PATH=$GIT_PATH/admin_code
CLOUDAPP_GIT_PATH=$GIT_PATH/so


type -a rsync || yum install -y rsync &> /dev/null

date_string=$(date +%F)



# 更新 前台源码
function update_frontend(){
	rsync -q -c -azP --exclude={'/config/','/data/system/','/debug/'} --delete  ${FRONTEND_GIT_PATH}/ /bby/web/www/kod.baibaoyun.com/web_kod/
	if [[ $? -ne 0 ]]; then
		echo "1|update frontend failed"
		return 1
	fi
	return 0
}


# 更新后台源码
function update_backend(){
	rsync -q -c -azP --exclude={'/runtime','/application/database.php','/application/admin/config.php','/application/admin/qiniu.config.php'} --delete  ${BACKEND_GIT_PATH}/ /bby/web/www/
	if [[ $? -ne 0 ]]; then
		echo "2|update backend failed"
		return 2
	fi
	return 0
}


# 更新云应用
function update_cloudapp(){
	rsync -q -c -azP --delete ${CLOUDAPP_GIT_PATH}/ /bby/server/
	if [[ $? -ne 0 ]]; then
		echo "3|update cloudapp failed"
		return 3
	fi
	return 0
}


# 链接库
function link_libraries(){
	ln -svf /bby/server/*.so.* /usr/lib/
	lddconfig
	if [ $? -ne 0 ]; then
		echo "4|link libararies failed"
		return 4
	fi
	
	return 0
}





function main(){
	update_frontend
	update_backend
	update_cloudapp
	link_libraries
}



test ! -e $GIT_PATH/script/check_version.sh && chmod +x $GIT_PATH/script/check_version.sh
$GIT_PATH/script/check_version.sh
if [ $? -ne 0 ]; then
	echo "5| has updated already"
	exit 5
fi	
main
if [ $? -eq 0 ]; then
	cp -f /bby/git/version.txt /bby/web/www/
	echo "0|OK"
fi










