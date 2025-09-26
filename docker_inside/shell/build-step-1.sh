#!/bin/bash

set -e

GROUP=

group() {
	endgroup
	echo "::group::  $1"
	GROUP=1
}

endgroup() {
	if [ -n "$GROUP" ]; then
		echo "::endgroup::"
	fi
	GROUP=
}

trap 'endgroup' ERR

# snapshot containers don't ship with the SDK to save bandwidth
# run setup.sh to download and extract the SDK
[ ! -f setup.sh ] || bash setup.sh

chmod a+x shell/diy-step-1.sh
./shell/diy-step-1.sh
. ./envfile/custom-packages.env

FEEDNAME="${FEEDNAME:-action}"
BUILD_LOG="${BUILD_LOG:-1}"
SKIP_PREFIX="- luci-i18n-"

check_build() {
    for SKIP_ONE in $SKIP_PREFIX; do
		if [[ "$1" == "$SKIP_ONE"* ]]; then
			return 1
		fi
	done
	return 0
}

if [ -z "$NO_DEFAULT_FEEDS" ]; then
	cat feeds.conf.default >> feeds.conf
fi

echo "src-link $FEEDNAME ${FEED_DIR}" >> feeds.conf

ALL_CUSTOM_FEEDS="$FEEDNAME "
for EXTRA_FEED in $EXTRA_FEEDS; do
	echo "$EXTRA_FEED" | tr '|' ' ' >> feeds.conf
	ALL_CUSTOM_FEEDS+="$(echo "$EXTRA_FEED" | cut -d'|' -f2) "
done

group "feeds.conf"
cat feeds.conf
endgroup

group "feeds update -a"
./scripts/feeds update -a
endgroup

group "make defconfig"
make defconfig
endgroup

if [ -z "$CUSTOM_PACKAGES" ]; then
	# compile all packages in feed
	for FEED in $ALL_CUSTOM_FEEDS; do
		group "feeds install -p $FEED -f -a"
		./scripts/feeds install -p "$FEED" -f -a
		endgroup
	done

	RET=0

	make \
		BUILD_LOG="$BUILD_LOG" \
		IGNORE_ERRORS="$IGNORE_ERRORS" \
		CONFIG_AUTOREMOVE=y \
		V="$V" \
		-j "$(nproc)" || RET=$?
else
	# compile specific packages with checks
	for PKG in $CUSTOM_PACKAGES; do
		check_build "$PKG" || continue
		for FEED in $ALL_CUSTOM_FEEDS; do
			group "feeds install -p $FEED -f $PKG"
			./scripts/feeds install -p "$FEED" -f "$PKG"
			endgroup
		done

		if [ -n "${SRC_CHECK}" ];then
			group "make package/$PKG/download"
			make \
				BUILD_LOG="$BUILD_LOG" \
				IGNORE_ERRORS="$IGNORE_ERRORS" \
				"package/$PKG/download" V=s
			endgroup

			group "make package/$PKG/check"
			make \
				BUILD_LOG="$BUILD_LOG" \
				IGNORE_ERRORS="$IGNORE_ERRORS" \
				"package/$PKG/check" V=s 2>&1 | \
					tee logtmp
			endgroup

			RET=${PIPESTATUS[0]}

			if [ "$RET" -ne 0 ]; then
				echo_red   "=> Package check failed: $RET)"
				exit "$RET"
			fi

			badhash_msg="HASH does not match "
			badhash_msg+="|HASH uses deprecated hash,"
			badhash_msg+="|HASH is missing,"
			if grep -qE "$badhash_msg" logtmp; then
				echo "Package HASH check failed"
				exit 1
			fi
		fi

		PATCHES_DIR=$(find ${FEED_DIR} -path "*/$PKG/patches")
		if [ -d "$PATCHES_DIR" ] && [ -n "${REFRESH_CHECK}" ]; then
			group "make package/$PKG/refresh"
			make \
				BUILD_LOG="$BUILD_LOG" \
				IGNORE_ERRORS="$IGNORE_ERRORS" \
				"package/$PKG/refresh" V=s
			endgroup

			if ! git -C "$PATCHES_DIR" diff --quiet -- .; then
				echo "Dirty patches detected, please refresh and review the diff"
				git -C "$PATCHES_DIR" checkout -- .
				exit 1
			fi

			group "make package/$PKG/clean"
			make \
				BUILD_LOG="$BUILD_LOG" \
				IGNORE_ERRORS="$IGNORE_ERRORS" \
				"package/$PKG/clean" V=s
			endgroup
		fi

		FILES_DIR=$(find ${FEED_DIR} -path "*/$PKG/files")
		if [ -d "$FILES_DIR" ] && [ -n "${SHFMT_CHECK}" ]; then
			find "$FILES_DIR" -name "*.init" -exec shfmt -w -sr -s '{}' \;
			if ! git -C "$FILES_DIR" diff --quiet -- .; then
				echo "init script must be formatted. Please run through shfmt -w -sr -s"
				git -C "$FILES_DIR" checkout -- .
				exit 1
			fi
		fi

	done

	RET=0

	for PKG in $CUSTOM_PACKAGES; do
	    check_build "$PKG" || continue
		make \
			BUILD_LOG="$BUILD_LOG" \
			IGNORE_ERRORS="$IGNORE_ERRORS" \
			CONFIG_AUTOREMOVE=y \
			V="$V" \
			-j "$(nproc)" \
			"package/$PKG/compile" || {
				RET=$?
				break
			}
	done
fi

if [ "$INDEX" = '1' ];then
	group "make package/index"
	make package/index
	endgroup
fi

find "bin/packages" -type f -path "*/$FEEDNAME/*" -exec cp '{}' "extra-packages/" \;

exit "$RET"
