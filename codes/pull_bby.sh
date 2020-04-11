#!/bin/bash

#description: 从中控服务器拉取网站源码(不含配置文件)
#author: liuliang9835@dingtalk.com


function install_git() {
	yum install -y wget unzip gcc gcc-c++ tcl gettext zlib-devel openssl-devel curl-devel expat-devel perl-ExtUtils-CBuilder perl-ExtUtils-MakeMaker
	test -d git-2.3.0 && rm -rf git-2.3.0
	test -f git_v2.3.0.zip || wget http://gogs.baibaoyun.com:3000/liuliang/packages/raw/master/git_v2.3.0.zip 
	unzip git_v2.3.0.zip && rm -f git_v2.3.0.zip	
	#cd git-2.3.0 && make prefix=/usr/local/git all && make prefix=/usr/local/git install
	make -C git-2.3.0 prefix=/usr/local/git all && make -C git-2.3.0 prefix=/usr/local/git install || return 1
	echo "export PATH=/usr/local/git/bin:$PATH" > /etc/profile.d/git.sh
	rm -rf git-2.3.0
	return 0
}

# 判断执行用户
if [[ $EUID -ne 0 ]]; then
	echo "-1|$0  executed by root only."
	exit -1
fi



# 判断参数合法
if [[ $# -lt 4 ]]; then
	echo "-2|params less than 4"
	exit -2
fi

user=$1
password=$2
url=$3
pullDir=$4

hostinfo=${url#*//}


# 安装git

v=$(git --version 2> /dev/null)
if [[ ! $v =~ '2.3.0' ]]; then
	install_git && source /etc/profile.d/git.sh
	if [[ $? -ne 0 ]]; then
		echo "-4|git install failed"
		exit -4
	fi
	
fi

# 拉取数据

test -d $pullDir && rm -rf $pullDir

git clone http://$user:$password@$hostinfo $pullDir  || ( echo "-5|Git clone failed" && exit -5; )

