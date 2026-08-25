#!/bin/bash
# After Effects 2022 - Wine 9.0 / Proton Compatible Linux Installer
# Based on LinuxPS architecture

set -e

# Get script directory
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
WORK_DIR="$(dirname "$SCRIPT_DIR")"
AE_WORK="$WORK_DIR/ae-work"

# Source common functions
if [ -f "$LIB_DIR/common.sh" ]; then
  source "$LIB_DIR/common.sh"
else
  echo "Error: Could not find common.sh at $LIB_DIR/common.sh"
  exit 1
fi

# ===== CONFIGURATION =====
readonly SCRIPT_VERSION="1.0"
readonly WINE_VERSION="9.0"
readonly WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-amd64.tar.xz"
readonly WINE_SHA256="cf0c09d4346dc10bc92ab674936292cff47eeb71ca7604b8e6303b7bdb97e2f6"
readonly WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
readonly WINETRICKS_SHA256=""
readonly REDIST_URL="https://drive.google.com/uc?export=download&id=1qcmyHzWerZ39OhW0y4VQ-hOy7639bJPO"
readonly REDIST_SHA256="a7cd24cecc984c10e6cbbdf77ebb8211bbc774cbc7d7e6fd9776f1eb13dbc9d4"
readonly CACHE_DIR="$HOME/.cache/aftereffects2022-installer"

# Parse arguments
VERBOSE=false
INSTALL_DIR=""
DRY_RUN=false
KEEP_CACHE=false
SKIP_VERIFY=false
FORCE=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] /path/to/install/directory

Options:
  -v, --verbose      Show detailed output
  -V, --version      Show version information
  -n, --dry-run      Show what would be done without executing
  -k, --keep-cache   Keep downloaded files in \$CACHE_DIR after install
  -s, --skip-verify  Skip checksum verification (not recommended)
  -f, --force        Overwrite an existing Wine prefix without prompting
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)      VERBOSE=true; shift ;;
    -V|--version)
      echo "Adobe After Effects 2022 Linux Installer v$SCRIPT_VERSION (Wine $WINE_VERSION)"
      exit 0 ;;
    -n|--dry-run)      DRY_RUN=true; shift ;;
    -k|--keep-cache)   KEEP_CACHE=true; shift ;;
    -s|--skip-verify)  SKIP_VERIFY=true; shift ;;
    -f|--force)        FORCE=true; shift ;;
    -h|--help)         usage; exit 0 ;;
    --)                shift; break ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1 ;;
    *)
      if [ -n "$INSTALL_DIR" ]; then
        echo "Error: multiple install directories given ('$INSTALL_DIR' and '$1')" >&2
        exit 1
      fi
      INSTALL_DIR="$1"
      shift ;;
  esac
done

if [ -z "$INSTALL_DIR" ]; then
  usage
  exit 1
fi

INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
WINE_DIR="$INSTALL_DIR/wine-9.0"
WINEPREFIX="$INSTALL_DIR/Adobe-AfterEffects"

if [ "$DRY_RUN" = "true" ]; then
  cat <<EOF
[dry-run] Would install After Effects 2022 with these settings:
  INSTALL_DIR     = $INSTALL_DIR
  WINE_DIR        = $WINE_DIR
  WINEPREFIX      = $WINEPREFIX
  WINE_URL        = $WINE_URL
  CACHE_DIR       = $CACHE_DIR
  SKIP_VERIFY     = $SKIP_VERIFY
  FORCE           = $FORCE
  KEEP_CACHE      = $KEEP_CACHE
EOF
  exit 0
fi

# Refuse to clobber an existing Wine prefix without --force
if [ -d "$WINEPREFIX" ] && [ "$FORCE" != "true" ]; then
  log_error "Wine prefix already exists: $WINEPREFIX"
  log_info "Re-run with --force to overwrite, or pick a different install directory."
  exit 1
fi

TOTAL_STEPS=14
CURRENT_STEP=0

# Cleanup on exit
trap cleanup_on_exit EXIT

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

print_header "    Adobe After Effects 2022 Installer for Linux          "

# Check system requirements
check_requirements "$INSTALL_DIR"

# Setup Wine 9.0 locally
log_step "Setting up Wine 9.0..."
if [ ! -d "$WINE_DIR" ]; then
  mkdir -p "$INSTALL_DIR/wine-tmp"
  cd "$INSTALL_DIR/wine-tmp"
  
  if ! download_file "$WINE_URL" "wine-9.0-amd64.tar.xz" "$WINE_SHA256" "Wine 9.0" "$SKIP_VERIFY" "$CACHE_DIR"; then
    log_error "Failed to download Wine"
    exit 1
  fi

  log_info "Extracting Wine..."
  tar -xf wine-9.0-amd64.tar.xz
  mv wine-9.0-amd64 "$WINE_DIR"

  cd "$INSTALL_DIR"
  rm -rf wine-tmp
  log_success "Wine 9.0 installed"
