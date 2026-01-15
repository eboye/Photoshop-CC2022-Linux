#!/bin/bash
# Illustrator 2021 Uninstaller for Linux

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
  echo "Error: Installation directory required"
  echo "Usage: $0 [OPTIONS] /path/to/install/directory"
  exit 1
fi

# Normalize installation directory
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"

print_header "      Illustrator 2021 Uninstaller"

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
log_step "Verifying Illustrator 2021 installation..."
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator-2021"
ILL_DIR="$WINEPREFIX/drive_c/Program Files/Adobe Illustrator 2021"

if [ ! -d "$ILL_DIR" ]; then
  log_error "Illustrator 2021 installation not found at $ILL_DIR"
  exit 1
fi

if [ -f "$ILL_DIR/Support Files/Contents/Windows/Illustrator.exe" ]; then
  log_success "Illustrator 2021 installation verified"
else
  log_error "Illustrator executable not found"
  exit 1
fi

# Step 2: Stop running processes
log_step "Stopping Illustrator processes..."
wineserver -k 2>/dev/null || true
sleep 2

# Kill any remaining Illustrator processes
pkill -f "Illustrator.exe" 2>/dev/null || true
pkill -f "launcher.sh" 2>/dev/null || true

log_success "Processes stopped"

# Step 3: Remove desktop entry
log_step "Removing desktop entry..."
DESKTOP_ENTRY="$HOME/.local/share/applications/illustrator2021.desktop"
if [ -f "$DESKTOP_ENTRY" ]; then
  rm -f "$DESKTOP_ENTRY"
  log_success "Desktop entry removed"
else
  log_info "No desktop entry found"
fi

# Step 4: Remove icon
log_step "Removing icon..."
ICON_FILE="$HOME/.local/share/icons/illustrator2021.svg"
if [ -f "$ICON_FILE" ]; then
  rm -f "$ICON_FILE"
  log_success "Icon removed"
else
  log_info "No icon found"
fi

# Step 5: Remove installation files
log_step "Removing installation files..."
if [ "$VERBOSE" = true ]; then
  rm -rf "$ILL_DIR"
  rm -rf "$WINEPREFIX"
else
  rm -rf "$ILL_DIR" 2>/dev/null
  rm -rf "$WINEPREFIX" 2>/dev/null
fi

log_success "Installation files removed"

# Step 6: Clean up cache if requested
if [ "$PURGE_ALL" = true ]; then
  log_step "Cleaning cache files..."
  
  # Remove Illustrator cache
  ILLUSTRATOR_CACHE="$HOME/.cache/illustrator2021-installer"
  if [ -d "$ILLUSTRATOR_CACHE" ]; then
    if [ "$VERBOSE" = true ]; then
      rm -rf "$ILLUSTRATOR_CACHE"
    else
      rm -rf "$ILLUSTRATOR_CACHE" 2>/dev/null
    fi
    log_success "Illustrator cache removed"
  else
    log_info "No Illustrator cache found"
  fi
else
  log_info "Cache files preserved (use --purge to remove)"
fi

# Final cleanup
wineserver -k 2>/dev/null || true
sleep 1

# Check if installation directory is empty and offer to remove it
if [ -d "$INSTALL_DIR" ]; then
  REMAINING_FILES=$(find "$INSTALL_DIR" -type f 2>/dev/null | wc -l)
  if [ "$REMAINING_FILES" -eq 0 ]; then
    log_info "Installation directory is empty"
    if [ "$VERBOSE" = true ]; then
      rmdir "$INSTALL_DIR" 2>/dev/null || true
    else
      rmdir "$INSTALL_DIR" 2>/dev/null || true
    fi
  else
    log_warning "Installation directory still contains files"
    if [ "$VERBOSE" = true ]; then
      echo "Remaining files:"
      find "$INSTALL_DIR" -type f 2>/dev/null | head -10
    fi
  fi
fi

echo ""
echo -e "${BOLD}${GREEN}Uninstallation completed successfully!${NC}"
echo ""
echo -e "${BLUE}Removed:${NC}"
echo "  - Illustrator 2021 installation"
echo "  - Wine prefix and configuration"
echo "  - Desktop entry"
echo "  - Icon"
if [ "$PURGE_ALL" = true ]; then
  echo "  - Cache files"
fi
echo ""
echo -e "${GREEN}✓${NC} Illustrator 2021 uninstalled"
