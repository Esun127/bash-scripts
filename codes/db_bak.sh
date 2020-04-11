#!/bin/bash


## description: 数据库日备份脚本
## author: liuliang9835@dingtalk.com

export PATH=/bby_install/server/mysql/bin:$PATH


BackupPath="/bby_database/databak/mysql/backup"
suffix=$(date +%Y%m%d_%H)




function logger(){
	
	logPath=/var/log/${0//.sh/.log}
	if [[ $# -lt 2 ]]; then
		return 1
	fi
	
	dbname=$1
	flag=$2
	
	printf "%-15s : %-15s - %3s\n" $suffix $dbname $flag >> $logPath
	
}

test -d $BackupPath || mkdir $BackupPath


cat > $HOME/.my.cnf <<\EOF
[client]
user=bbyepdb001
password=bbyepdb$001
host=10.27.210.207
port=3908
EOF

MainDbBackupFile="bbyep_main_db_${suffix}.sql"
accessBackupFile="bbyep_access_db_${suffix}.sql" 
form_bbyBackupFile="bbyep_formreport_db_${suffix}.sql"
webMsgBackupFile="bbyep_webmsg_db_${suffix}.sql"

common_opts="-E -R --triggers --single-transaction"


# 备份 百宝云主数据库
{ mysqldump $common_opts --databases bbyep_main_db --ignore-table=baibaoyun_main.t_cloud_api_msg_new --ignore-table=baibaoyun_main.t_cloud_tempfile --ignore-table=baibaoyun_main.t_login_log --ignore-table=baibaoyun_main.t_msg_app --ignore-table=baibaoyun_main.t_msg_app_new > "$BackupPath/$MainDbBackupFile" && logger bbyep_main_db yes || logger bbyep_main_db no; } 2> /dev/null

 # 备份 访问统计数据库
{ mysqldump $common_opts --databases bbyep_access_db > "$BackupPath/$accessBackupFile" && logger bbyep_access_db yes || logger bbyep_access_db no; } 2> /dev/null

 # 备份 表单系统数据库
{ mysqldump $common_opts --skip-opt --skip-comments --complete-insert --databases bbyep_formreport_db >"$BackupPath/$form_bbyBackupFile" && logger bbyep_formreport_db yes || logger bbyep_formreport_db no; } &> /dev/null

# 备份 百宝云消息数据库
{ mysqldump $common_opts --databases bbyep_webmsg_db > "$BackupPath/$webMsgBackupFile" && logger bbyep_webmsg_db yes || logger bbyep_webmsg_db no; } 2> /dev/null


\rm -f $HOME/.my.cnf

# 删除5天前的备份文件
find "$BackupPath" -name "bbyep_*[log,sql]" -type f -mtime +5 -exec rm -rf {} \;

