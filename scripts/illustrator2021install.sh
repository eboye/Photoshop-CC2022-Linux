#!/bin/bash
# Illustrator 2021 Installer for Linux - Enhanced Version

set -e

# Get script directory
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common functions
if [ -f "$LIB_DIR/common.sh" ]; then
  source "$LIB_DIR/common.sh"
else
  echo "Error: Could not find common.sh at $LIB_DIR/common.sh"
  exit 1
fi

# ===== CONFIGURATION =====
readonly SCRIPT_VERSION="2.0-2021-CR"
readonly WINE_VERSION="7.12-staging-tkg"
readonly WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/7.12/wine-7.12-staging-tkg-amd64.tar.xz"
readonly WINE_SHA256=""
readonly WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
readonly WINETRICKS_SHA256=""
readonly REDIST_URL="https://drive.google.com/uc?export=download&id=1qcmyHzWerZ39OhW0y4VQ-hOy7639bJPO"
readonly REDIST_SHA256="a7cd24cecc984c10e6cbbdf77ebb8211bbc774cbc7d7e6fd9776f1eb13dbc9d4"
readonly CACHE_DIR="$HOME/.cache/illustrator2021cr-installer"

# Local files
readonly LOCAL_ILLUSTRATOR_ARCHIVE="AdobeIllustrator2021.tar.xz"

# Parse arguments
VERBOSE=false
INSTALL_DIR=""
DRY_RUN=false
KEEP_CACHE=false
SKIP_VERIFY=false
CREATE_DESKTOP=true
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
  --no-desktop       Skip desktop entry creation
  -h, --help         Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)     VERBOSE=true; shift ;;
    -V|--version)
      echo "Illustrator 2021 Linux Installer v$SCRIPT_VERSION"
      exit 0 ;;
    -n|--dry-run)     DRY_RUN=true; shift ;;
    -k|--keep-cache)  KEEP_CACHE=true; shift ;;
    -s|--skip-verify) SKIP_VERIFY=true; shift ;;
    -f|--force)       FORCE=true; shift ;;
    --no-desktop)     CREATE_DESKTOP=false; shift ;;
    -h|--help)        usage; exit 0 ;;
    --)               shift; break ;;
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

# Default installation directory
if [ -z "$INSTALL_DIR" ]; then
  INSTALL_DIR="$HOME/.WineApps"
  echo "No installation directory specified, using default: $INSTALL_DIR"
  echo "You have 5 seconds to cancel with CTRL + C..."
  sleep 5
fi

# Normalize installation directory
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
WINE_DIR="$INSTALL_DIR/wine-7.12-staging-tkg"
CUSTOM_WINE_DIR="$INSTALL_DIR/wine-illustrator-custom"
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator-2021"

if [ "$DRY_RUN" = "true" ]; then
  cat <<EOF
[dry-run] Would install Illustrator 2021 with these settings:
  INSTALL_DIR     = $INSTALL_DIR
  WINE_DIR        = $WINE_DIR
  CUSTOM_WINE_DIR = $CUSTOM_WINE_DIR
  WINEPREFIX      = $WINEPREFIX
  WINE_URL        = $WINE_URL
  CACHE_DIR       = $CACHE_DIR
  SKIP_VERIFY     = $SKIP_VERIFY
  CREATE_DESKTOP  = $CREATE_DESKTOP
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
TOTAL_STEPS=18
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

# Get absolute paths
WORK_DIR="$(dirname "$SCRIPT_DIR")"

# Find local Illustrator archive
find_local_illustrator() {
  local locations=(
    "$WORK_DIR/$LOCAL_ILLUSTRATOR_ARCHIVE"
    "$SCRIPT_DIR/$LOCAL_ILLUSTRATOR_ARCHIVE"
    "$INSTALL_DIR/$LOCAL_ILLUSTRATOR_ARCHIVE"
    "$HOME/$LOCAL_ILLUSTRATOR_ARCHIVE"
  )
  
  for location in "${locations[@]}"; do
    if [ -f "$location" ]; then
      echo "$location"
      return 0
    fi
  done
  
  return 1
}

print_header "      Adobe Illustrator 2021 Installer for Linux"

# Check system requirements
check_requirements "$INSTALL_DIR"

