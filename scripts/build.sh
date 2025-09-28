#!/bin/bash

set -e

# 必需的环境变量列表
REQUIRED_VARS=(
  "GIT_WORKSPACE"
  "TARGET_ARCH"
  "TARGET_PLATFORM"
  "OWRT_VERSION"
  "PROFILE" 
  "ROOTFS_PARTSIZE"
  "ROUTER_IP"
)

# 设置默认值
: ${ROUTER_IP:='192.168.26.1'}
: ${ROOTFS_PARTSIZE:='0'}
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

init_env() {
	mkdir -p output
	cp -rf platform/${TARGET_PLATFORM}/${PROFILE}/diy-step-*.sh docker_inside/shell/ || {
		echo "请在 platform/${TARGET_PLATFORM}/${PROFILE} 放入diy脚本"
		return 1
	}
}

# 使用SDK编译包
build_packages() {
    docker run --rm -i -u root\
	-e V=s \
	-e FEEDNAME=${FEED_NAME} \
	-e FEED_DIR="/home/build/immortalwrt/custom-feeds" \
	-v "${GIT_WORKSPACE}/cache/bin:/home/build/immortalwrt/bin" \
	-v "${GIT_WORKSPACE}/cache/extra-packages:/home/build/immortalwrt/extra-packages" \
	-v "${GIT_WORKSPACE}/cache/feeds:/home/build/immortalwrt/feeds" \
	-v "${GIT_WORKSPACE}/docker_inside/shell:/home/build/immortalwrt/shell" \
	-v "${GIT_WORKSPACE}/cache/envfile:/home/build/immortalwrt/envfile" \
	-v "${GIT_WORKSPACE}/cache/custom-feeds:/home/build/immortalwrt/custom-feeds" \
	immortalwrt/sdk:${TARGET_PLATFORM}-${TARGET_ARCH}-openwrt-${OWRT_VERSION} \
	/bin/bash shell/build-step-1.sh
	cp -rf cache/extra-packages/* output/
}

# 构建最终镜像
build_image() {
    rm "${GIT_WORKSPACE}/docker_inside/files/etc/opkg/arch.conf" || true
	rm "${GIT_WORKSPACE}/docker_inside/files/etc/custom_vars.txt" || true
    test -e "${GIT_WORKSPACE}/board/$PROFILE/arch.conf" && {
	    mkdir -p "${GIT_WORKSPACE}/docker_inside/files/etc/opkg"
	    cp "${GIT_WORKSPACE}/board/$PROFILE/arch.conf" "${GIT_WORKSPACE}/docker_inside/files/etc/opkg/arch.conf"
    }
	mkdir -p "${GIT_WORKSPACE}/docker_inside/files/etc"
	echo "CUSTOM_IP=${ROUTER_IP}" >> ${GIT_WORKSPACE}/docker_inside/files/etc/custom_vars.txt
    docker run --rm -i -u root\
	-e PROFILE=$PROFILE \
	-e ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE\
	-v "${GIT_WORKSPACE}/cache/bin:/home/build/immortalwrt/bin" \
	-v "${GIT_WORKSPACE}/docker_inside/shell:/home/build/immortalwrt/shell" \
	-v "${GIT_WORKSPACE}/cache/extra-packages:/home/build/immortalwrt/packages" \
	-v "${GIT_WORKSPACE}/docker_inside/files:/home/build/immortalwrt/files" \
	-v "${GIT_WORKSPACE}/cache/envfile:/home/build/immortalwrt/envfile" \
	immortalwrt/imagebuilder:${TARGET_PLATFORM}-${TARGET_ARCH}-openwrt-${OWRT_VERSION} \
	/bin/bash shell/build-step-2.sh
	cp -rf cache/bin/targets/${TARGET_PLATFORM}/${TARGET_ARCH}/* output/
}

# 主执行流程
check_env_vars
cd ${GIT_WORKSPACE}
init_env
build_packages
build_image
echo "构建完成！输出镜像在: ${GIT_WORKSPACE}/docker/bin"

