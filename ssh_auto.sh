#!/bin/bash
#
# 此脚本用于和目标机器交换ssh key

# Author: pizhicheng@foxmail.com

############################
# DEPENDENCY:
#   expect ssh
# SYNOPSIS:
#   exchange with single machine:
#     ssh_auto.sh [-k key_file] -h target_host -u target_username -p target_password
#   exchange with multiple machine:
#     ssh_auto.sh [-k key_file] -f host_file [-u target_username -p target_password]
# DESCTIPTIONS:
#   this shell is used for exchange ssh keys with target host
# OPTIONS:
#   -k
#     the key file in the localhost [default ~/.ssh/id_rsa]. this file will be auto
#     generate if no exists.
#   -h
#     the target host
#   -u
#     the target host user name
#   -p
#     the target host user password
#   -f
#     the host list file [each line format: host [username password] ]. if username and
#     password is not specified in host file, it will use the input argument followed with
#     -u and -p options
# EXAMPLES:
#   exchange ssh key with one machine:
#      ssh_auto.sh -h 192.168.1.2 -u root -p 123456
#   exchange ssh keys with multiple machine:
#      ssh_auto.sh -f ./host_file
###########################

user_name=''
pass_word=''
host_file=''
host=''
key_file="${HOME}/.ssh/id_rsa"
while getopts "u:p:f:h:k:" opt; do
  case ${opt} in
    u)
      user_name=$OPTARG
      ;;
    p)
      pass_word=$OPTARG
      ;;
    f)
      host_file=$OPTARG
      ;;
    h)
      host=$OPTARG
      ;;
    k)
      key_file=$OPTARG
      ;;
    ?)
      echo <<EOF
############################
# DEPENDENCY:
#   expect ssh
# SYNOPSIS:
#   exchange with single machine:
#     ssh_auto.sh [-k key_file] -h target_host -u target_username -p target_password
#   exchange with multiple machine:
#     ssh_auto.sh [-k key_file] -f host_file [-u target_username -p target_password]
# DESCTIPTIONS:
#   this shell is used for exchange ssh keys with target host
# OPTIONS:
#   -k
#     the key file in the localhost [default ~/.ssh/id_rsa]. this file will be auto
#     generate if no exists.
#   -h
#     the target host
#   -u
#     the target host user name
#   -p
#     the target host user password
#   -f
#     the host list file [each line format: host [username password] ]. if username and
#     password is not specified in host file, it will use the input argument followed with
#     -u and -p options
# EXAMPLES:
#   exchange ssh key with one machine:
#      ssh_auto.sh -h 192.168.1.2 -u root -p 123456
#   exchange ssh keys with multiple machine:
#      ssh_auto.sh -f ./host_file
###########################
EOF
    exit 0;
    ;;
  esac
done

[[ ! -f ${key_file}.pub ]] && echo y | ssh-keygen -t rsa -P '' -f ${key_file}  # 密钥对不存在则创建密钥
if [[ -n ${host_file} ]]; then
  while read host username password; do
    if [[ -z ${host} ]]; then
      continue;
    fi
    if [[ -z ${username} ]]; then
      username=${user_name}
    fi
    if [[ -z ${password} ]]; then
      password=${pass_word}
    fi
    if [ -z ${username} -o -z ${password} ]; then
      err "no username and password in host file and argument"
      exit 1;
    fi
    expect -c " spawn ssh-copy-id -i ${key_file}.pub ${username}@${host}
expect {
  \"yes/no\" {send \"yes\n\"; exp_continue }
  \"password\" { send \"${password}\r\"; exp_continue }
  eof
}"
  done < ${host_file}      # 读取存储ip的文件
elif [[ -n ${host} ]]; then
  expect -c " spawn ssh-copy-id -i ${key_file}.pub ${user_name}@${host}
expect {
  \"yes/no\" {send \"yes\n\"; exp_continue }
  \"password\" { send \"${pass_word}\r\"; exp_continue }
  eof
}"
else
  err "no hosts input"
fi

# output error message. code from https://zh-google-styleguide.readthedocs.io/en/latest/google-shell-styleguide/environment/
err() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}
