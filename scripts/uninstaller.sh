#!/bin/bash
# Photoshop 2021 Uninstaller for Linux

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
      echo "Usage: $0 [OPTIONS] /path/to/install/directory"
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
  echo "Usage: $0 [OPTIONS] /path/to/install/directory"
  echo ""
  echo "Options:"
  echo "  -v, --verbose    Show detailed output"
  echo "  -p, --purge      Remove all files including cache"
  echo "  -h, --help       Show this help message"
  exit 1
fi

# Progress tracking
TOTAL_STEPS=5
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

print_header "           Adobe Photoshop 2021 Uninstaller              "

# Validate installation directory
log_step "Validating installation directory..."
if [ ! -d "$INSTALL_DIR" ]; then
  log_error "Installation directory does not exist: $INSTALL_DIR"
  exit 1
fi

WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"
LAUNCHER="$INSTALL_DIR/launch-photoshop.sh"

if [ ! -d "$WINEPREFIX" ] && [ ! -f "$LAUNCHER" ]; then
  log_error "No Photoshop installation found in $INSTALL_DIR"
  log_error "Please provide the correct installation directory"
  exit 1
fi
log_success "Valid installation directory found"

# Stop any running Photoshop processes
log_step "Stopping Photoshop processes..."
if pgrep -f "Photoshop.exe" >/dev/null 2>&1; then
  log_info "Terminating running Photoshop instances..."
  pkill -f "Photoshop.exe" || true
  sleep 2
  pkill -9 -f "Photoshop.exe" || true
fi

# Stop Wine server
if [ -d "$WINEPREFIX" ]; then
  export WINEPREFIX="$WINEPREFIX"
  wineserver -k 2>/dev/null || true
  sleep 2
fi
log_success "All processes stopped"

# Remove Wine prefix
log_step "Removing Wine prefix..."
if [ -d "$WINEPREFIX" ]; then
  if [ "$VERBOSE" = true ]; then
    log_info "Removing: $WINEPREFIX"
  fi
  rm -rf "$WINEPREFIX"
  log_success "Wine prefix removed"
else
  log_info "Wine prefix not found - skipping"
fi

# Remove launcher
log_step "Removing launcher script..."
if [ -f "$LAUNCHER" ]; then
  rm -f "$LAUNCHER"
  log_success "Launcher script removed"
else
  log_info "Launcher script not found - skipping"
fi

# Remove installation files
log_step "Removing installation files..."
for item in wine-9.0 winetricks allredist "Adobe Photoshop 2021" *.tar.xz *.dmg; do
  if [ -e "$INSTALL_DIR/$item" ]; then
    if [ "$VERBOSE" = true ]; then
      log_info "Removing: $item"
    fi
    rm -rf "$INSTALL_DIR/$item"
  fi
done
log_success "Installation files removed"

# Remove cache if requested
if [ "$PURGE_ALL" = "true" ]; then
  log_step "Removing cache files..."
  for cache_dir in "$HOME/.cache/photoshop2021-installer" "$HOME/.cache/photoshop2021cr-installer"; do
    if [ -d "$cache_dir" ]; then
      if [ "$VERBOSE" = true ]; then
        log_info "Removing cache: $cache_dir"
      fi
      rm -rf "$cache_dir"
    fi
  done
  log_success "Cache files removed"
fi

# Remove desktop shortcuts
log_step "Removing desktop shortcuts..."
for desktop_file in "$HOME/Desktop/Photoshop 2021.desktop" "$HOME/.local/share/applications/Photoshop 2021.desktop"; do
  if [ -f "$desktop_file" ]; then
    rm -f "$desktop_file"
    if [ "$VERBOSE" = true ]; then
      log_info "Removed: $desktop_file"
    fi
  fi
done
log_success "Desktop shortcuts removed"

# Check if directory is empty and offer to remove it
log_step "Final cleanup..."
if [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
  log_info "Installation directory is empty"
  echo -n -e "${BLUE}Remove empty directory? [y/N]: ${NC}"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    rmdir "$INSTALL_DIR"
    log_success "Empty directory removed"
  fi
else
  log_info "Installation directory still contains files"
  if [ "$VERBOSE" = true ]; then
    ls -la "$INSTALL_DIR"
  fi
fi

echo ""
echo -e "${BOLD}${GREEN}Uninstallation completed successfully!${NC}"
echo ""
echo -e "${BLUE}Note:${NC} Some user settings may remain in:"
echo "  - ~/.wine (if you use Wine for other applications)"
echo "  - Adobe Cloud settings (if you use other Adobe products)"
echo ""
if [ "$PURGE_ALL" != "true" ]; then
  echo -e "${BLUE}To remove cached downloads, run:${NC}"
  echo "  $0 --purge $INSTALL_DIR"
fi
