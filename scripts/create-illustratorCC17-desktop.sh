#!/bin/bash
# Illustrator CC 17 Desktop Entry Creator

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
      echo "Usage: $0 [OPTIONS] /path/to/illustrator/installation"
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
  echo "Usage: $0 [OPTIONS] /path/to/illustrator/installation"
  exit 1
fi

# Normalize installation directory
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"

print_header "      Illustrator CC 17 Desktop Entry Creator"

log_info "Installation directory: $INSTALL_DIR"

# Progress tracking
TOTAL_STEPS=4
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

# Step 1: Verify installation
log_step "Verifying Illustrator CC 17 installation..."
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator"
ILL_DIR="$WINEPREFIX/drive_c/Program Files/Adobe/IllustratorCC17"

if [ ! -f "$ILL_DIR/IllustratorCC64.exe" ]; then
  log_error "Illustrator CC 17 executable not found at $ILL_DIR/IllustratorCC64.exe"
  exit 1
fi

log_success "Illustrator CC 17 installation verified"

# Step 2: Check existing desktop entry
log_step "Checking existing desktop entry..."
DESKTOP_ENTRY="$HOME/.local/share/applications/illustratorCC17.desktop"

if [ -f "$DESKTOP_ENTRY" ] && [ "$FORCE" != "true" ]; then
  log_error "Desktop entry already exists. Use --force to overwrite."
  exit 1
fi

if [ -f "$DESKTOP_ENTRY" ] && [ "$FORCE" = "true" ]; then
  rm -f "$DESKTOP_ENTRY"
  log_info "Removed existing desktop entry"
fi

# Step 3: Handle launcher
log_step "Setting up launcher..."
LAUNCHER="$INSTALL_DIR/launcher/launcher.sh"

if [ ! -f "$LAUNCHER" ]; then
  log_info "Creating launcher script..."
  mkdir -p "$INSTALL_DIR/launcher"
  
  cat > "$LAUNCHER" << EOF
#!/usr/bin/env bash
export WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator"
wine64 "$INSTALL_DIR/Adobe-Illustrator/IllustratorCC17/IllustratorCC64.exe" "\$@"
EOF
  
  chmod +x "$LAUNCHER"
  log_success "Launcher script created"
else
  log_success "Launcher script found"
fi

# Step 4: Handle icon (local only)
log_step "Setting up icon..."
ICON_FILE="$HOME/.local/share/icons/illustratorCC17.svg"

mkdir -p ~/.local/share/icons/

# Use local icon if exists, otherwise use generic icon
if [ -f "$ICON_FILE" ] && [ "$FORCE" != "true" ]; then
  log_info "Icon already exists"
  ICON_NAME="illustratorCC17"
else
  # Try to find local icon first
  LOCAL_ICON_LOCATIONS=(
    "$HOME/illustratorCC17.svg"
    "$(dirname "$SCRIPT_DIR")/illustratorCC17.svg"
    "$INSTALL_DIR/illustratorCC17.svg"
    "/home/eboye/GitHub/illustratorCClinux/images/AiIcon.png"
  )
  
  ICON_FOUND=false
  for icon_path in "${LOCAL_ICON_LOCATIONS[@]}"; do
    if [ -f "$icon_path" ]; then
      if [[ "$icon_path" == *.png ]]; then
        # Convert PNG to SVG if possible, or copy as PNG
        cp "$icon_path" "$HOME/.local/share/icons/illustratorCC17.png"
        ICON_NAME="illustratorCC17"
      else
        cp "$icon_path" "$ICON_FILE"
        ICON_NAME="illustratorCC17"
      fi
      ICON_FOUND=true
      log_success "Local icon copied"
      break
    fi
  done
  
  if [ "$ICON_FOUND" = false ]; then
    log_warning "No local icon found, using generic icon"
    ICON_NAME="application-x-illustrator"
  fi
fi

# Step 5: Create desktop entry
log_step "Creating desktop entry..."

# Set default name if not provided
if [ -z "$DESKTOP_NAME" ]; then
  DESKTOP_NAME="Illustrator CC 17"
fi

# Create desktop entry
cat > "$DESKTOP_ENTRY" << EOF
[Desktop Entry]
Name=$DESKTOP_NAME
Exec=bash -c "$LAUNCHER %F"
Type=Application
Comment=Illustrator CC 17 (Wine)
Categories=Graphics;
Icon=$ICON_NAME
StartupWMClass=illustrator.exe
EOF

if [ -f "$DESKTOP_ENTRY" ]; then
  log_success "Desktop entry created"
else
  log_error "Failed to create desktop entry"
  exit 1
fi

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
fi

echo ""
echo -e "${BOLD}${GREEN}Desktop entry created successfully!${NC}"
echo ""
echo -e "${BLUE}Desktop entry:${NC} $DESKTOP_ENTRY"
echo -e "${BLUE}Name:${NC} $DESKTOP_NAME"
echo -e "${BLUE}Icon:${NC} $ICON_NAME"
echo ""
echo -e "${BLUE}You can now launch Illustrator from:${NC}"
echo "  - Applications menu"
echo "  - Desktop (if your system supports it)"
echo "  - Command line: gtk-launch illustratorCC17"
echo ""
echo -e "${GREEN}✓${NC} Desktop entry creation completed"
