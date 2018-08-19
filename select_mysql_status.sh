#!/bin/bash

Port=3307                                         //MySQL端口
User="root"                                       //MySQL用户
Password="oldboy123"                              //MySQL用户密码
Mysql_sock="/data/${Port}/mysql.sock"             //mysql.sock随着每次MySQL启动而生成
Mysql_cmd="/application/mysql/bin/mysql -u${User} -p${Password} -S $Mysql_sock -e"  //MySQL非交互命令
Error_file="/tmp/mysql_check_error.log"   //错误输入文件

#source functions libary
. /etc/init.d/functions

#check mysql server    //检查MySQL是否启动
[ -e $Mysql_sock ]||{
  echo "The Mysql server no start"
  exit 1
}

#function ingore errors    //忽略错误函数
skip_errors(){
  array=(1158 1159 1008 1007 1062)
  flag=0
  for num in ${array[*]}
  do
    if [ "$1" = "$num" ];then    //如果有对应的错误号，MySQL就跳过此错误号
       ${Mysql_cmd} "stop slave;set global sql_slave_skip_counter = 1;start slave;"  
       echo "Last_IO_Errno:$1">>$Error_file
    else
       echo "Last_IO_Errno:$1">>$Error_file
       ((flag++))   //如果此错误号不在array数组中，将此错误号写入错误文件中，并循环五次
    fi
  done

  if [ $flag = ${#array[@]} ];then   //发送邮件
     echo "**********`date +%F_%T`************">>$Error_file
     uniq $Error_file|mail -s "Mysql Slave error" 111@111.com 
  fi
}

#check mysql slave  //检查从库是否正常
check_mysql(){
  array1=(`${Mysql_cmd} "show slave status\G"|egrep "Slave_IO_Running|Slave_SQL_Running|Last_SQL_Errno|Seconds_Behind_Master"|awk '{print $NF}'`)
  if [ "${array1[0]}" = "Yes" -a "${array1[1]}" == "Yes" -a "${array1[2]}" = 0 ];then
     action "Mysql Slave" /bin/true
  else
     action "Mysql Slave" /bin/false
     if [ "${array1[0]}" != "Yes" ];then   //将上述错误的列写入到错误文件中
        ${Mysql_cmd} "show slave status\G"|grep "Slave_IO_Running">>$Error_file
     elif [ "${array1[1]}" != "Yes" ];then
        ${Mysql_cmd} "show slave status\G"|grep "Slave_SQL_Running"|grep -v "Slave_SQL_Running_State">>$Error_file
     else [ "${array1[2]}" != 0 ]
        ${Mysql_cmd} "show slave status\G"|grep "Seconds_Behind_Master">>$Error_file
     fi
     skip_errors ${array1[3]}  //发送邮件
  fi
}

main(){
  while true
  do
    check_mysql
    sleep 60
  done
}
main