# Step 1: Setup custom wine-illustrator from project root
log_step "Setting up custom wine-illustrator..."
if [ ! -d "$INSTALL_DIR/wine-illustrator-custom" ]; then
  # Check for local custom wine in project root
  LOCAL_WINE="$PROJECT_ROOT/wine-illustrator-custom.tar.xz"
  if [ -f "$LOCAL_WINE" ]; then
    log_info "Using local custom Wine: $LOCAL_WINE"
    tar -xf "$LOCAL_WINE" -C "$INSTALL_DIR/" || { log_error "Failed to extract local wine-illustrator-custom"; exit 1; }
  else
    log_info "Local custom Wine not found, downloading..."
    cd "$INSTALL_DIR"
    
    # Download custom wine-illustrator
    WINE_ILLUSTRATOR_URL="https://web.archive.org/web/20231024185932if_/https://lulucloud.mywire.org/FileHosting/GithubProjects/Illustrator/wine-illustrator-custom.tar.xz"
    if ! download_file "$WINE_ILLUSTRATOR_URL" "wine-illustrator-custom.tar.xz" "" "Custom Wine for Illustrator" "$SKIP_VERIFY" "$CACHE_DIR"; then
      log_error "Failed to download custom wine-illustrator"
      log_error "Please download it manually and place in project root:"
      log_error "wget -O wine-illustrator-custom.tar.xz \"$WINE_ILLUSTRATOR_URL\""
      exit 1
    fi
    
    log_info "Extracting custom Wine..."
    tar -xf wine-illustrator-custom.tar.xz -C "$INSTALL_DIR/" || { log_error "Failed to extract custom wine-illustrator"; exit 1; }
    
    # Clean up downloaded file
    rm -f wine-illustrator-custom.tar.xz
  fi
  log_success "Custom wine-illustrator extracted"
else
  log_info "Using existing custom wine-illustrator"
fi

# Step 2: Setup Wine 7.12 TKG locally
log_step "Setting up Wine 7.12 TKG..."
if [ ! -d "$WINE_DIR" ]; then
  mkdir -p "$INSTALL_DIR/wine-tmp"
  cd "$INSTALL_DIR/wine-tmp"
  
  if ! download_file "$WINE_URL" "wine-7.12-staging-tkg-amd64.tar.xz" "$WINE_SHA256" "Wine 7.12 TKG" "$SKIP_VERIFY" "$CACHE_DIR"; then
    log_error "Failed to download Wine"
    exit 1
  fi

  log_info "Extracting Wine..."
  tar -xf wine-7.12-staging-tkg-amd64.tar.xz
  mv wine-7.12-staging-tkg-amd64 "$WINE_DIR"

  cd "$INSTALL_DIR"
  rm -rf wine-tmp
  log_success "Wine 7.12 TKG installed"
else
  log_info "Using existing Wine 7.12 TKG installation"
fi

# Set Wine paths
setup_wine_env "$WINE_DIR" "$WINEPREFIX"

# Verify wine is working
log_step "Verifying Wine installation..."
if ! "$INSTALL_DIR/wine-illustrator-custom/bin/wine" --version >/dev/null 2>&1; then
  log_error "Custom wine-illustrator is not working correctly"
  exit 1
fi
if [ "$VERBOSE" = true ]; then
  "$INSTALL_DIR/wine-illustrator-custom/bin/wine" --version
fi
log_success "Custom wine-illustrator verified"

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
"$INSTALL_DIR/wine-illustrator-custom/bin/wineserver" -k 2>/dev/null || true
sleep 2

if [ "$VERBOSE" = true ]; then
  if ! "$CUSTOM_WINE_DIR/bin/wineboot"; then
    log_error "wineboot failed"
    exit 1
  fi
else
  "$CUSTOM_WINE_DIR/bin/wineboot" >/dev/null 2>&1 &
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
  timeout 30 env WINEPREFIX="$WINEPREFIX" PATH="$INSTALL_DIR/wine-illustrator-custom/bin:$PATH" "$INSTALL_DIR/wine-illustrator-custom/bin/wine" "$INSTALL_DIR/winetricks" win10 || log_warning "Windows 10 mode configuration timed out"
else
  log_info "Setting Windows version..."
  timeout 30 env WINEPREFIX="$WINEPREFIX" PATH="$INSTALL_DIR/wine-illustrator-custom/bin:$PATH" "$INSTALL_DIR/wine-illustrator-custom/bin/wine" "$INSTALL_DIR/winetricks" -q win10 >/dev/null 2>&1 || log_warning "Windows 10 mode configuration timed out"
  log_success "Windows 10 mode enabled (or skipped)"
