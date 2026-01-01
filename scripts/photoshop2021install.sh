#!/bin/bash
# Photoshop 2021 - Wine 9.0 (Isolated, compatible version)

set -e

# ===== CONFIGURATION =====
readonly SCRIPT_VERSION="2.0"
readonly WINE_VERSION="9.0"
readonly WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-amd64.tar.xz"
readonly WINE_SHA256="cf0c09d4346dc10bc92ab674936292cff47eeb71ca7604b8e6303b7bdb97e2f6"
readonly WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
readonly WINETRICKS_SHA256=""
readonly REDIST_URL="https://drive.google.com/uc?export=download&id=1qcmyHzWerZ39OhW0y4VQ-hOy7639bJPO"
readonly REDIST_SHA256="a7cd24cecc984c10e6cbbdf77ebb8211bbc774cbc7d7e6fd9776f1eb13dbc9d4"
readonly MIN_DISK_SPACE_GB=10
readonly MIN_RAM_GB=4
readonly CACHE_DIR="$HOME/.cache/photoshop2021-installer"

# Parse arguments
VERBOSE=false
INSTALL_DIR=""
DRY_RUN=false
KEEP_CACHE=false
SKIP_VERIFY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -V|--version)
      echo "Photoshop 2021 Linux Installer v$SCRIPT_VERSION (Wine $WINE_VERSION)"
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
  echo "  -v, --verbose      Show detailed output"
  echo "  -V, --version      Show version information"
  echo "  -n, --dry-run      Show what would be done without executing"
  echo "  -k, --keep-cache   Keep downloaded files in cache"
  echo "  -s, --skip-verify  Skip checksum verification (not recommended)"
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
TOTAL_STEPS=12
CURRENT_STEP=0

# Cleanup on exit
cleanup_on_exit() {
  if [ $? -ne 0 ]; then
    log_error "Installation failed. Cleaning up..."
    wineserver -k 2>/dev/null || true
    if [ "$KEEP_CACHE" != "true" ]; then
      rm -rf "$INSTALL_DIR/wine-tmp" 2>/dev/null || true
    fi
  fi
}

trap cleanup_on_exit EXIT

# Verify file checksum
verify_checksum() {
  local file="$1"
  local expected_sha256="$2"
  
  if [ "$SKIP_VERIFY" = "true" ]; then
    log_info "Skipping checksum verification"
    return 0
  fi
  
  if [ -z "$expected_sha256" ]; then
    log_info "No checksum provided - skipping verification"
    return 0
  fi
  
  if [ ! -f "$file" ]; then
    log_error "File not found: $file"
    return 1
  fi
  
  local actual_sha256
  actual_sha256=$(sha256sum "$file" | cut -d' ' -f1)
  
  if [ "$actual_sha256" != "$expected_sha256" ]; then
    log_error "Checksum verification failed for $file"
    log_error "Expected: $expected_sha256"
    log_error "Actual: $actual_sha256"
    log_error "Tip: Use --skip-verify to bypass (not recommended)"
    return 1
  fi
  
  return 0
}

# Download with resume and verification (background version)
download_file_bg() {
  local url="$1"
  local output="$2"
  local sha256="$3"
  local description="$4"
  local pid_file="$5"

  if [ -f "$output" ] && verify_checksum "$output" "$sha256"; then
    log_info "Using existing $description"
    echo "0" > "$pid_file"
    return 0
  fi

  if [ "$DRY_RUN" = "true" ]; then
    log_info "[DRY-RUN] Would download: $url"
    echo "0" > "$pid_file"
    return 0
  fi

  # Use cache if available
  local cache_file
  cache_file="$CACHE_DIR/$(basename "$output")"
  if [ -f "$cache_file" ] && verify_checksum "$cache_file" "$sha256"; then
    log_info "Using cached $description"
    cp "$cache_file" "$output"
    echo "0" > "$pid_file"
    return 0
  fi

  # Download in background
  mkdir -p "$(dirname "$output")"
  (
    # Special handling for Google Drive URLs
    if [[ "$url" == *"drive.google.com"* ]]; then
      if command -v gdown >/dev/null 2>&1; then
        if [ "$VERBOSE" = "true" ]; then
          gdown "$url" -O "$output" 2>/dev/null
        else
          gdown -q "$url" -O "$output" 2>/dev/null
        fi
      else
        # Use curl with confirmation token
        if [ "$VERBOSE" = "true" ]; then
          curl -L "${url}&confirm=t" > "$output" 2>/dev/null
        else
          curl -# -L "${url}&confirm=t" > "$output" 2>/dev/null
        fi
      fi
    else
      # Regular download
      if [ "$VERBOSE" = "true" ]; then
        wget -c "$url" -O "$output" 2>/dev/null
      else
        wget -c --show-progress "$url" -O "$output" 2>/dev/null
      fi
    fi

    # Verify
    if verify_checksum "$output" "$sha256"; then
      # Cache if enabled
      if [ "$KEEP_CACHE" = "true" ]; then
        mkdir -p "$CACHE_DIR"
        cp "$output" "$cache_file"
      fi
      echo "0" > "$pid_file"
    else
      rm -f "$output"
      echo "1" > "$pid_file"
    fi
  ) &

  # Store the actual PID
  echo $! > "$pid_file"
}

