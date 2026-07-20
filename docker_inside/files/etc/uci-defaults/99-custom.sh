#!/bin/sh
# /etc/uci-defaults/99-custom.sh
# chmod 644

# ===== 日志重定向 =====
exec >/tmp/99-custom.log 2>&1

echo "=========================================="
echo "uci-defaults: 99-custom.sh started"
echo "Date: $(date)"
echo "=========================================="

# ===== 0. 防重复执行（独立命名，避免冲突）=====
FLAG="/etc/config/.uci-defaults-custom-quade"
if [ -f "$FLAG" ]; then
    echo "[SKIP] Already initialized, exiting."
    exit 0
fi

# ===== 1. 定义变量（重点：LAN IP 可随意改）=====
# 获取打包时传入的自定义配置
source /etc/custom_vars.txt || true

CUSTOM_IP="${CUSTOM_IP:-192.168.26.1}"
TIMEZONE="CST-8"
ZONENAME="Asia/Shanghai"
AUTHOR="Built by Quade"

echo "[INFO] Variables loaded:"
echo "  CUSTOM_IP=$CUSTOM_IP"

# ===== 2. 读取固件版本（运行期正确方式）=====
if [ -f /etc/openwrt_release ]; then
    . /etc/openwrt_release
    echo "[INFO] DISTRIB_RELEASE=$DISTRIB_RELEASE"
    echo "[INFO] DISTRIB_ID=$DISTRIB_ID"
else
    echo "[WARN] /etc/openwrt_release not found"
fi

# ===== 3. 切换 USTC 源 =====
if [ -f /etc/apk/repositories.d/distfeeds.list ]; then
    echo "[INFO] Switching apk repos to USTC..."
    sed -i.bak \
        -e 's|https://downloads.immortalwrt.org|https://mirrors.ustc.edu.cn/immortalwrt|g' \
        -e 's|https://downloads.openwrt.org|https://mirrors.ustc.edu.cn/openwrt|g' \
        /etc/apk/repositories.d/distfeeds.list
elif [ -f /etc/opkg/distfeeds.conf ]; then
    echo "[INFO] Switching opkg repos to USTC..."
    sed -i.bak \
        -e 's|https://downloads.immortalwrt.org|https://mirrors.ustc.edu.cn/immortalwrt|g' \
        -e 's|https://downloads.openwrt.org|https://mirrors.ustc.edu.cn/openwrt|g' \
        /etc/opkg/distfeeds.conf
else
    echo "[WARN] No repo config found"
fi

# ===== 4. 系统基础配置（逐条 uci set，支持变量）=====
echo "[INFO] Writing system config..."
uci -q set system.@system[0].timezone="$TIMEZONE"
uci -q set system.@system[0].zonename="$ZONENAME"
uci -q set system.@system[0].description="$AUTHOR"
uci -q commit system

# ===== 5. LAN IP 配置（变量注入，必须 static）=====
echo "[INFO] Setting LAN IP to $CUSTOM_IP..."
uci -q set network.lan.proto="static"
uci -q set network.lan.ipaddr="$CUSTOM_IP"
uci -q set network.lan.netmask="255.255.255.0"
uci -q commit network

# ===== 6. NTP 静态解析（Android TV 友好）=====
echo "[INFO] Adding NTP static record..."
uci -q add dhcp domain
uci -q set dhcp.@domain[-1].name="time.android.com"
uci -q set dhcp.@domain[-1].ip="203.107.6.88"
uci -q commit dhcp

# ===== 7. 完成标记 =====
touch "$FLAG"
echo "[INFO] Initialization complete."
echo "=========================================="
echo "Finished at: $(date)"
echo "=========================================="

exit 0

