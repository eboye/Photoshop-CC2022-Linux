#!/bin/bash
# Photoshop 2021 - Wine 9.0 (Isolated, compatible version) with Camera Raw

set -e

# Get script directory
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Source common functions
if [ -f "$LIB_DIR/common.sh" ]; then
  source "$LIB_DIR/common.sh"
else
  echo "Error: Could not find common.sh at $LIB_DIR/common.sh"
  exit 1
fi

# ===== CONFIGURATION =====
readonly SCRIPT_VERSION="2.0-CR"
readonly WINE_VERSION="9.0"
readonly WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-amd64.tar.xz"
readonly WINE_SHA256="cf0c09d4346dc10bc92ab674936292cff47eeb71ca7604b8e6303b7bdb97e2f6"
readonly WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
readonly WINETRICKS_SHA256=""
readonly CAMERA_RAW_URL="https://download.adobe.com/pub/adobe/photoshop/cameraraw/win/12.x/CameraRaw_12_2_1.exe"
readonly CAMERA_RAW_SHA256=""
readonly REDIST_URL="https://drive.google.com/uc?export=download&id=1qcmyHzWerZ39OhW0y4VQ-hOy7639bJPO"
readonly REDIST_SHA256="a7cd24cecc984c10e6cbbdf77ebb8211bbc774cbc7d7e6fd9776f1eb13dbc9d4"
readonly CACHE_DIR="$HOME/.cache/photoshop2021cr-installer"

# Parse arguments
VERBOSE=false
INSTALL_DIR=""
DRY_RUN=false
KEEP_CACHE=false
SKIP_VERIFY=false
SKIP_APPEARANCE=false
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
  --skip-appearance  Skip appearance configuration
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)      VERBOSE=true; shift ;;
    -V|--version)
      echo "Photoshop 2021 Linux Installer (CR) v$SCRIPT_VERSION (Wine $WINE_VERSION)"
      exit 0 ;;
    -n|--dry-run)      DRY_RUN=true; shift ;;
    -k|--keep-cache)   KEEP_CACHE=true; shift ;;
    -s|--skip-verify)  SKIP_VERIFY=true; shift ;;
    -f|--force)        FORCE=true; shift ;;
    --skip-appearance) SKIP_APPEARANCE=true; shift ;;
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

