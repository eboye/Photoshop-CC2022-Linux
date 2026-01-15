#!/bin/bash
# Illustrator 2021 Desktop Entry Creator

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

print_header "      Illustrator 2021 Desktop Entry Creator"

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
log_step "Verifying Illustrator 2021 installation..."
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator-2021"
LAUNCHER="$INSTALL_DIR/launch-illustrator.sh"

# Check for both launcher and executable
ILL_EXE="$WINEPREFIX/drive_c/Program Files/Adobe Illustrator 2021/Support Files/Contents/Windows/Illustrator.exe"

if [ ! -f "$LAUNCHER" ] && [ ! -f "$ILL_EXE" ]; then
  log_error "Neither launcher nor Illustrator executable found"
  log_error "Expected launcher: $LAUNCHER"
  log_error "Expected executable: $ILL_EXE"
  exit 1
fi

# Create launcher if missing but executable exists
if [ ! -f "$LAUNCHER" ] && [ -f "$ILL_EXE" ]; then
  log_info "Creating launcher script..."
  WINE_DIR="$INSTALL_DIR/wine-9.0"
  
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

log_success "Illustrator 2021 installation verified"

# Step 2: Check existing desktop entry
log_step "Checking existing desktop entry..."
DESKTOP_ENTRY="$HOME/.local/share/applications/illustrator2021.desktop"

if [ -f "$DESKTOP_ENTRY" ] && [ "$FORCE" != "true" ]; then
  log_error "Desktop entry already exists. Use --force to overwrite."
  exit 1
fi

if [ -f "$DESKTOP_ENTRY" ] && [ "$FORCE" = "true" ]; then
  rm -f "$DESKTOP_ENTRY"
  log_info "Removed existing desktop entry"
fi

# Step 3: Handle icon (local only)
log_step "Setting up icon..."
ICON_FILE="$HOME/.local/share/icons/illustrator2021.svg"

mkdir -p ~/.local/share/icons/

# Use local icon if exists, otherwise use generic icon
if [ -f "$ICON_FILE" ] && [ "$FORCE" != "true" ]; then
  log_info "Icon already exists"
  ICON_NAME="illustrator2021"
else
  # Try to find local icon first
  LOCAL_ICON_LOCATIONS=(
    "$HOME/AdobeIllustrator2021.svg"
    "$(dirname "$SCRIPT_DIR")/AdobeIllustrator2021.svg"
    "$INSTALL_DIR/AdobeIllustrator2021.svg"
  )
  
  ICON_FOUND=false
  for icon_path in "${LOCAL_ICON_LOCATIONS[@]}"; do
    if [ -f "$icon_path" ]; then
      cp "$icon_path" "$ICON_FILE"
      ICON_NAME="illustrator2021"
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

# Step 4: Create desktop entry
log_step "Creating desktop entry..."

# Set default name if not provided
if [ -z "$DESKTOP_NAME" ]; then
  DESKTOP_NAME="Adobe Illustrator 2021"
fi

# Create desktop entry
cat > "$DESKTOP_ENTRY" << EOF
[Desktop Entry]
Name=$DESKTOP_NAME
Exec=bash -c "$LAUNCHER %F"
Type=Application
Comment=Illustrator 2021 (Wine)
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
echo -e "${BLUE}Icon:${NC} $ICON_FILE"
echo ""
echo -e "${BLUE}You can now launch Illustrator from:${NC}"
echo "  - Applications menu"
echo "  - Desktop (if your system supports it)"
echo "  - Command line: gtk-launch illustrator2021"
echo ""
echo -e "${GREEN}✓${NC} Desktop entry creation completed"
