#!/bin/bash

set -x

# 必需的环境变量列表
REQUIRED_VARS=(
  "GIT_WORKSPACE"
  "ARCH_VER"
  "PROFILE" 
  "ROOTFS_PARTSIZE"
  "ROUTER_IP"
)

# 设置默认值
: ${ROUTER_IP:='192.168.26.1'}
: ${ROOTFS_PARTSIZE:=1024}
: ${FEED_NAME:='third_part'}

# 检查函数
check_env_vars() {
  local missing_vars=()
  
  for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
      missing_vars+=("$var")
    fi
  done

  if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "错误：缺少以下必需环境变量:"
    printf ' - %s\n' "${missing_vars[@]}"
    exit 1
  else
    echo "所有必需环境变量已设置"
  fi
}

# 使用SDK编译包
build_packages() {
    docker run --rm -i -u root\
	-e FEEDNAME=${FEED_NAME} \
	-e FEED_DIR="/home/build/immortalwrt/custom-feeds" \
        -v "${GIT_WORKSPACE}/cache/bin:/home/build/immortalwrt/bin" \
        -v "${GIT_WORKSPACE}/cache/extra-packages:/home/build/immortalwrt/extra-packages" \
        -v "${GIT_WORKSPACE}/cache/feeds:/home/build/immortalwrt/feeds" \
        -v "${GIT_WORKSPACE}/docker_inside/shell:/home/build/immortalwrt/shell" \
        -v "${GIT_WORKSPACE}/cache/envfile:/home/build/immortalwrt/envfile" \
        -v "${GIT_WORKSPACE}/cache/custom-feeds:/home/build/immortalwrt/custom-feeds" \
        immortalwrt/sdk:${ARCH_VER} \
	/bin/bash shell/build-step-1.sh
}

# 构建最终镜像
build_image() {
    test -e "${GIT_WORKSPACE}/board/$PROFILE/arch.conf" && {
	    mkdir -p "${GIT_WORKSPACE}/docker_inside/files/etc/opkg"
	    cp "${GIT_WORKSPACE}/board/$PROFILE/arch.conf" "${GIT_WORKSPACE}/docker_inside/files/etc/opkg/arch.conf"
    }
    docker run --rm -i -u root\
	-e PROFILE=$PROFILE \
	-e ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE\
	-e ROUTER_IP=$ROUTER_IP\
        -v "${GIT_WORKSPACE}/cache/bin:/home/build/immortalwrt/bin" \
        -v "${GIT_WORKSPACE}/docker_inside/shell:/home/build/immortalwrt/shell" \
        -v "${GIT_WORKSPACE}/cache/extra-packages:/home/build/immortalwrt/packages" \
        -v "${GIT_WORKSPACE}/docker_inside/files:/home/build/immortalwrt/files" \
        -v "${GIT_WORKSPACE}/cache/envfile:/home/build/immortalwrt/envfile" \
        immortalwrt/imagebuilder:${ARCH_VER} \
	/bin/bash shell/build-step-2.sh
    rm "${GIT_WORKSPACE}/docker_inside/files/etc/opkg/arch.conf" || true
}

# 主执行流程
check_env_vars
cd ${GIT_WORKSPACE}
build_packages
build_image
echo "构建完成！输出镜像在: ${GIT_WORKSPACE}/docker/bin"