# Download with resume and verification
download_file() {
  local url="$1"
  local output="$2"
  local sha256="$3"
  local description="$4"

  if [ -f "$output" ] && verify_checksum "$output" "$sha256"; then
    log_info "Using existing $description"
    return 0
  fi

  log_info "Downloading $description..."

  if [ "$DRY_RUN" = "true" ]; then
    log_info "[DRY-RUN] Would download: $url"
    return 0
  fi

  # Use cache if available
  local cache_file
  cache_file="$CACHE_DIR/$(basename "$output")"
  if [ -f "$cache_file" ] && verify_checksum "$cache_file" "$sha256"; then
    log_info "Using cached $description"
    cp "$cache_file" "$output"
    return 0
  fi

  # Download with resume
  mkdir -p "$(dirname "$output")"
  if [ "$VERBOSE" = "true" ]; then
    wget -c "$url" -O "$output"
  else
    wget -c --show-progress "$url" -O "$output"
  fi

  # Verify
  if ! verify_checksum "$output" "$sha256"; then
    rm -f "$output"
    return 1
  fi

  # Cache if enabled
  if [ "$KEEP_CACHE" = "true" ]; then
    mkdir -p "$CACHE_DIR"
    cp "$output" "$cache_file"
  fi

  log_success "$description downloaded and verified"
}

# Check system requirements
check_requirements() {
  log_step "Checking system requirements..."

  # Check disk space
  local available_space
  available_space=$(df -BG "$INSTALL_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
  if [ "$available_space" -lt "$MIN_DISK_SPACE_GB" ]; then
    log_error "Insufficient disk space. Required: ${MIN_DISK_SPACE_GB}GB, Available: ${available_space}GB"
    exit 1
  fi
  log_success "Disk space: ${available_space}GB available"

  # Check RAM
  local total_ram
  total_ram=$(free -g | awk 'NR==2{print $2}')
  if [ "$total_ram" -lt "$MIN_RAM_GB" ]; then
    log_error "Insufficient RAM. Required: ${MIN_RAM_GB}GB, Available: ${total_ram}GB"
    exit 1
  fi
  log_success "RAM: ${total_ram}GB available"

  # Check required commands
  local missing_commands=()
  for cmd in tar wget curl sha256sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_commands+=("$cmd")
    fi
  done

  if [ ${#missing_commands[@]} -gt 0 ]; then
    log_error "Missing required commands: ${missing_commands[*]}"
    exit 1
  fi
  log_success "All required commands found"
}

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

# Check system requirements
check_requirements

# Setup Wine 9.0 locally
log_step "Setting up Wine 9.0..."

# Start parallel downloads
mkdir -p "$INSTALL_DIR/wine-tmp"
cd "$INSTALL_DIR/wine-tmp"

# PID files for background downloads
WINE_PID_FILE="$INSTALL_DIR/.wine_download.pid"
REDIST_PID_FILE="$INSTALL_DIR/.redist_download.pid"

# Start Wine download in background
log_info "Starting parallel downloads..."
download_file_bg "$WINE_URL" "wine-9.0-amd64.tar.xz" "$WINE_SHA256" "Wine 9.0" "$WINE_PID_FILE"

# Start redistributables download in background
cd "$INSTALL_DIR"
download_file_bg "$REDIST_URL" "allredist.tar.xz" "$REDIST_SHA256" "VC++ redistributables" "$REDIST_PID_FILE"

# Wait for downloads to complete
log_info "Waiting for downloads to complete..."
wine_pid=$(cat "$WINE_PID_FILE")
redist_pid=$(cat "$REDIST_PID_FILE")

# Wait for both processes
wait "$wine_pid"
wine_exit_code=$?
wait "$redist_pid"
redist_exit_code=$?

# Clean up PID files
rm -f "$WINE_PID_FILE" "$REDIST_PID_FILE"

# Check results
if [ $wine_exit_code -ne 0 ] || [ $redist_exit_code -ne 0 ]; then
  log_error "One or more downloads failed"
  exit 1
fi

# Check Wine download
cd "$INSTALL_DIR/wine-tmp"
if [ -f "wine-9.0-amd64.tar.xz" ]; then
  log_info "Extracting Wine..."
  tar -xf wine-9.0-amd64.tar.xz
  mv wine-9.0-amd64 "$WINE_DIR"
  cd "$INSTALL_DIR"
  rm -rf wine-tmp
  log_success "Wine 9.0 installed"
else
  log_error "Failed to download Wine"
  exit 1
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
  if ! download_file "$WINETRICKS_URL" "winetricks" "$WINETRICKS_SHA256" "winetricks"; then
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

log_step "Downloading redistributables..."
cd "$INSTALL_DIR"
if [ ! -d "allredist" ]; then
  log_info "Checking redistributables download..."

  # Check if download was completed in parallel
  if [ -f "allredist.tar.xz" ]; then
    log_success "Redistributables already downloaded"
  else
    log_error "Redistributables download failed"
    exit 1
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
  log_error "Available directories in $INSTALL_DIR:"
  for dir in "$INSTALL_DIR"/*; do
    [ -d "$dir" ] && echo "  $(basename "$dir")"
  done | grep -i photoshop || echo "  (No directories containing 'photoshop' found)"
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