if [ -z "$INSTALL_DIR" ] && [ $# -gt 0 ]; then
  INSTALL_DIR="$1"; shift
  if [ $# -gt 0 ]; then
    echo "Error: extra arguments after install dir: $*" >&2
    exit 1
  fi
fi

if [ -z "$INSTALL_DIR" ]; then
  usage
  exit 1
fi

INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
WINE_DIR="$INSTALL_DIR/wine-9.0"
WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"

if [ "$DRY_RUN" = "true" ]; then
  cat <<EOF
[dry-run] Would install Photoshop 2021 + Camera Raw with these settings:
  INSTALL_DIR     = $INSTALL_DIR
  WINE_DIR        = $WINE_DIR
  WINEPREFIX      = $WINEPREFIX
  WINE_URL        = $WINE_URL
  CAMERA_RAW_URL  = $CAMERA_RAW_URL
  CACHE_DIR       = $CACHE_DIR
  SKIP_VERIFY     = $SKIP_VERIFY
  SKIP_APPEARANCE = $SKIP_APPEARANCE
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

# Progress tracking
TOTAL_STEPS=14
CURRENT_STEP=0

# Cleanup on exit
trap cleanup_on_exit EXIT

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

# Get absolute paths
WORK_DIR="$(dirname "$SCRIPT_DIR")"

print_header "      Adobe Photoshop 2021 + Camera Raw Installer for Linux"

# Check system requirements
check_requirements "$INSTALL_DIR"

# xdotool is only needed for the appearance step; gate the check on it
if [ "$SKIP_APPEARANCE" != "true" ]; then
  check_xdotool
fi

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

# Set Wine paths
setup_wine_env "$WINE_DIR" "$WINEPREFIX"

# Verify wine is working
log_step "Verifying Wine installation..."
if ! wine --version >/dev/null 2>&1; then
  log_error "Wine is not working correctly"
  exit 1
fi
if [ "$VERBOSE" = true ]; then
  wine --version
fi
log_success "Wine $WINE_VERSION verified"

# Download winetricks
log_step "Setting up winetricks..."
cd "$INSTALL_DIR"
# Re-fetch if local copy is missing, empty, or not executable
if [ ! -s "winetricks" ] || ! [ -x "winetricks" ]; then
  rm -f winetricks
  if ! download_file "$WINETRICKS_URL" "winetricks" "$WINETRICKS_SHA256" "winetricks" "$SKIP_VERIFY"; then
    log_error "Failed to download winetricks"
    exit 1
  fi
  chmod +x winetricks
  if [ ! -s "winetricks" ]; then
    log_error "Downloaded winetricks is empty"
    exit 1
  fi
  log_success "Winetricks downloaded"
else
  log_info "Using existing winetricks"
fi

# Disable winetricks stats reporting
mkdir -p "$HOME/.cache/winetricks"
echo "optout" > "$HOME/.cache/winetricks/track_usage"

# Initialize wine prefix
log_step "Initializing Wine prefix..."
log_info "Creating Windows environment... (this takes 1-2 minutes)"
rm -rf "$WINEPREFIX"
wineserver -k 2>/dev/null || true
sleep 2

if [ "$VERBOSE" = true ]; then
  if ! wineboot; then
    log_error "wineboot failed"
    exit 1
  fi
else
  wineboot >/dev/null 2>&1 &
  BOOT_PID=$!
  # Show spinner while wineboot runs
  while kill -0 $BOOT_PID 2>/dev/null; do
    for s in / - \\ \|; do
      printf "\r    %s%s%s Initializing..." "${YELLOW}" "${s}" "${NC}"
      sleep 0.1
    done
  done
  if ! wait "$BOOT_PID"; then
    printf "\r    %s✗%s Initialization failed\n" "${RED}" "${NC}"
    log_error "wineboot exited with non-zero status"
    exit 1
  fi
  printf "\r    %s✓%s Initialized      \n" "${GREEN}" "${NC}"
fi

log_step "Configuring Windows 10 mode..."
cd "$INSTALL_DIR"
if [ "$VERBOSE" = true ]; then
  ./winetricks win10
else
  log_info "Setting Windows version..."
  ./winetricks -q win10 >/dev/null 2>&1
  log_success "Windows 10 mode enabled"
fi

log_step "Applying Photoshop compatibility fixes..."
PS_FIXES_REG="$(mktemp --suffix=.reg)"
# Create registry fixes for monitor/EDID issues and DXVK optimization
cat > "$PS_FIXES_REG" << 'EOF'
REGEDIT4

[HKEY_CURRENT_USER\System\CurrentControlSet\Control\GraphicsDrivers]
"AdapterType"=dword:00000000
"AdapterLuid"=hex:00,00,00,00,00,00,00,00

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\GraphicsDrivers]
"AdapterType"=dword:00000000
"AdapterLuid"=hex:00,00,00,00,00,00,00,00

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"VideoMemorySize"="2048"
"StrictDrawOrdering"="disabled"
"OffscreenRenderingMode"="fbo"

[HKEY_CURRENT_USER\Software\Wine\DXVK]
"dxgi.enableVulkan"="dword:00000000"
"d3d11.enableVulkan"="dword:00000000"

EOF

# Apply the registry fixes
if wine regedit /S "$PS_FIXES_REG" >/dev/null 2>&1; then
  log_success "Photoshop compatibility fixes applied"
else
  log_warning "Failed to apply Photoshop registry fixes"
fi

rm -f "$PS_FIXES_REG"

log_step "Downloading redistributables..."
cd "$INSTALL_DIR"
if [ ! -d "allredist" ]; then
  log_info "Downloading VC++ redistributables... (this may take a few minutes)"
  
  if ! download_file "$REDIST_URL" "allredist.tar.xz" "$REDIST_SHA256" "VC++ redistributables" "$SKIP_VERIFY"; then
    log_error "Failed to download redistributables"
    exit 1
  fi
  
  log_info "Extracting..."
  tar -xf allredist.tar.xz
  rm allredist.tar.xz
  log_success "Redistributables ready"
else
  log_info "Using existing redistributables"
fi

log_step "Downloading Camera Raw..."
if ! download_file "$CAMERA_RAW_URL" "CameraRaw_12_2_1.exe" "$CAMERA_RAW_SHA256" "Camera Raw" "$SKIP_VERIFY" "$CACHE_DIR"; then
  log_error "Failed to download Camera Raw"
  SKIP_CAMERA_RAW=true
else
  CR_EXE="$INSTALL_DIR/CameraRaw_12_2_1.exe"
  log_success "Camera Raw downloaded"
fi

# Find Photoshop archive
log_step "Locating Photoshop archive..."
PS_ARCHIVE="$WORK_DIR/AdobePhotoshop2021.tar.xz"

if [ ! -f "$PS_ARCHIVE" ]; then
  if [ -f "$SCRIPT_DIR/AdobePhotoshop2021.tar.xz" ]; then
    PS_ARCHIVE="$SCRIPT_DIR/AdobePhotoshop2021.tar.xz"
  elif [ -f "$INSTALL_DIR/AdobePhotoshop2021.tar.xz" ]; then
    PS_ARCHIVE="$INSTALL_DIR/AdobePhotoshop2021.tar.xz"
  else
    log_error "Cannot find AdobePhotoshop2021.tar.xz"
    exit 1
  fi
fi
log_success "Found: $(basename "$PS_ARCHIVE")"

log_step "Extracting Photoshop..."
cd "$INSTALL_DIR"
log_info "Extracting archive... (this may take a minute)"
tar -xf "$PS_ARCHIVE"
log_success "Photoshop extracted"

log_step "Installing Wine components..."
log_info "Installing fonts, libraries, and DXVK... (5-10 minutes)"
log_info "Note: Multiple windows may appear - they will close automatically"
cd "$INSTALL_DIR"
if [ "$VERBOSE" = true ]; then
  ./winetricks fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts dxvk vkd3d
else
  ./winetricks -q fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts dxvk vkd3d >/dev/null 2>&1
  log_success "Wine components installed"
fi

log_step "Installing VC++ redistributables..."
log_info "Installing Visual C++ runtimes..."
if [ "$VERBOSE" = true ]; then
  wine allredist/redist/2010/vcredist_x64.exe /q /norestart
  wine allredist/redist/2010/vcredist_x86.exe /q /norestart
  wine allredist/redist/2012/vcredist_x86.exe /install /quiet /norestart
  wine allredist/redist/2012/vcredist_x64.exe /install /quiet /norestart
  wine allredist/redist/2013/vcredist_x86.exe /install /quiet /norestart
  wine allredist/redist/2013/vcredist_x64.exe /install /quiet /norestart
  wine allredist/redist/2019/VC_redist.x64.exe /install /quiet /norestart
  wine allredist/redist/2019/VC_redist.x86.exe /install /quiet /norestart
else
  wine allredist/redist/2010/vcredist_x64.exe /q /norestart >/dev/null 2>&1
  wine allredist/redist/2010/vcredist_x86.exe /q /norestart >/dev/null 2>&1
  wine allredist/redist/2012/vcredist_x86.exe /install /quiet /norestart >/dev/null 2>&1
  wine allredist/redist/2012/vcredist_x64.exe /install /quiet /norestart >/dev/null 2>&1
  wine allredist/redist/2013/vcredist_x86.exe /install /quiet /norestart >/dev/null 2>&1
  wine allredist/redist/2013/vcredist_x64.exe /install /quiet /norestart >/dev/null 2>&1
  wine allredist/redist/2019/VC_redist.x64.exe /install /quiet /norestart >/dev/null 2>&1
  wine allredist/redist/2019/VC_redist.x86.exe /install /quiet /norestart >/dev/null 2>&1
  log_success "VC++ redistributables installed"
fi

log_step "Installing Photoshop..."
mkdir -p "$WINEPREFIX/drive_c/Program Files/Adobe"
if mv "$INSTALL_DIR/Adobe Photoshop 2021" "$WINEPREFIX/drive_c/Program Files/Adobe/" 2>/dev/null; then
  log_success "Photoshop installed to Wine prefix"
else
  log_error "Could not find extracted Photoshop directory"
  log_error "Available directories in $INSTALL_DIR:"
  for dir in "$INSTALL_DIR"/*; do
    [ -d "$dir" ] && echo "  $(basename "$dir")"
  done | grep -i photoshop || echo "  (No directories containing 'photoshop' found)"
  exit 1
fi

# Prepare Camera Raw installer
log_step "Preparing Camera Raw installer..."

if [ "$SKIP_CAMERA_RAW" != "true" ]; then
  log_success "Camera Raw installer ready"
else
  log_warning "Camera Raw download failed - skipping Camera Raw installation"
fi

if [ "$SKIP_CAMERA_RAW" != "true" ]; then
  log_step "Installing Camera Raw..."
  log_info "Installing Camera Raw..."
  if [ "$VERBOSE" = true ]; then
    wine "$CR_EXE" --mode=silent
  else
    wine "$CR_EXE" --mode=silent >/dev/null 2>&1
  fi
  log_success "Camera Raw installed"
fi

log_step "Creating launcher..."
WINE_ENV_FILE="$INSTALL_DIR/wine-env.sh"
write_wine_env_file "$WINE_ENV_FILE" "$WINE_DIR" "$WINEPREFIX"

LAUNCHER="$INSTALL_DIR/launch-photoshop.sh"
cat > "$LAUNCHER" << 'EOF'
#!/usr/bin/env bash
# Single source of truth for wine env lives in wine-env.sh
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/wine-env.sh"

# Force Wine's builtin DirectX DLLs (instead of DXVK) for Photoshop compatibility.
# Note: trailing "=b" means "use builtin only". A bare "=" would disable the DLLs
# entirely and Photoshop would fail to load with status c0000135.
export WINEDLLOVERRIDES="winemenubuilder.exe=d;dxgi,d3d10core,d3d11,d3d12=b"
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX"
export WINEARCH=win64

cd "$WINEPREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2021"
exec "$WINELOADER" Photoshop.exe "$@"
EOF

chmod +x "$LAUNCHER"
log_success "Launcher created"

# Copy icons to installation directory
log_step "Copying icons..."
if [ -d "$WORK_DIR/images/icons" ]; then
  mkdir -p "$INSTALL_DIR/icons"
  cp -r "$WORK_DIR/images/icons" "$INSTALL_DIR/"
  log_success "Icons copied to installation directory"
else
  log_warning "Icons folder not found at $WORK_DIR/images/icons, desktop entry may use generic icons"
fi

log_step "Creating desktop entry..."
if "$SCRIPT_DIR/create-desktop-entry.sh" "$INSTALL_DIR" >/dev/null 2>&1; then
  log_success "Desktop entry created"
else
  log_warning "Failed to create desktop entry"
fi

# Auto-run Photoshop and apply appearance config
if [ "$SKIP_APPEARANCE" != "true" ]; then
  log_step "Configuring appearance..."
  
  # Wait for Photoshop to start and initialize
  wait_for_photoshop "$WINE_DIR"
  
  # Apply appearance configuration
  apply_appearance_config "$INSTALL_DIR" "$WINE_DIR" "$WINEPREFIX"
  
  log_success "Appearance configuration complete"
fi

# Final cleanup
wineserver -k 2>/dev/null || true
sleep 2

if [ "$KEEP_CACHE" != "true" ] && [ -d "$CACHE_DIR" ]; then
  log_info "Removing download cache at $CACHE_DIR (use --keep-cache to retain)"
  rm -rf "$CACHE_DIR"
fi

echo ""
echo -e "${BOLD}${GREEN}Installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}To launch Photoshop:${NC}"
echo "  $LAUNCHER"
echo ""
echo -e "${BLUE}Or from the command line:${NC}"
echo "  cd \"$INSTALL_DIR\""
echo "  ./launch-photoshop.sh"
echo ""
echo -e "${BLUE}Or from the desktop/applications menu:${NC}"
echo "  Look for 'Photoshop 2021' in your applications menu"
echo "  Or double-click the icon on your desktop"
echo ""
if [ "$SKIP_CAMERA_RAW" != "true" ]; then
  echo -e "${GREEN}✓${NC} Photoshop 2021 with Camera Raw installed"
else
  echo -e "${GREEN}✓${NC} Photoshop 2021 installed (Camera Raw skipped)"
fi
if [ "$SKIP_APPEARANCE" != "true" ]; then
  echo -e "${GREEN}✓${NC} Appearance configuration applied"
fi
