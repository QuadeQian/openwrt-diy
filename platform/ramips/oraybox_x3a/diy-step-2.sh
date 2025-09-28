#!/bin/bash

PACKAGES="base-files block-mount ca-bundle default-settings-chn dnsmasq-full dropbear firewall4 fstools"
PACKAGES="$PACKAGES kmod-crypto-hw-eip93 kmod-gpio-button-hotplug kmod-leds-gpio kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload"
PACKAGES="$PACKAGES libc libgcc libustream-openssl logd luci-app-package-manager luci-compat luci-lib-base luci-lib-ipkg luci-light"
PACKAGES="$PACKAGES mtd netifd nftables odhcp6c odhcpd-ipv6only opkg ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch"
PACKAGES="$PACKAGES urandom-seed urngd wpad-openssl kmod-mt7615-firmware -uboot-envtools"
PACKAGES="$PACKAGES luci-theme-argon"
echo "PACKAGES=\"$PACKAGES\"" >> ./envfile/custom-packages.env
