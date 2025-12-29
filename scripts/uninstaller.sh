#!/bin/bash
# Photoshop 2021 Uninstaller for Linux

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

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║           Adobe Photoshop 2021 Uninstaller              ║${NC}"
  echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
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

# Convert to absolute path
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"

print_header

# Check if installation exists
if [ ! -d "$WINEPREFIX" ]; then
  log_error "Photoshop installation not found at: $INSTALL_DIR"
  exit 1
fi

log_info "Removing Photoshop installation directory..."
if [ "$VERBOSE" = true ]; then
  rm -rfv "$WINEPREFIX"
else
  rm -rf "$WINEPREFIX"
fi
log_success "Photoshop installation removed"

# Remove Wine 9.0 if it exists
WINE_DIR="$INSTALL_DIR/wine-9.0"
if [ -d "$WINE_DIR" ]; then
  log_info "Removing Wine 9.0 installation..."
  if [ "$VERBOSE" = true ]; then
    rm -rfv "$WINE_DIR"
  else
    rm -rf "$WINE_DIR"
  fi
  log_success "Wine 9.0 removed"
fi

# Remove desktop entry
log_info "Removing desktop entry..."
if [ -f ~/.local/share/applications/photoshop.desktop ]; then
  rm -f ~/.local/share/applications/photoshop.desktop
  log_success "Desktop entry removed"
else
  log_info "Desktop entry not found"
fi

# Remove icon
log_info "Removing icon..."
if [ -f ~/.local/share/icons/photoshop.png ]; then
  rm -f ~/.local/share/icons/photoshop.png
  log_success "Icon removed"
else
  log_info "Icon not found"
fi

# Check if installation directory is now empty and offer to remove it
if [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
  log_info "Installation directory is empty"
  if [ "$VERBOSE" = true ]; then
    rmdir -v "$INSTALL_DIR"
  else
    rmdir "$INSTALL_DIR" 2>/dev/null || true
  fi
  log_success "Removed empty installation directory"
fi

print_header
echo -e "${GREEN}${BOLD}Photoshop has been successfully uninstalled!${NC}"
echo ""

# Display GUI notification if zenity is available
if command -v zenity >/dev/null 2>&1; then
  zenity --info --text="Photoshop CC 2021 has been successfully uninstalled." --title="Uninstall Complete" 2>/dev/null &
fi