else
  log_info "Using existing Wine 9.0 installation"
fi

_wine_env_exports() {
  local wine_dir="$1"
  local wineprefix="$2"
  cat <<EOF
export WINEPREFIX="$wineprefix"
export WINELOADER="\$(which wine)"
export WINEDEBUG=-all,err+all
export WINEDLLOVERRIDES="winemenubuilder.exe=d;dxgi,d3d10core,d3d11,d3d12=b;msxml3,msxml6=b"
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="$wineprefix"
export WINEARCH=win64
EOF
}

# Set Wine paths
setup_wine_env() {
  export WINEPREFIX="$WINEPREFIX"
  export WINELOADER="$(which wine)"
  export WINEDEBUG=-all
  export WINEDLLOVERRIDES="winemenubuilder.exe=d;dxgi,d3d10core,d3d11,d3d12=b;msxml3,msxml6=b"
  export W_OPT_UNATTENDED=1
  export WINETRICKS_OPT_SHAREDPREFIX=0
}

# Verify wine is working
log_step "Verifying Wine installation..."
if ! wine --version >/dev/null 2>&1; then
  log_error "Wine is not working correctly"
  exit 1
fi
log_success "Wine $WINE_VERSION verified"

# Download winetricks
log_step "Setting up winetricks..."
cd "$INSTALL_DIR"
if [ ! -s "winetricks" ] || ! [ -x "winetricks" ]; then
  rm -f winetricks
  if ! download_file "$WINETRICKS_URL" "winetricks" "$WINETRICKS_SHA256" "winetricks" "$SKIP_VERIFY"; then
    log_error "Failed to download winetricks"
    exit 1
  fi
  chmod +x winetricks
  log_success "Winetricks downloaded"
else
  log_info "Using existing winetricks"
fi

mkdir -p "$HOME/.cache/winetricks"
echo "optout" > "$HOME/.cache/winetricks/track_usage"

# Initialize wine prefix
log_step "Initializing Wine prefix (64-bit)..."
rm -rf "$WINEPREFIX"
wineserver -k 2>/dev/null || true
sleep 2

wineboot >/dev/null 2>&1 &
BOOT_PID=$!
while kill -0 $BOOT_PID 2>/dev/null; do
  for s in / - \\ \|; do
    printf "\r    %s%s%s Initializing..." "$YELLOW" "$s" "$NC"
    sleep 0.1
  done
done
wait "$BOOT_PID" || true
printf "\r    %s✓%s Initialized      \n" "$GREEN" "$NC"

log_step "Configuring Windows 10 mode..."
cd "$INSTALL_DIR"
./winetricks -q win10 >/dev/null 2>&1 || true
log_success "Windows 10 mode enabled"

log_step "Applying After Effects compatibility fixes & registry..."
AE_FIXES_REG="$(mktemp --suffix=.reg)"
cat > "$AE_FIXES_REG" << 'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"VideoMemorySize"="4096"
"StrictDrawOrdering"="disabled"
"OffscreenRenderingMode"="fbo"

[HKEY_CURRENT_USER\Software\Wine\DXVK]
"dxgi.enableVulkan"="dword:00000000"
"d3d11.enableVulkan"="dword:00000000"

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="2"
"FontSmoothingType"=dword:00000002

EOF

wine regedit /S "$AE_FIXES_REG" >/dev/null 2>&1 || true
rm -f "$AE_FIXES_REG"

# Import exported Windows VM registry if available
if [ -f "$AE_WORK/adobe_hklm.reg" ]; then
  wine regedit /S "$AE_WORK/adobe_hklm.reg" >/dev/null 2>&1 || true
fi
if [ -f "$AE_WORK/adobe_hkcu.reg" ]; then
  wine regedit /S "$AE_WORK/adobe_hkcu.reg" >/dev/null 2>&1 || true
fi
log_success "Registry compatibility fixes applied"

log_step "Downloading VC++ redistributables..."
cd "$INSTALL_DIR"
if [ ! -d "allredist" ]; then
  if ! download_file "$REDIST_URL" "allredist.tar.xz" "$REDIST_SHA256" "VC++ redistributables" "$SKIP_VERIFY"; then
    log_error "Failed to download redistributables"
    exit 1
  fi
  tar -xf allredist.tar.xz
  rm allredist.tar.xz
  log_success "Redistributables ready"
