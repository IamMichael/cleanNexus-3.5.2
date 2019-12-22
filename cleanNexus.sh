#!/bin/bash

# CentOS7.5 Minimal,docker-ce v18.06.0,nexus-3.5.2
# Docker nexus 私有仓库镜像查询、删除、上传、下载
# Author  Michael <user@example.com>

# 参数 variable
# image="image_name:image_version"

# 访问仓库地址
nexus_url="http://192.168.1.102:8081"
registry_url="http://192.168.1.102:8081/repository/test"

# auth 认证用户名密码
auth_user="admin"
auth_passwd="admin123"

# 清理用到的两个 task id
test01_id="e1794158-0bcc-4bbb-81a4-ce8b59661563"
test02_id="e97067db-45ab-47e6-a194-50855f5f6023"


# Script run user
if [[ $UID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Command-line JSON processor
if [[ ! -f /usr/bin/jq ]]; then
  echo "Install jq"
  yum -y install jq > /dev/null 2>&1
fi

# 检测仓库的可用性
function check_registry() {
  curl -s -u ${auth_user}:${auth_passwd} ${registry_url}/v2/_catalog > /dev/null 2>&1 
  if [ $? -eq 0 ]; then
    echo -e "Connect to registry ${registry_url} successfully!"
  else
    echo -e "Connect to registry ${registry_url} failed!"
    exit 1
  fi
}

# 获取镜像和对应版本名列表
function fetch_image_name_version() {
  image_name_list=$(curl -s -u ${auth_user}:${auth_passwd} ${registry_url}/v2/_catalog | jq .repositories | awk -F'"' '{for(i=1;i<=NF;i+=2)$i=""}{print $0}')
  if [[ ${image_name_list} = "" ]]; then
    echo -e "No image found in ${registry_url}!"
    exit 1
  fi
  echo -e "\033[32mAll docker images are listed below:\033[0m"
  for image_name in ${image_name_list};
    do
      image_version_list=$(curl -s -u ${auth_user}:${auth_passwd} ${registry_url}/v2/$image_name/tags/list | jq .tags | awk -F'"' '{for(i=1;i<=NF;i+=2)$i=""}{print $0}')
      for t in $image_version_list;
      do
        echo "${image_name}:${t}"
      done
    done
}

# 删除镜像
function delete_image() {
  for n in ${images};
  do
    image_name=${n%%:*}
    image_version=${n##*:}
    [[ "${image_name}" == "${image_version}" ]] && { image_version=latest; n="$n:latest"; }

    image_digest=`curl -is -u ${auth_user}:${auth_passwd} --header "Accept: application/vnd.docker.distribution.manifest.v2+json" ${registry_url}/v2/${image_name}/manifests/${image_version} | awk '/Digest/ {print $NF}'`

    if [[ -z "${image_digest}" ]]; then
      echo -e "${image_name}:${image_version} does no exist!" 
    else  
      digest_url="${registry_url}/v2/${image_name}/manifests/${image_digest}"
      return_code=$(curl -Is -u ${auth_user}:${auth_passwd} -X DELETE ${digest_url%?} | awk '/HTTP/ {print $2}')
      if [[ ${return_code} -eq 202 ]]; then
        echo "Delete $n successfully!"
        # nexus执行task,垃圾回收 
#        echo "Clean..."
#        curl -u ${auth_user}:${auth_passwd} -H "Content-Type: application/json" -X POST -d '{"action":"coreui_Task","method":"run","data":["${test01_id}"],"type":"rpc","tid":2019}' ${nexus_url}/service/extdirect 
#        sleep 10
#        curl -u ${auth_user}:${auth_passwd} -H "Content-Type: application/json" -X POST -d '{"action":"coreui_Task","method":"run","data":["${test02_id}"],"type":"rpc","tid":2019}' ${nexus_url}/service/extdirect  
      else
        echo -e "Delete $n failed!"
      fi
    fi
  done

# nexus垃圾回收 
#  echo "Clean..."
#  curl -u ${auth_user}:${auth_passwd} -H "Content-Type: application/json" -X POST -d '{"action":"coreui_Task","method":"run","data":["${test01_id}"],"type":"rpc","tid":2019}' ${nexus_url}/service/extdirect
#  curl -u ${auth_user}:${auth_passwd} -H "Content-Type: application/json" -X POST -d '{"action":"coreui_Task","method":"run","data":["${test02_id}"],"type":"rpc","tid":2019}' ${nexus_url}/service/extdirect

}

case "$1" in
  "-h"|"--help")
  echo
  echo "查看帮助信息"
  echo "sh $0 -h"
  echo
  echo "查询仓库所有镜像："
  echo "sh $0 -q"
  echo 
  echo "删除指定镜像语法"
  echo "sh $0 -d image_name1:image_version1 image_name2:image_version2"
  echo "示例：删除 centos:6 centos:7 (镜像名:版本)"
  echo "sh $0 -d centos:6  centos:7"
  echo
;;
  "-d")
  check_registry
  images=${*/-dd/}
  images=${images/-d/}
  delete_image
;;
  "-q")
  check_registry
  fetch_image_name_version
;;
  *)
  echo $"Usage: sh $0 {-h|-q|-d}"
  exit 2
;;
esac

