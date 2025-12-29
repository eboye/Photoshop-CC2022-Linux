#!/bin/bash
# Photoshop 2021 - Wine 9.0 (Isolated, compatible version) with Camera Raw

set -e

# Parse arguments
VERBOSE=false
INSTALL_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      INSTALL_DIR="$1"
      shift
      ;;
  esac
done

if [ -z "$INSTALL_DIR" ]; then
  echo "Usage: $0 [OPTIONS] /path/to/install/directory"
  echo ""
  echo "Options:"
  echo "  -v, --verbose    Show detailed output"
  exit 1
fi

INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
WINE_DIR="$INSTALL_DIR/wine-9.0"
WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Progress tracking
TOTAL_STEPS=11
CURRENT_STEP=0

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║   Adobe Photoshop 2021 + Camera Raw Installer for Linux   ║${NC}"
  echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

log_info() {
  echo -e "    ${BLUE}→${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_error() {
  echo -e "${RED}✗ ERROR:${NC} $1"
}

print_header

# Setup Wine 9.0 locally
log_step "Setting up Wine 9.0..."
if [ ! -d "$WINE_DIR" ]; then
  log_info "Downloading Wine 9.0 from Kron4ek... (this may take a few minutes)"
  mkdir -p "$INSTALL_DIR/wine-tmp"
  cd "$INSTALL_DIR/wine-tmp"

  if [ "$VERBOSE" = true ]; then
    wget https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-amd64.tar.xz
  else
    wget -q --show-progress https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-amd64.tar.xz
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
export PATH="$WINE_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$WINE_DIR/lib:$WINE_DIR/lib64:${LD_LIBRARY_PATH}"
export WINEPREFIX
export WINELOADER="$WINE_DIR/bin/wine"
export WINEDLLPATH="$WINE_DIR/lib/wine:$WINE_DIR/lib64/wine"
export WINEDEBUG=-all
export WINEDLLOVERRIDES="winemenubuilder.exe=d"

# Suppress winetricks reporting
export WINETRICKS_OPT_SHAREDPREFIX=0
export W_OPT_UNATTENDED=1

# Verify wine is working
log_step "Verifying Wine installation..."
if [ "$VERBOSE" = true ]; then
  wine --version
else
  wine --version >/dev/null 2>&1
fi
if [ $? -ne 0 ]; then
  log_error "Wine is not working correctly"
  exit 1
fi
log_success "Wine $(wine --version | cut -d' ' -f1) verified"

# Download winetricks
log_step "Setting up winetricks..."
cd "$INSTALL_DIR"
if [ ! -f "winetricks" ]; then
  log_info "Downloading winetricks..."
  if [ "$VERBOSE" = true ]; then
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
  else
    wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
  fi
  chmod +x winetricks
  log_success "Winetricks downloaded"
else
  log_info "Using existing winetricks"
fi

# Initialize wine prefix
log_step "Initializing Wine prefix..."
if [ ! -d "$WINEPREFIX" ]; then
  log_info "Creating Wine prefix with Windows 10..."
  if [ "$VERBOSE" = true ]; then
    wineboot
    ./winetricks win10
  else
    wineboot >/dev/null 2>&1
    ./winetricks -q win10 >/dev/null 2>&1
  fi
  log_success "Wine prefix initialized"
else
  log_info "Wine prefix already exists"
fi

# Download all redistributables
log_step "Downloading redistributables..."
cd "$INSTALL_DIR"
if [ ! -d "allredist" ]; then
  log_info "Downloading all redistributables... (this may take a few minutes)"
  if [ "$VERBOSE" = true ]; then
    curl -L -P0 "https://lulucloud.mywire.org/FileHosting/GithubProjects/allredist.tar.xz" > allredist.tar.xz
  else
    curl -s -L -P0 "https://lulucloud.mywire.org/FileHosting/GithubProjects/allredist.tar.xz" > allredist.tar.xz
  fi
  
  log_info "Extracting redistributables..."
  mkdir allredist
  tar -xf allredist.tar.xz
  rm -rf allredist.tar.xz
  log_success "Redistributables ready"
else
  log_info "Redistributables already downloaded"
fi

# Download Photoshop
log_step "Downloading Photoshop 2021..."
cd "$INSTALL_DIR"
if [ ! -d "Adobe Photoshop 2021" ]; then
  log_info "Downloading Photoshop 2021... (this may take a while)"
  if [ "$VERBOSE" = true ]; then
    curl -L -P0 "https://lulucloud.mywire.org/FileHosting/GithubProjects/AdobePhotoshop2021.tar.xz" > AdobePhotoshop2021.tar.xz
  else
    curl -s -L -P0 "https://lulucloud.mywire.org/FileHosting/GithubProjects/AdobePhotoshop2021.tar.xz" > AdobePhotoshop2021.tar.xz
  fi
  
  log_info "Extracting Photoshop..."
  tar -xf AdobePhotoshop2021.tar.xz
  rm -rf AdobePhotoshop2021.tar.xz
  log_success "Photoshop extracted"
else
  log_info "Photoshop already extracted"
fi

# Install winetricks components
log_step "Installing Wine components..."
if [ "$VERBOSE" = true ]; then
  ./winetricks fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts dxvk win10 vkd3d