fi

log_step "Applying dark theme..."
# Ensure Wine prefix is properly initialized
if [ ! -f "$WINEPREFIX/user.reg" ]; then
  log_info "Initializing Wine prefix for dark theme..."
  env WINEPREFIX="$WINEPREFIX" PATH="$INSTALL_DIR/wine-illustrator-custom/bin:$PATH" "$INSTALL_DIR/wine-illustrator-custom/bin/wineboot" -u >/dev/null 2>&1 || true
  sleep 2
fi

if [ -f "$WINEPREFIX/user.reg" ]; then
  # Add dark mode colors
  cat >> "$WINEPREFIX/user.reg" << 'EOF'

[Control Panel\\Colors]
"ActiveBorder"="59 59 59"
"ActiveTitle"="0 0 0"
"AppWorkspace"="37 37 37"
"Background"="37 37 37"
"ButtonAlternateFace"="180 180 180"
"ButtonDkShadow"="105 105 105"
"ButtonFace"="37 37 37"
"ButtonHilight"="255 255 255"
"ButtonLight"="220 220 220"
"ButtonShadow"="105 105 105"
"ButtonText"="255 255 255"
"GrayText"="150 150 150"
"Hilight"="51 51 51"
"HilightText"="255 255 255"
"InactiveBorder"="255 255 255"
"InactiveTitle"="37 37 37"
"InactiveTitleText"="200 200 200"
"InfoText"="0 0 0"
"InfoWindow"="255 255 255"
"Menu"="37 37 37"
"MenuBar"="37 37 37"
"MenuHilight"="51 51 51"
"MenuText"="255 255 255"
"Scrollbar"="73 73 73"
"TitleText"="255 255 255"
"Window"="37 37 37"
"WindowFrame"="100 100 100"
"WindowText"="255 255 255"
EOF
  log_success "Dark theme applied"
else
  log_warning "Could not find user.reg to apply dark theme"
  # Try alternative method - create the registry file directly
  log_info "Attempting alternative dark theme application..."
  mkdir -p "$WINEPREFIX"
  cat > "$WINEPREFIX/user.reg" << 'EOF'

WINE REGISTRY Version 2

;; All keys relative to \\User\\Default

[Control Panel\\Colors]
"ActiveBorder"="59 59 59"
"ActiveTitle"="0 0 0"
"AppWorkspace"="37 37 37"
"Background"="37 37 37"
"ButtonAlternateFace"="180 180 180"
"ButtonDkShadow"="105 105 105"
"ButtonFace"="37 37 37"
"ButtonHilight"="255 255 255"
"ButtonLight"="220 220 220"
"ButtonShadow"="105 105 105"
"ButtonText"="255 255 255"
"GrayText"="150 150 150"
"Hilight"="51 51 51"
"HilightText"="255 255 255"
"InactiveBorder"="255 255 255"
"InactiveTitle"="37 37 37"
"InactiveTitleText"="200 200 200"
"InfoText"="0 0 0"
"InfoWindow"="255 255 255"
"Menu"="37 37 37"
"MenuBar"="37 37 37"
"MenuHilight"="51 51 51"
"MenuText"="255 255 255"
"Scrollbar"="73 73 73"
"TitleText"="255 255 255"
"Window"="37 37 37"
"WindowFrame"="100 100 100"
"WindowText"="255 255 255"

EOF
  log_success "Dark theme applied via alternative method"
fi

