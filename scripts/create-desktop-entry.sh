#!/bin/bash
# Create Desktop Entry for Photoshop 2021

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
INSTALL_DIR=""
DESKTOP_NAME=""
ICON_PATH=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--name)
      DESKTOP_NAME="$2"
      shift 2
      ;;
    -i|--icon)
      ICON_PATH="$2"
      shift 2
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] /path/to/photoshop/installation"
      echo ""
      echo "Options:"
      echo "  -n, --name NAME    Custom name for desktop entry (default: Photoshop 2021)"
      echo "  -i, --icon PATH    Path to icon file (default: creates symbolic icon)"
      echo "  -f, --force        Overwrite existing desktop entry"
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
  echo "Usage: $0 [OPTIONS] /path/to/photoshop/installation"
  echo "Use -h for help"
  exit 1
fi

# Validate installation directory
if [ ! -d "$INSTALL_DIR" ]; then
  log_error "Installation directory does not exist: $INSTALL_DIR"
  exit 1
fi

# Check if it's a Photoshop installation
LAUNCHER="$INSTALL_DIR/launch-photoshop.sh"
if [ ! -f "$LAUNCHER" ]; then
  log_error "Not a valid Photoshop installation directory"
  log_error "Missing launch-photoshop.sh"
  exit 1
fi

# Set default name
if [ -z "$DESKTOP_NAME" ]; then
  DESKTOP_NAME="Photoshop 2021"
fi

# XDG directories
USER_DESKTOP_DIR="$HOME/Desktop"
USER_APPLICATIONS_DIR="$HOME/.local/share/applications"
SYSTEM_APPLICATIONS_DIR="/usr/share/applications"

# Determine where to install
DESKTOP_FILE_DIR="$USER_APPLICATIONS_DIR"
DESKTOP_FILE="$DESKTOP_FILE_DIR/adobe-photoshop-2021.desktop"

# Check if desktop file already exists
if [ -f "$DESKTOP_FILE" ] && [ "$FORCE" != "true" ]; then
  log_error "Desktop entry already exists: $DESKTOP_FILE"
  log_error "Use --force to overwrite"
  exit 1
fi

print_header "           Creating Desktop Entry for Photoshop 2021        "

log_step "Validating installation..."
log_success "Photoshop installation found"

log_step "Preparing desktop entry..."
# Create directories
mkdir -p "$DESKTOP_FILE_DIR"

# Handle icon
if [ -z "$ICON_PATH" ]; then
  # Create a symbolic icon using ImageMagick if available
  ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
  mkdir -p "$ICON_DIR"
  ICON_PATH="$ICON_DIR/adobe-photoshop-2021.png"
  
  if command -v convert >/dev/null 2>&1; then
    # Create a simple icon
    convert -size 256x256 xc:blue \
            -font Arial -pointsize 48 -fill white -gravity center \
            -annotate +0+0 "Ps" \
            "$ICON_PATH" 2>/dev/null || true
  fi
  
  # If icon creation failed, use a generic icon
  if [ ! -f "$ICON_PATH" ]; then
    ICON_PATH="applications-graphics"
  fi
fi

log_step "Creating desktop entry..."
# Create the desktop file
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Name=$DESKTOP_NAME
Exec=$LAUNCHER %F
Icon=$ICON_PATH
Type=Application
StartupWMClass=photoshop.exe
Categories=Graphics;Photography;
MimeType=image/jpeg;image/png;image/tiff;image/bmp;image/gif;image/webp;image/ico;
EOF

# Make executable
chmod +x "$DESKTOP_FILE"

log_success "Desktop entry created"

log_step "Finalizing..."
# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$USER_APPLICATIONS_DIR" 2>/dev/null || true
fi

# Also create on desktop if it exists
if [ -d "$USER_DESKTOP_DIR" ]; then
  cp "$DESKTOP_FILE" "$USER_DESKTOP_DIR/"
  # Make desktop shortcut trusted on GNOME-based systems
  if command -v gio >/dev/null 2>&1; then
    gio set "$USER_DESKTOP_DIR/adobe-photoshop-2021.desktop" \
           metadata::trusted true 2>/dev/null || true
  fi
  log_success "Desktop shortcut created"
fi

echo ""
echo -e "${BOLD}${GREEN}Desktop entry created successfully!${NC}"
echo ""
echo -e "${BLUE}Desktop file:${NC} $DESKTOP_FILE"
echo ""
echo -e "${BLUE}To launch Photoshop:${NC}"
echo "  - From applications menu: Graphics → $DESKTOP_NAME"
echo "  - From desktop: Double-click the icon"
echo "  - From terminal: gtk-launch adobe-photoshop-2021"
echo ""
echo -e "${YELLOW}Note:${NC} If the icon doesn't appear, log out and log back in"