else
  ./winetricks -q fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts dxvk win10 vkd3d >/dev/null 2>&1
fi
log_success "Wine components installed"

# Install redistributables
log_step "Installing Visual C++ redistributables..."
log_info "Installing 2010 redistributables..."
WINEPREFIX=$WINEPREFIX wine allredist/redist/2010/vcredist_x64.exe /q /norestart >/dev/null 2>&1
WINEPREFIX=$WINEPREFIX wine allredist/redist/2010/vcredist_x86.exe /q /norestart >/dev/null 2>&1

log_info "Installing 2012 redistributables..."
WINEPREFIX=$WINEPREFIX wine allredist/redist/2012/vcredist_x86.exe /install /quiet /norestart >/dev/null 2>&1
WINEPREFIX=$WINEPREFIX wine allredist/redist/2012/vcredist_x64.exe /install /quiet /norestart >/dev/null 2>&1

log_info "Installing 2013 redistributables..."
WINEPREFIX=$WINEPREFIX wine allredist/redist/2013/vcredist_x86.exe /install /quiet /norestart >/dev/null 2>&1
WINEPREFIX=$WINEPREFIX wine allredist/redist/2013/vcredist_x64.exe /install /quiet /norestart >/dev/null 2>&1

log_info "Installing 2019 redistributables..."
WINEPREFIX=$WINEPREFIX wine allredist/redist/2019/VC_redist.x64.exe /install /quiet /norestart >/dev/null 2>&1
WINEPREFIX=$WINEPREFIX wine allredist/redist/2019/VC_redist.x86.exe /install /quiet /norestart >/dev/null 2>&1
log_success "Visual C++ redistributables installed"

# Install Photoshop
log_step "Installing Photoshop..."
mkdir -p "$WINEPREFIX/drive_c/Program Files/Adobe"
mv "Adobe Photoshop 2021" "$WINEPREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2021"
log_success "Photoshop installed"

# Create launcher script
log_step "Creating launcher script..."
cat > "$WINEPREFIX/drive_c/launcher.sh" << 'EOF'
#!/usr/bin/env bash
SCR_PATH="pspath"
CACHE_PATH="pscache"
RESOURCES_PATH="$SCR_PATH/resources"
WINE_PREFIX="$SCR_PATH/prefix"
FILE_PATH=$(winepath -w "$1")
export WINEPREFIX="INSTALL_DIR_PLACEHOLDER"
WINEPREFIX=INSTALL_DIR_PLACEHOLDER DXVK_LOG_PATH=INSTALL_DIR_PLACEHOLDER DXVK_STATE_CACHE_PATH=INSTALL_DIR_PLACEHOLDER wine64 INSTALL_DIR_PLACEHOLDER/Adobe-Photoshop/drive_c/Program\ Files/Adobe/Adobe\ Photoshop\ 2021/photoshop.exe "$FILE_PATH"
EOF

# Replace placeholder with actual install directory
sed -i "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$WINEPREFIX/drive_c/launcher.sh"
chmod +x "$WINEPREFIX/drive_c/launcher.sh"
log_success "Launcher script created"

# Set Windows version to win10
log_step "Configuring Windows version..."
winecfg -v win10 >/dev/null 2>&1
log_success "Windows version set to 10"

# Create desktop entry
log_step "Creating desktop entry..."
mv allredist/photoshop.png ~/.local/share/icons/photoshop.png 2>/dev/null || true

mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/photoshop.desktop << EOF
[Desktop Entry]
Name=Photoshop CC 2021
Exec=bash -c "$INSTALL_DIR/Adobe-Photoshop/drive_c/launcher.sh %F"
Type=Application
Comment=Photoshop CC 2021 (Wine)
Categories=Graphics;
Icon=photoshop
StartupWMClass=photoshop.exe
EOF
log_success "Desktop entry created"

# Install Camera Raw
log_step "Installing Camera Raw 12.2.1..."
cd "$INSTALL_DIR"
if [ "$VERBOSE" = true ]; then
  curl -L "https://download.adobe.com/pub/adobe/photoshop/cameraraw/win/12.x/CameraRaw_12_2_1.exe" > CameraRaw_12_2_1.exe
  WINEPREFIX=$WINEPREFIX wine CameraRaw_12_2_1.exe
else
  curl -s -L "https://download.adobe.com/pub/adobe/photoshop/cameraraw/win/12.x/CameraRaw_12_2_1.exe" > CameraRaw_12_2_1.exe
  WINEPREFIX=$WINEPREFIX wine CameraRaw_12_2_1.exe >/dev/null 2>&1
fi
rm -rf CameraRaw_12_2_1.exe
log_success "Camera Raw installed"

# Cleanup
log_step "Cleaning up..."
rm -rf allredist
rm -rf winetricks
log_success "Cleanup completed"

print_header
echo -e "${GREEN}${BOLD}Installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}To launch Photoshop:${NC}"
echo -e "  • From terminal: ${CYAN}$INSTALL_DIR/Adobe-Photoshop/drive_c/launcher.sh${NC}"
echo -e "  • From applications menu: ${CYAN}Graphics → Photoshop CC 2021${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} The first launch may take longer as Wine configures components."