# Step 4: Download redistributables (Wine-compatible versions)
log_step "Downloading redistributables..."
cd "$INSTALL_DIR"
if [ ! -d "vcredist" ]; then
  log_info "Downloading Wine-compatible VC++ redistributables..."
  
  mkdir -p vcredist/{2010,2012,2013,2019}
  
  # Download Wine-compatible versions
  log_info "Downloading VC++ 2010..."
  download_file "https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe" "vcredist/2010/vcredist_x64.exe" "" "VC++ 2010 x64" "$SKIP_VERIFY" "$CACHE_DIR"
  download_file "https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe" "vcredist/2010/vcredist_x86.exe" "" "VC++ 2010 x86" "$SKIP_VERIFY" "$CACHE_DIR"
  
  log_info "Downloading VC++ 2012..."
  download_file "https://download.microsoft.com/download/1/6/B/16B06F94-8F05-4A8B-9A61-888E3A2C9B73/VSU_4/vcredist_x64.exe" "vcredist/2012/vcredist_x64.exe" "" "VC++ 2012 x64" "$SKIP_VERIFY" "$CACHE_DIR"
  download_file "https://download.microsoft.com/download/1/6/B/16B06F94-8F05-4A8B-9A61-888E3A2C9B73/VSU_4/vcredist_x86.exe" "vcredist/2012/vcredist_x86.exe" "" "VC++ 2012 x86" "$SKIP_VERIFY" "$CACHE_DIR"
  
  log_info "Downloading VC++ 2013..."
  download_file "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe" "vcredist/2013/vcredist_x64.exe" "" "VC++ 2013 x64" "$SKIP_VERIFY" "$CACHE_DIR"
  download_file "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe" "vcredist/2013/vcredist_x86.exe" "" "VC++ 2013 x86" "$SKIP_VERIFY" "$CACHE_DIR"
  
  log_info "Downloading VC++ 2019..."
  download_file "https://aka.ms/vs/17/release/vc_redist.x64.exe" "vcredist/2019/VC_redist.x64.exe" "" "VC++ 2019 x64" "$SKIP_VERIFY" "$CACHE_DIR"
  download_file "https://aka.ms/vs/17/release/vc_redist.x86.exe" "vcredist/2019/VC_redist.x86.exe" "" "VC++ 2019 x86" "$SKIP_VERIFY" "$CACHE_DIR"
  
  log_success "Redistributables downloaded"
else
  log_info "Using existing redistributables"
fi

# Step 5: Find and extract Illustrator
log_step "Locating Illustrator 2021 archive..."
ILLUSTRACTOR_ARCHIVE=$(find_local_illustrator)
if [ $? -ne 0 ]; then
  log_error "AdobeIllustrator2021.tar.xz not found in any of these locations:"
  echo "  - $WORK_DIR/$LOCAL_ILLUSTRATOR_ARCHIVE"
  echo "  - $SCRIPT_DIR/$LOCAL_ILLUSTRATOR_ARCHIVE"
  echo "  - $INSTALL_DIR/$LOCAL_ILLUSTRATOR_ARCHIVE"
  echo "  - $HOME/$LOCAL_ILLUSTRATOR_ARCHIVE"
  exit 1
fi

log_success "Found: $(basename "$ILLUSTRACTOR_ARCHIVE")"

log_step "Extracting Illustrator 2021..."
log_info "Extracting archive... (this may take a minute)"
tar -xf "$ILLUSTRACTOR_ARCHIVE" -C /tmp/
log_success "Illustrator extracted"

# Step 6: Use Wine 7.12 TKG for Illustrator compatibility
log_step "Using Wine 7.12 TKG for Illustrator compatibility..."
log_info "Using Wine 7.12 TKG for optimal Illustrator compatibility (same as old wine-illustrator-custom)"
log_success "Wine 7.12 TKG configured for Illustrator"

# Step 7: Initialize Wine prefix with Wine 7.12 TKG
log_step "Initializing Wine prefix with Wine 7.12 TKG..."
log_info "Initializing Wine with Wine 7.12 TKG..."
"$WINE_DIR/bin/wineboot" >/dev/null 2>&1
log_success "Wine prefix initialized with Wine 7.12 TKG"

# Step 8: Verify Wine 7.12 TKG installation
log_step "Verifying Wine 7.12 TKG installation..."
if [ -f "$WINE_DIR/bin/wine64" ]; then
  log_success "Wine 7.12 TKG verified and working"
  log_info "Using Wine 7.12 TKG for optimal Illustrator 2021 compatibility"
else
  log_error "Wine 7.12 TKG binary not found"
  exit 1
fi

# Step 9: Install Wine components
log_step "Installing Wine components..."
log_info "Installing fonts, libraries, and DXVK... (5-10 minutes)"
log_info "Note: Multiple windows may appear - they will close automatically"
cd "$INSTALL_DIR"
if [ "$VERBOSE" = true ]; then
  env WINEPREFIX="$WINEPREFIX" PATH="$INSTALL_DIR/wine-illustrator-custom/bin:$PATH" "$INSTALL_DIR/wine-illustrator-custom/bin/wine" "$INSTALL_DIR/winetricks" fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts
