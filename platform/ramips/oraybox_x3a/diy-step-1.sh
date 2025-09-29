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

# turboacc
git_sparse_clone luci https://github.com/chenmozhijin/turboacc luci-app-turboacc
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-turboacc luci-i18n-turboacc-zh-cn"

echo "CUSTOM_PACKAGES=\"$CUSTOM_PACKAGES\"" > ./envfile/custom-packages.env
