#!/usr/bin/env bash
# 校验 make defconfig 之后的 .config 是否保住了预期符号。
# OpenWrt 的 make defconfig 会静默丢弃「依赖不满足 / feed 里不存在」的包，
# 看到编译成功并不代表插件真的进了镜像，所以本步不能省。
#
# 用法: PRESET=full|base verify-config.sh .config
#   full（默认）= 底板 + release.config 全量插件
#   base        = 仅底板，只校验 PON 相关关键符号
# 退出码：0 通过或仅警告；2 关键符号不符（必须修）
set -uo pipefail

CONFIG_FILE="${1:-.config}"
PRESET="${PRESET:-full}"
[ -f "$CONFIG_FILE" ] || { echo "[verify] 找不到 $CONFIG_FILE"; exit 1; }

CORE=(
  CONFIG_PACKAGE_luci-app-onu
  CONFIG_PACKAGE_luci-app-pon-status
  CONFIG_PACKAGE_kmod-airoha-xpon
  CONFIG_PACKAGE_airoha-ponctl
)
FULL=(
  CONFIG_PACKAGE_luci-app-airoha-npu
  CONFIG_PACKAGE_ponwrt-defaults
  CONFIG_PACKAGE_luci-app-openclash
  CONFIG_PACKAGE_luci-proto-wireguard
  CONFIG_PACKAGE_wireguard-tools
  CONFIG_PACKAGE_kmod-wireguard
  CONFIG_PACKAGE_ddns-go
  CONFIG_PACKAGE_luci-app-ddns-go
  CONFIG_PACKAGE_adguardhome
  CONFIG_PACKAGE_luci-app-adguardhome
  CONFIG_PACKAGE_luci-app-upnp
  CONFIG_PACKAGE_kmod-nft-offload
  CONFIG_PACKAGE_kmod-nft-tproxy
  CONFIG_PACKAGE_kmod-nf-conntrack-bridge
  CONFIG_PACKAGE_kmod-tcp-bbr
)
FORBIDDEN=(
  CONFIG_PACKAGE_luci-app-pon
  CONFIG_PACKAGE_luci-app-ddns
  CONFIG_PACKAGE_ddns-scripts
)

REQUIRED=("${CORE[@]}")
[ "$PRESET" = "full" ] && REQUIRED+=("${FULL[@]}")

hard=0
printf '%-52s %-9s %s\n' "SYMBOL" "STATE" "RESULT"
printf '%s\n' "------------------------------------------------------------------------"
for s in "${REQUIRED[@]}"; do
  if grep -qx "${s}=y" "$CONFIG_FILE"; then
    printf '%-52s %-9s %s\n' "$s" "y" "OK"
  else
    printf '%-52s %-9s %s\n' "$s" "-" "MISSING"
    case "$s" in
      CONFIG_PACKAGE_luci-app-onu|CONFIG_PACKAGE_luci-app-pon-status|CONFIG_PACKAGE_kmod-airoha-xpon|CONFIG_PACKAGE_airoha-ponctl) hard=1 ;;
    esac
  fi
done
for s in "${FORBIDDEN[@]}"; do
  if grep -qx "${s}=y" "$CONFIG_FILE"; then
    printf '%-52s %-9s %s\n' "$s" "y" "SHOULD-BE-OFF"; hard=1
  else
    printf '%-52s %-9s %s\n' "$s" "-" "OK"
  fi
done

echo
if [ "$hard" -eq 1 ]; then
  cat <<'EOF2'
[verify] 关键符号不符，禁止出货。排查顺序：
  1) feeds 是否装全：./scripts/feeds install -a 是否报 "package ... not found"
  2) pon_userspace feed 是否含 luci-app-onu：ls feeds/pon_userspace/luci-app-onu
  3) 补丁是否生效：grep luci-app-onu configs/an7583.config
  4) 依赖是否被裁：grep -E "omcproxy|airoha-ponctl|ppp-mod-pppoe" .config
EOF2
  exit 2
fi

echo "[verify] 通过（PRESET=$PRESET）。非关键符号若 MISSING，说明该插件被 defconfig 裁掉，核对 feeds 后再决定是否放行。"
exit 0
