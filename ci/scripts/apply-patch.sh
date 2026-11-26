#!/usr/bin/env bash
# 补丁：configs/<target>.config 中 luci-app-pon -> luci-app-onu / luci-i18n-pon -> luci-i18n-onu
# 背景：pon_userspace feed（naoki66/OpenWrt_ONU_CONFIG）已把包改名为 luci-app-onu，
#       底板 an7583.config 仍写 CONFIG_PACKAGE_luci-app-pon=y，是死符号，不打则 ONU 页缺失。
# 幂等：已打过直接退出 0；patch 失败自动回退 sed 精确替换，结尾强校验。
#
# 用法: apply-patch.sh <源码根> [target]     target 默认 an7583
set -euo pipefail

SRC="${1:-.}"
TARGET="${2:-an7583}"
CFG="$SRC/configs/${TARGET}.config"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/../patches/0001-an7583-rename-package-luci-app-pon-to-luci-app-onu.patch"

[ -f "$CFG" ] || { echo "[patch] 缺少 $CFG"; exit 1; }

if ! grep -q '^CONFIG_PACKAGE_luci-app-pon=y$' "$CFG" && ! grep -q '^CONFIG_PACKAGE_luci-i18n-pon-zh-cn=y$' "$CFG"; then
    echo "[patch] $CFG 已是 onu 命名，跳过"
    exit 0
fi

if [ "$TARGET" = "an7583" ] && patch -p1 --forward --dry-run -d "$SRC" < "$PATCH" >/dev/null 2>&1; then
    patch -p1 --forward -d "$SRC" < "$PATCH"
    echo "[patch] git style patch 应用成功"
else
    echo "[patch] patch 预览失败或不适用于 $TARGET，改用精确替换"
    sed -i \
        -e 's/^CONFIG_PACKAGE_luci-app-pon=y$/CONFIG_PACKAGE_luci-app-onu=y/' \
        -e 's/^CONFIG_PACKAGE_luci-i18n-pon-zh-cn=y$/CONFIG_PACKAGE_luci-i18n-onu-zh-cn=y/' \
        "$CFG"
fi

grep -q '^CONFIG_PACKAGE_luci-app-pon=y$' "$CFG" && { echo "[patch] 失败：仍存在 luci-app-pon=y"; exit 1; }
grep -q '^CONFIG_PACKAGE_luci-app-onu=y$' "$CFG" || { echo "[patch] 失败：未写入 luci-app-onu"; exit 1; }
grep -q '^CONFIG_PACKAGE_luci-i18n-onu-zh-cn=y$' "$CFG" || echo "[patch] 警告：未写入 luci-i18n-onu-zh-cn"
echo "[patch] 校验通过"
