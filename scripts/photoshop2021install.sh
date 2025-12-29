#!/bin/bash
# Photoshop 2021 - Wine 9.0 (Isolated, compatible version)

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
  echo -e "${BOLD}${CYAN}║       Adobe Photoshop 2021 Installer for Linux           ║${NC}"
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

# Get absolute paths first
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

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

# Disable winetricks stats reporting
mkdir -p "$HOME/.cache/winetricks"
echo "optout" > "$HOME/.cache/winetricks/track_usage"

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
    for s in / - \\ \|; do
      printf "\r    ${YELLOW}${s}${NC} Initializing..."
      sleep 0.1
    done
  done
  printf "\r    ${GREEN}✓${NC} Initialized      \n"
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

log_step "Downloading redistributables..."
cd "$INSTALL_DIR"
if [ ! -d "allredist" ]; then
  log_info "Downloading VC++ redistributables... (this may take a few minutes)"
  if [ "$VERBOSE" = true ]; then
    curl -L "https://drive.google.com/uc?export=download&id=1qcmyHzWerZ39OhW0y4VQ-hOy7639bJPO" > allredist.tar.xz
  else
    curl -# -L "https://drive.google.com/uc?export=download&id=1qcmyHzWerZ39OhW0y4VQ-hOy7639bJPO" > allredist.tar.xz
  fi
  log_info "Extracting..."
  tar -xf allredist.tar.xz
  rm allredist.tar.xz
  log_success "Redistributables ready"
else
  log_info "Using existing redistributables"
fi

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
  ls -la "$INSTALL_DIR" | grep -i photoshop
  exit 1
fi

log_step "Creating launcher..."
LAUNCHER="$INSTALL_DIR/launch-photoshop.sh"
cat > "$LAUNCHER" << EOF
#!/usr/bin/env bash
export PATH="$WINE_DIR/bin:\$PATH"
export LD_LIBRARY_PATH="$WINE_DIR/lib:$WINE_DIR/lib64:\${LD_LIBRARY_PATH}"
export WINEPREFIX="$WINEPREFIX"
export WINELOADER="$WINE_DIR/bin/wine"
export WINEDLLPATH="$WINE_DIR/lib/wine:$WINE_DIR/lib64/wine"
export WINEDEBUG=-all

FILE_PATH=""
if [ -n "\$1" ]; then
  FILE_PATH=\$(winepath -w "\$1" 2>/dev/null) || true
fi

wine64 "$WINEPREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2021/photoshop.exe" "\$FILE_PATH"
EOF

chmod +x "$LAUNCHER"
log_success "Launcher created"

log_step "Cleaning up..."
cd "$INSTALL_DIR"
rm -rf allredist winetricks
log_success "Temporary files removed"

echo ""
echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║            Installation Complete! 🎉                      ║${NC}"
echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Launch Photoshop:${NC}"
echo -e "  ${CYAN}$LAUNCHER${NC}"
echo ""
echo -e "${BOLD}Open a file:${NC}"
echo -e "  ${CYAN}$LAUNCHER /path/to/image.psd${NC}"
echo ""
