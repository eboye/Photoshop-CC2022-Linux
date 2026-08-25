#!/bin/bash
# After Effects 2022 Uninstaller for Linux

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

# Parse arguments
VERBOSE=false
INSTALL_DIR=""
PURGE_ALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -p|--purge)
      PURGE_ALL=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] /path/to/aftereffects/installation"
      echo ""
      echo "Options:"
      echo "  -v, --verbose    Show detailed output"
      echo "  -p, --purge      Remove all files including cache"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
    *)
      INSTALL_DIR="$1"
      shift
      ;;
  esac
done

if [ -z "$INSTALL_DIR" ]; then
  echo "Error: Installation directory required"
  echo "Usage: $0 [OPTIONS] /path/to/aftereffects/installation"
  exit 1
fi

# Normalize installation directory
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"

print_header "      After Effects 2022 Uninstaller"

log_info "Installation directory: $INSTALL_DIR"

# Progress tracking
TOTAL_STEPS=6
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

# Step 1: Verify installation
log_step "Verifying After Effects 2022 installation..."
WINEPREFIX="$INSTALL_DIR/Adobe-AfterEffects"
AE_DIR="$WINEPREFIX/drive_c/Program Files/Adobe/Adobe After Effects 2022"

if [ ! -d "$AE_DIR" ] && [ ! -d "$WINEPREFIX" ] && [ ! -f "$INSTALL_DIR/launch-aftereffects.sh" ]; then
  log_error "After Effects 2022 installation not found at $INSTALL_DIR"
  exit 1
fi
log_success "After Effects 2022 installation verified"

# Step 2: Stop running processes
log_step "Stopping After Effects processes..."
if [ -d "$WINEPREFIX" ]; then
  export WINEPREFIX="$WINEPREFIX"
  wineserver -k 2>/dev/null || true
fi
sleep 2

pkill -f "AfterFX.exe" 2>/dev/null || true
pkill -f "launch-aftereffects.sh" 2>/dev/null || true
log_success "Processes stopped"

# Step 3: Remove desktop integration
log_step "Removing desktop entries and icons..."
DESKTOP_FILE="$HOME/.local/share/applications/adobe-aftereffects-2022.desktop"
if [ -f "$DESKTOP_FILE" ]; then
  rm -f "$DESKTOP_FILE"
  log_info "Removed desktop file"
fi

rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/adobe-aftereffects-2022.svg" 2>/dev/null || true
rm -f "$HOME/.local/share/icons/adobe-aftereffects-2022.ico" 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
log_success "Desktop integration removed"

# Step 4: Remove Wine prefix and installation directory
log_step "Removing installation files..."
if [ -d "$WINEPREFIX" ]; then
  log_info "Removing Wine prefix..."
  rm -rf "$WINEPREFIX"
fi

if [ -d "$INSTALL_DIR" ]; then
  log_info "Removing installation directory..."
  rm -rf "$INSTALL_DIR"
fi
log_success "Installation directory removed"

# Step 5: Clean cache if requested
log_step "Cleaning cache..."
if [ "$PURGE_ALL" = true ]; then
  CACHE_DIR="$HOME/.cache/aftereffects2022-installer"
  if [ -d "$CACHE_DIR" ]; then
    log_info "Purging cache at $CACHE_DIR..."
    rm -rf "$CACHE_DIR"
  fi
  log_success "Cache purged"
else
  log_info "Cache preserved (use -p to purge)"
fi

# Step 6: Final check
log_step "Final verification..."
log_success "After Effects 2022 uninstalled successfully!"

echo ""
echo -e "${GREEN}✓${NC} Uninstallation complete"
