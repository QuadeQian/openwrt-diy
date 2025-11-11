#!/bin/bash

[[ "${FEED_DIR}" =~ ^/ ]] || {
	echo "Feed dir is invalid"
	exit 1
}

rm -rf ${FEED_DIR}/* 
mkdir -p ${FEED_DIR}

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ${FEED_DIR}/
  cd .. && rm -rf $repodir
}

# 晶晨宝盒
# git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
# sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/QuadeQian/openwrt-diy'|g" ${FEED_DIR}/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" ${FEED_DIR}/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|ARMv8|OWRT-$PROFILE|g" ${FEED_DIR}/luci-app-amlogic/root/etc/config/amlogic
# CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# iStore
# git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui 
# git_sparse_clone main https://github.com/linkease/istore luci 
# CUSTOM_PACKAGES="$CUSTOM_PACKAGES app-store-ui luci-app-store luci-i18n-store-zh-cn"

# 测速插件
git_sparse_clone master https://github.com/sirpdboy/luci-app-netspeedtest homebox netspeedtest luci-app-netspeedtest
CUSTOM_PACKAGES="$CUSTOM_PACKAGES homebox netspeedtest luci-app-netspeedtest luci-i18n-netspeedtest-zh-cn"

# easytier
git_sparse_clone main https://github.com/EasyTier/luci-app-easytier easytier luci-app-easytier
CUSTOM_PACKAGES="$CUSTOM_PACKAGES easytier luci-app-easytier luci-i18n-easytier-zh-cn"

echo "CUSTOM_PACKAGES=\"$CUSTOM_PACKAGES\"" > ./envfile/custom-packages.env
