#!/usr/bin/env bash
# Adobe After Effects 2022 Launcher Script Template

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
if [ -f "$HERE/wine-env.sh" ]; then
  source "$HERE/wine-env.sh"
else
  export WINEPREFIX="${WINEPREFIX:-$HERE/Adobe-AfterEffects}"
  export WINELOADER="${WINELOADER:-$(which wine)}"
  export WINEDEBUG=-all,err+all
  export WINEDLLOVERRIDES="winemenubuilder.exe=d;dxgi,d3d10core,d3d11,d3d12=b;msxml3,msxml6=b"
  export __GL_SHADER_DISK_CACHE=1
  export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX"
  export WINEARCH=win64
fi

cd "$WINEPREFIX/drive_c/Program Files/Adobe/Adobe After Effects 2022/Support Files"
exec "$WINELOADER" AfterFX.exe "$@"