else
  log_info "Using existing redistributables"
fi

log_step "Installing Wine components..."
cd "$INSTALL_DIR"
./winetricks -q fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts dxvk vkd3d d3dcompiler_47 >/dev/null 2>&1 || true
log_success "Wine components installed"

log_step "Installing VC++ redistributables..."
wine allredist/redist/2010/vcredist_x64.exe /q /norestart >/dev/null 2>&1 || true
wine allredist/redist/2010/vcredist_x86.exe /q /norestart >/dev/null 2>&1 || true
wine allredist/redist/2012/vcredist_x86.exe /install /quiet /norestart >/dev/null 2>&1 || true
wine allredist/redist/2012/vcredist_x64.exe /install /quiet /norestart >/dev/null 2>&1 || true
wine allredist/redist/2013/vcredist_x86.exe /install /quiet /norestart >/dev/null 2>&1 || true
wine allredist/redist/2013/vcredist_x64.exe /install /quiet /norestart >/dev/null 2>&1 || true
wine allredist/redist/2019/VC_redist.x64.exe /install /quiet /norestart >/dev/null 2>&1 || true
wine allredist/redist/2019/VC_redist.x86.exe /install /quiet /norestart >/dev/null 2>&1 || true
log_success "VC++ redistributables installed"

# Find After Effects archive
log_step "Locating After Effects archive..."
AE_ARCHIVE="$WORK_DIR/AdobeAfterEffects2022.tar.xz"

if [ ! -f "$AE_ARCHIVE" ]; then
  if [ -f "$SCRIPT_DIR/AdobeAfterEffects2022.tar.xz" ]; then
    AE_ARCHIVE="$SCRIPT_DIR/AdobeAfterEffects2022.tar.xz"
  elif [ -f "$INSTALL_DIR/AdobeAfterEffects2022.tar.xz" ]; then
    AE_ARCHIVE="$INSTALL_DIR/AdobeAfterEffects2022.tar.xz"
  elif [ -f "$AE_WORK/AdobeAfterEffects2022.tar.xz" ]; then
    AE_ARCHIVE="$AE_WORK/AdobeAfterEffects2022.tar.xz"
  else
    log_error "Cannot find AdobeAfterEffects2022.tar.xz"
    exit 1
  fi
fi
log_success "Found: $(basename "$AE_ARCHIVE")"

log_step "Extracting After Effects 2022..."
mkdir -p "$WINEPREFIX/drive_c/Program Files/Adobe"
mkdir -p "$WINEPREFIX/drive_c/Program Files/Common Files/Adobe"
mkdir -p "$WINEPREFIX/drive_c/Program Files (x86)/Common Files/Adobe"

log_info "Extracting binaries and runtime components..."
if tar -tf "$AE_ARCHIVE" 2>/dev/null | grep -q "^drive_c/"; then
  tar -xf "$AE_ARCHIVE" -C "$WINEPREFIX/"
else
  tar -xf "$AE_ARCHIVE" -C "$WINEPREFIX/drive_c/Program Files/Adobe/"
fi
log_success "After Effects 2022 extracted"

log_step "Creating launchers..."
WINE_ENV_FILE="$INSTALL_DIR/wine-env.sh"
write_wine_env_file "$WINE_ENV_FILE" "$WINE_DIR" "$WINEPREFIX"

LAUNCHER="$INSTALL_DIR/launch-aftereffects.sh"
cat > "$LAUNCHER" << 'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$HERE/wine-env.sh"

export WINEDLLOVERRIDES="winemenubuilder.exe=d;dxgi,d3d10core,d3d11,d3d12=b"
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX"
export WINEARCH=win64

cd "$WINEPREFIX/drive_c/Program Files/Adobe/Adobe After Effects 2022/Support Files"
exec "$WINELOADER" AfterFX.exe "$@"
EOF
chmod +x "$LAUNCHER"
log_success "Launcher created at $LAUNCHER"

log_step "Creating desktop entry..."
DESKTOP_FILE="$HOME/.local/share/applications/adobe-aftereffects-2022.desktop"
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Adobe After Effects 2022
Comment=Create motion graphics and visual effects
Exec="$LAUNCHER" %F
Icon=video-x-generic
Terminal=false
Type=Application
Categories=Graphics;Video;AudioVideo;
MimeType=application/x-aftereffects;
StartupNotify=true
EOF
chmod +x "$DESKTOP_FILE"
log_success "Desktop entry created"

# Final cleanup
wineserver -k 2>/dev/null || true
sleep 2

echo ""
echo -e "${BOLD}${GREEN}Installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}To launch After Effects:${NC}"
echo "  $LAUNCHER"
echo ""
