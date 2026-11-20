#!/usr/bin/env bash
# 앱 아이콘·스플래시 PNG 를 assets/branding/source/*.svg 에서 다시 만든다 (Chrome 헤드리스로 렌더링).
# 원본은 데스크톱 앱(stock-manager) 의 build/appicon.svg · frontend/images/brand-mark.svg.
# 만든 뒤: dart run flutter_launcher_icons && dart run flutter_native_splash:create
set -euo pipefail

cd "$(dirname "$0")/.."
SRC=assets/branding/source
OUT=assets/branding
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# render <svg> <png> <캔버스 px> [그림 px]  (그림이 작으면 캔버스 가운데, 나머지는 투명)
render() {
  local svg=$1 png=$2 canvas=$3 size=${4:-$3}
  local pad=$(((canvas - size) / 2))
  cp "$SRC/$svg" "$TMP/$svg"
  cat >"$TMP/page.html" <<EOF
<!doctype html><html><body style="margin:0;background:transparent">
<img src="$svg" width="$size" height="$size" style="display:block;margin:${pad}px">
</body></html>
EOF
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --default-background-color=00000000 --force-device-scale-factor=1 \
    --window-size="$canvas,$canvas" --screenshot="$TMP/out.png" "file://$TMP/page.html" >/dev/null 2>&1
  mv "$TMP/out.png" "$OUT/$png"
  echo "$OUT/$png"
}

render app_icon.svg app_icon.png 1024            # 안드로이드 7 이하 (둥근 사각형 그대로)
render app_icon_ios.svg app_icon_ios.png 1024    # iOS (꽉 찬 정사각형, 모서리는 iOS 가 깎음)
render app_icon_bg.svg app_icon_bg.png 1024      # 안드로이드 적응형 배경
render app_icon_fg.svg app_icon_fg.png 1024      # 안드로이드 적응형 전경
render app_icon_mono.svg app_icon_mono.png 1024  # 안드로이드 13+ 테마 아이콘
# 스플래시: 안드로이드 12 는 1152px 중 지름 768px 원 안만 보이므로 600px 로 가운데에
render brand_mark.svg splash_logo.png 1152 600
# 앱 안 시작 화면(IntroGate)의 마크: 150dp 를 고밀도 화면에서도 선명하게
render brand_mark.svg intro_mark.png 600