else
  env WINEPREFIX="$WINEPREFIX" PATH="$INSTALL_DIR/wine-illustrator-custom/bin:$PATH" "$INSTALL_DIR/wine-illustrator-custom/bin/wine" "$INSTALL_DIR/winetricks" -q fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts >/dev/null 2>&1
  log_success "Wine components installed"
fi

# Step 10: Install Illustrator
log_step "Installing Illustrator..."
mkdir -p "$WINEPREFIX/drive_c/Program Files/"
cp -r "/tmp/Adobe Illustrator 2021" "$WINEPREFIX/drive_c/Program Files/"
rm -rf "/tmp/Adobe Illustrator 2021"
log_success "Illustrator installed"

# Disable DxfDwg plugins: their Windows-side deps don't resolve under Wine,
# so they pop an "Error loading plugins" dialog on every startup. DXF/DWG
# import wouldn't work under Wine anyway.
log_step "Disabling Wine-incompatible DxfDwg plugins..."
DXF_COUNT=0
while IFS= read -r -d '' f; do
  mv "$f" "$f.disabled"
  DXF_COUNT=$((DXF_COUNT + 1))
done < <(find "$WINEPREFIX/drive_c" -iname "DxfDwg*.aip" -type f -print0 2>/dev/null)
if [ "$DXF_COUNT" -gt 0 ]; then
  log_success "Disabled $DXF_COUNT DxfDwg plugin file(s)"
else
  log_info "No DxfDwg plugins found"
fi

# Step 12: Install VC++ redistributables using simpler approach
log_step "Installing VC++ redistributables..."
log_info "Installing Visual C++ runtimes (2010, 2012, 2013, 2015, 2019, 2022)..."
cd "$INSTALL_DIR"

# Simple approach: install only the essential ones that Illustrator needs
log_info "Installing essential VC++ redistributables..."

# Install 2010, 2012, 2013 first (most important for Illustrator)
for version in 2010 2012 2013; do
  log_info "Installing VC++ $version..."
  env WINEPREFIX="$WINEPREFIX" PATH="$CUSTOM_WINE_DIR/bin:$PATH" timeout 30 "$CUSTOM_WINE_DIR/bin/wine" "$INSTALL_DIR/winetricks" -q vcrun$version >/dev/null 2>&1 || log_warning "VC++ $version installation failed"
done

# Try 2015 and 2019 with shorter timeout
for version in 2015 2019; do
  log_info "Installing VC++ $version..."
  env WINEPREFIX="$WINEPREFIX" PATH="$CUSTOM_WINE_DIR/bin:$PATH" timeout 20 "$CUSTOM_WINE_DIR/bin/wine" "$INSTALL_DIR/winetricks" -q vcrun$version >/dev/null 2>&1 || log_warning "VC++ $version installation failed"
done

# Fix missing MSVCP140_CODECVT_IDS.dll that redistributables sometimes miss
log_info "Fixing missing DLL dependencies..."
if [ ! -f "$WINEPREFIX/drive_c/windows/system32/msvcp140_codecvt_ids.dll" ]; then
  if [ -f "/usr/lib/wine/x86_64-windows/msvcp140_codecvt_ids.dll" ]; then
    cp /usr/lib/wine/x86_64-windows/msvcp140_codecvt_ids.dll "$WINEPREFIX/drive_c/windows/system32/"
    log_info "Added missing MSVCP140_CODECVT_IDS.dll"
  else
    log_warning "Could not find MSVCP140_CODECVT_IDS.dll in system Wine"
  fi
fi

# Also copy other common missing DLLs
for dll in msvcp140.dll msvcr140.dll vcruntime140.dll; do
  if [ ! -f "$WINEPREFIX/drive_c/windows/system32/$dll" ] && [ -f "/usr/lib/wine/x86_64-windows/$dll" ]; then
    cp "/usr/lib/wine/x86_64-windows/$dll" "$WINEPREFIX/drive_c/windows/system32/"
    log_info "Added missing $dll"
  fi
done

log_success "VC++ redistributables installed (2010, 2012, 2013, 2015, 2019)"

