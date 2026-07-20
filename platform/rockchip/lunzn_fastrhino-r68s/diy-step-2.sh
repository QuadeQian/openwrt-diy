#!/bin/bash

PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-mwan3-zh-cn"
PACKAGES="$PACKAGES luci-i18n-sqm-zh-cn"
PACKAGES="$PACKAGES luci-i18n-adguardhome-zh-cn"
PACKAGES="$PACKAGES luci-i18n-advanced-reboot-zh-cn"

# ===== EasyTier 自动获取（基于 IMAGEBUILDER_TAG）=====
# 解析 tag: x86-64-openwrt-25.12 → PLATFORM=x86, ARCH=64, VERSION=25.12
if [ -n "$IMAGEBUILDER_TAG" ]; then
    PLATFORM=$(echo "$IMAGEBUILDER_TAG" | cut -d'-' -f1)
    ARCH=$(echo "$IMAGEBUILDER_TAG" | cut -d'-' -f2)
    OWRT_VERSION=$(echo "$IMAGEBUILDER_TAG" | sed 's/.*-openwrt-//')
fi

# 判断 apk/ipk（25.12 为界）
USE_APK=0
if echo "$OWRT_VERSION" | awk -F. '{if ($1>25 || ($1==25 && $2>=12)) exit 0; else exit 1}'; then
    USE_APK=1
fi

# 映射 EasyTier 架构命名（横杠转下划线）
ET_ARCH=$(echo "${PLATFORM}_${ARCH}" | tr '-' '_')
case "$ET_ARCH" in
    x86_64) ET_ARCH="x86_64" ;;
    rockchip_*) ET_ARCH="aarch64_generic" ;;
    bcm27xx_*) ET_ARCH="aarch64_cortex-a72" ;;
    sunxi_*) ET_ARCH="aarch64_cortex-a53" ;;
    mt7622_*) ET_ARCH="aarch64_cortex-a53" ;;
    ramips_*) ET_ARCH="mipsel_24kc" ;;
esac

# 下载 EasyTier（latest 版）
ET_TAG=$(curl -fsSL https://api.github.com/repos/EasyTier/luci-app-easytier/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
ET_VER=${ET_TAG#v}
SUFFIX=$([ $USE_APK -eq 1 ] && echo "SNAPSHOT" || echo "${OWRT_VERSION%.*}.0")
ASSET="EasyTier-v${ET_VER}-${ET_ARCH}-${SUFFIX}.zip"
URL="https://github.com/EasyTier/luci-app-easytier/releases/download/${ET_TAG}/${ASSET}"

echo "[EasyTier] Downloading: $URL"
TMP=$(mktemp -d) && cd $TMP
curl -fL --retry 3 "$URL" -o et.zip && unzip -q et.zip
cp *.${USE_APK:+apk}${USE_APK:-ipk} /home/build/immortalwrt/packages/ 2>/dev/null && {
  # 追加到 PACKAGES
  PACKAGES="$PACKAGES luci-app-easytier luci-i18n-easytier-zh-cn easytier kmod-tun"
  echo "[EasyTier] Done. Tag=$IMAGEBUILDER_TAG Arch=$ET_ARCH APK=$USE_APK"
}
cd - >/dev/null && rm -rf $TMP


echo "PACKAGES=\"$PACKAGES\"" >> ./envfile/custom-packages.env
