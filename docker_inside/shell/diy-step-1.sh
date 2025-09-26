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
  destdir=$(basename "$repourl" .git)
  test "$destdir" == "$@" && destdir="${FEED_DIR}" || destdir="${FEED_DIR}/$destdir"
  test -d $destdir || mkdir -p $destdir
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ $destdir
  cd .. && rm -rf $repodir
}

# Themes
#git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon ${FEED_DIR}/luci-theme-argon
#git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config ${FEED_DIR}/luci-app-argon-config
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-theme-argon luci-app-argon-config"

# 晶晨宝盒
git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/QuadeQian/openwrt-diy'|g" ${FEED_DIR}/luci-app-amlogic/root/etc/config/amlogic
# sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" ${FEED_DIR}/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|ARMv8|OWRT|g" ${FEED_DIR}/luci-app-amlogic/root/etc/config/amlogic
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-amlogic"

# iStore
#git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui 
#git_sparse_clone main https://github.com/linkease/istore luci 
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES app-store-ui taskd luci-lib-taskd luci-lib-xterm luci-app-store"

# 测速插件
git_sparse_clone lua https://github.com/sirpdboy/luci-app-netspeedtest homebox luci-app-netspeedtest
CUSTOM_PACKAGES="$CUSTOM_PACKAGES homebox luci-app-netspeedtest"

# turboacc
git_sparse_clone luci https://github.com/chenmozhijin/turboacc luci-app-turboacc
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-turboacc"

echo "CUSTOM_PACKAGES=\"$CUSTOM_PACKAGES\"" > ./envfile/custom-packages.env

