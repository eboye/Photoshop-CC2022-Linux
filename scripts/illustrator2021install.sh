#!/bin/bash
# Illustrator 2021 Installer for Linux - Enhanced Version

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
readonly SCRIPT_VERSION="1.0-2021-CR"
readonly WINE_VERSION="9.0"
readonly WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-amd64.tar.xz"
readonly WINE_SHA256="cf0c09d4346dc10bc92ab674936292cff47eeb71ca7604b8e6303b7bdb97e2f6"
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

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -V|--version)
      echo "Illustrator 2021 Linux Installer v$SCRIPT_VERSION"
      exit 0
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -k|--keep-cache)
      KEEP_CACHE=true
      shift
      ;;
    -s|--skip-verify)
      SKIP_VERIFY=true
      shift
      ;;
    --no-desktop)
      CREATE_DESKTOP=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] /path/to/install/directory"
      echo ""
      echo "Options:"
      echo "  -v, --verbose      Show detailed output"
      echo "  -V, --version      Show version information"
      echo "  -n, --dry-run      Show what would be done without executing"
      echo "  -k, --keep-cache   Keep downloaded files in cache"
      echo "  -s, --skip-verify  Skip checksum verification"
      echo "  --no-desktop      Skip desktop entry creation"
      echo "  -h, --help         Show this help message"
      exit 0
      ;;
    *)
      INSTALL_DIR="$1"
      shift
      ;;
  esac
done

# Default installation directory
if [ -z "$INSTALL_DIR" ]; then
  INSTALL_DIR="$HOME/.WineApps"
  echo "No installation directory specified, using default: $INSTALL_DIR"
  echo "You have 5 seconds to cancel with CTRL + C..."
  sleep 5
fi

# Normalize installation directory
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
WINE_DIR="$INSTALL_DIR/wine-9.0"
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator-2021"

# Progress tracking
TOTAL_STEPS=15
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

# Step 1: Setup Wine 9.0 locally
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
if [ ! -f "winetricks" ]; then
  if ! download_file "$WINETRICKS_URL" "winetricks" "$WINETRICKS_SHA256" "winetricks" "$SKIP_VERIFY"; then
    log_error "Failed to download winetricks"
    exit 1
  fi
  chmod +x winetricks
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
  wineboot
else
  wineboot >/dev/null 2>&1 &
  BOOT_PID=$!
  # Show spinner while wineboot runs
  while kill -0 $BOOT_PID 2>/dev/null; do
    for s in / - \ \|; do
      printf "\r    %s%s%s Initializing..." "${YELLOW}" "${s}" "${NC}"
      sleep 0.1
    done
  done
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

log_step "Applying dark theme..."
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
fi

# Step 4: Download redistributables
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
if [ "$DRY_RUN" = true ]; then
  log_info "DRY RUN: Would extract Illustrator from $ILLUSTRACTOR_ARCHIVE"
else
  log_info "Extracting archive... (this may take a minute)"
  tar -xf "$ILLUSTRACTOR_ARCHIVE" -C /tmp/
  log_success "Illustrator extracted"
fi

# Step 6: Install Wine components
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

# Step 7: Install Illustrator
log_step "Installing Illustrator..."
if [ "$DRY_RUN" = true ]; then
  log_info "DRY RUN: Would install Illustrator to Wine prefix"
else
  mkdir -p "$WINEPREFIX/drive_c/Program Files/"
  cp -r "/tmp/Adobe Illustrator 2021" "$WINEPREFIX/drive_c/Program Files/"
  rm -rf "/tmp/Adobe Illustrator 2021"
  
  log_success "Illustrator installed"
fi

# Step 8: Install VC++ redistributables
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

# Step 9: Create launcher script
log_step "Creating launcher script..."
LAUNCHER="$INSTALL_DIR/launch-illustrator.sh"
if [ "$DRY_RUN" = true ]; then
  log_info "DRY RUN: Would create launcher script"
else
  cat > "$LAUNCHER" << EOF
#!/usr/bin/env bash
export PATH="$WINE_DIR/bin:\$PATH"
export LD_LIBRARY_PATH="$WINE_DIR/lib:$WINE_DIR/lib64:\${LD_LIBRARY_PATH}"
export WINEPREFIX="$WINEPREFIX"
export WINELOADER="$WINE_DIR/bin/wine"
export WINEDLLPATH="$WINE_DIR/lib/wine:$WINE_DIR/lib64/wine"
export WINEDEBUG=-all
export WINEDLLOVERRIDES="winemenubuilder.exe=d"

cd "\$WINEPREFIX/drive_c/Program Files/Adobe Illustrator 2021/Support Files/Contents/Windows"
"\$WINE_DIR/bin/wine" Illustrator.exe "\$@"
EOF
  
  chmod +x "$LAUNCHER"
  log_success "Launcher script created"
fi

# Step 10: Create desktop entry (if requested)
if [ "$CREATE_DESKTOP" = true ]; then
  log_step "Creating desktop entry..."
  if [ "$DRY_RUN" = true ]; then
    log_info "DRY RUN: Would create desktop entry (using generic icon)"
  else
    # Create desktop entry with generic icon
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
    
    log_success "Desktop entry created (using generic icon)"
  fi
else
  log_info "Desktop entry creation skipped"
fi

# Cleanup
if [ "$KEEP_CACHE" != "true" ] && [ "$DRY_RUN" != "true" ]; then
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
