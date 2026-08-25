#!/bin/bash
# After Effects 2022 Desktop Entry Creator

set -e

# Get script directory
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
WORK_DIR="$(dirname "$SCRIPT_DIR")"

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
FORCE=false
DESKTOP_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -n|--name)
      DESKTOP_NAME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] /path/to/aftereffects/installation"
      echo ""
      echo "Options:"
      echo "  -v, --verbose      Show detailed output"
      echo "  -f, --force        Overwrite existing desktop entry"
      echo "  -n, --name NAME    Custom name for desktop entry"
      echo "  -h, --help         Show this help message"
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

print_header "      After Effects 2022 Desktop Entry Creator"

log_info "Installation directory: $INSTALL_DIR"

TOTAL_STEPS=4
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

# Step 1: Verify installation
log_step "Verifying After Effects 2022 installation..."
LAUNCHER="$INSTALL_DIR/launch-aftereffects.sh"

if [ ! -f "$LAUNCHER" ]; then
  log_error "Launcher not found at $LAUNCHER"
  exit 1
fi
log_success "Launcher verified"

# Step 2: Set up icons
log_step "Setting up application icons..."
ICON_NAME="adobe-aftereffects-2022"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"

if [ -f "$WORK_DIR/images/icons/aftereffects.png" ]; then
  cp "$WORK_DIR/images/icons/aftereffects.png" "$ICON_DIR/$ICON_NAME.png"
  log_success "Application icon installed"
fi

# Step 3: Create desktop entry
log_step "Creating desktop entry..."
APP_NAME="${DESKTOP_NAME:-Adobe After Effects 2022}"
DESKTOP_FILE="$HOME/.local/share/applications/adobe-aftereffects-2022.desktop"

mkdir -p "$(dirname "$DESKTOP_FILE")"

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=Create motion graphics and visual effects
Exec="$LAUNCHER" %F
Icon=$ICON_NAME
Terminal=false
Type=Application
Categories=Graphics;Video;AudioVideo;
MimeType=application/x-aftereffects;
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"
log_success "Desktop entry created at $DESKTOP_FILE"

# Step 4: Update desktop database
log_step "Updating desktop database..."
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
log_success "Desktop database updated"

echo ""
echo -e "${GREEN}✓${NC} Desktop integration complete"