# Step 12.5: Apply Adobe CSXS registry fixes to bypass Adobe services
log_step "Applying Adobe compatibility fixes..."
ADOBE_CSXS_REG="$(mktemp --suffix=.reg)"
# Create Adobe CSXS registry fix to bypass Adobe service requirements
cat > "$ADOBE_CSXS_REG" << 'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Software\Adobe\CSXS.11]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.12]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.13]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.14]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.15]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.16]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.17]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.18]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.19]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.20]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.21]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.22]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.23]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.24]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.25]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.26]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.27]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.28]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.29]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.30]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.11]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.12]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.13]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.14]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.15]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.16]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.17]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.18]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.19]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.20]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.21]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.22]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.23]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.24]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.25]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.26]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.27]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.28]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.29]
"PlayerDebugMode"=dword:00000001

[HKEY_LOCAL_MACHINE\Software\Adobe\CSXS.30]
"PlayerDebugMode"=dword:00000001
EOF

# Apply the registry fix
env WINEPREFIX="$WINEPREFIX" PATH="$CUSTOM_WINE_DIR/bin:$PATH" "$CUSTOM_WINE_DIR/bin/wine" regedit /S "$ADOBE_CSXS_REG" || log_warning "Failed to apply Adobe CSXS registry fixes"

rm -f "$ADOBE_CSXS_REG"

log_success "Adobe compatibility fixes applied"

# Step 13: Create launcher script
log_step "Creating launcher script..."
WINE_ENV_FILE="$INSTALL_DIR/wine-env.sh"
write_wine_env_file "$WINE_ENV_FILE" "$CUSTOM_WINE_DIR" "$WINEPREFIX"

LAUNCHER="$INSTALL_DIR/launch-illustrator.sh"
cat > "$LAUNCHER" << 'EOF'
#!/usr/bin/env bash
# Single source of truth for wine env lives in wine-env.sh
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/wine-env.sh"

# DXVK environment variables from oldinstall
export DXVK_LOG_PATH="$WINEPREFIX"
export DXVK_STATE_CACHE_PATH="$WINEPREFIX"

cd "$WINEPREFIX/drive_c/Program Files/Adobe Illustrator 2021/Support Files/Contents/Windows"
exec "$(dirname "$WINELOADER")/wine64" Illustrator.exe "$@"
EOF

chmod +x "$LAUNCHER"
log_success "Launcher script created"

# Copy icons to installation directory
log_step "Copying icons..."
if [ -d "$PROJECT_ROOT/images/icons" ]; then
  mkdir -p "$INSTALL_DIR/icons"
  cp -r "$PROJECT_ROOT/images/icons" "$INSTALL_DIR/"
  log_success "Icons copied to installation directory"
else
  log_warning "Icons folder not found at $PROJECT_ROOT/images/icons, desktop entry may use generic icons"
fi

# Step 13: Create desktop entry (if requested)
if [ "$CREATE_DESKTOP" = true ]; then
  log_step "Creating desktop entry..."
  # Use the desktop entry creation script which now handles icons properly
  if "$SCRIPT_DIR/create-illustrator2021-desktop.sh" "$INSTALL_DIR" >/dev/null 2>&1; then
    log_success "Desktop entry created"
  else
    log_warning "Failed to create desktop entry, creating fallback..."
    mkdir -p ~/.local/share/applications
    # Fallback desktop entry with generic icon
    cat > ~/.local/share/applications/illustrator2021.desktop << EOF
[Desktop Entry]
Name=Adobe Illustrator 2021
Exec=bash -c "$LAUNCHER %F"
Type=Application
Comment=Illustrator 2021 (Wine)
Categories=Graphics;
Icon=application-x-illustrator
StartupWMClass=illustrator.exe
EOF
    log_success "Fallback desktop entry created"
  fi
else
  log_info "Desktop entry creation skipped"
fi

# Cleanup
if [ "$KEEP_CACHE" != "true" ] && [ -d "$CACHE_DIR" ]; then
  log_info "Removing download cache at $CACHE_DIR (use --keep-cache to retain)"
  rm -rf "$CACHE_DIR"
fi

echo ""
echo -e "${BOLD}${GREEN}Installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}To launch Illustrator:${NC}"
echo "  $LAUNCHER"
echo ""
echo -e "${BLUE}Or from the applications menu:${NC}"
echo "  Look for 'Adobe Illustrator 2021'"
echo ""
if [ "$CREATE_DESKTOP" = true ]; then
  echo -e "${GREEN}✓${NC} Desktop entry created"
fi
echo -e "${GREEN}✓${NC} Illustrator 2021 installed"
