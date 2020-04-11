#!/bin/bash


GIT_PATH=/bby/git


# 读取当前运行的版本串
test -f /bby/web/www/version.txt && cur_version=$(tail -1 /bby/web/www/version.txt) || cur_version=$(curl -sk https://127.0.0.1:446/user/login?refurl=https://127.0.0.1/ | grep 'site_code_ver' | cut -d ':' -f 2 | sed 's/[" ]//g')


# 读取新版本串
test -f /bby/git/version.txt && new_version=$(tail -1 $GIT_PATH/version.txt)



cur_index=`nl $GIT_PATH/version.txt | grep "$cur_version" | awk '{ print $1}'`
new_index=`nl $GIT_PATH/version.txt | tail -1 | awk '{ print $1}'`

if [[ $new_index -le $cur_index ]]; then
	# 不需要进行重启
	echo "1|needn't restart"
	exit 1
	
fi	




# 获取新版本服务状态文件
status_file="$GIT_PATH/serverstatus/${new_version}.txt"

test ! -f $status_file && echo "2|missing serverstatus" && exit 2

let count=0
while read line; do
	# 获取需要重启的服务
	name=$(echo $line | cut -d '-' -f 1)
	if [[ ! -x /etc/init.d/$name ]]; then
		cp -a $GIT_PATH/script/$name /etc/init.d/$name
	fi

	# 获取需要重启的时间
	timestring=$(echo $line | cut -d '-' -f 2)
	
	# 如果状态文件有给定时间
	if [[ $timestring != $name ]]; then
	
		# 时间为now时立即重启
		if [[ $timestring == "now" ]]; then
				/etc/init.d/$name restart
				if [ $? -ne 0 ]; then
					echo "1|$name restart failed"
					let count++
				fi
		else
		# 则将时间写入crontab做单次定时重启
			if ! service crond status &> /dev/null; then
				service crond start
			fi
			
			# 判断约定时间是否当天已经过去
			sethour=`echo $timestring|cut -d':' -f1`
			setmin=`echo $timestring|cut -d':' -f2`
			if [[ $setmin -gt 60 ]]; then
				setmin=30
			fi
			if [[ $sethour -gt 24 ]]; then
				sethour=03
			fi
			hour=`date +%H`
			if [[ $hour -gt $sethour ]]; then
				dm=`date -d tomorrow "+%d %m"`
			else
				dm=`date "+%d %m"`
			fi				
			echo "$setmin $sethour $dm /etc/init.d/$name restart" >> /var/spool/cron/root
		fi
	fi
done < $status_file

if [[ $count -ne 0 ]]; then
	echo "$count| there are $count services restarted failed right now."
	exit $count
fi


