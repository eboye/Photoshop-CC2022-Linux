#!/bin/bash
# Illustrator 2021 Restore Script for Linux

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
BACKUP_FILE=""
INSTALL_DIR=""
KEEP_PERMISSIONS=false
CREATE_DESKTOP=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -k|--keep-permissions)
      KEEP_PERMISSIONS=true
      shift
      ;;
    --no-desktop)
      CREATE_DESKTOP=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] backup_file /path/to/restore/directory"
      echo ""
      echo "Options:"
      echo "  -v, --verbose           Show detailed output"
      echo "  -k, --keep-permissions  Keep original permissions"
      echo "  --no-desktop           Skip desktop entry creation"
      echo "  -h, --help              Show this help message"
      exit 0
      ;;
    *)
      if [ -z "$BACKUP_FILE" ]; then
        BACKUP_FILE="$1"
      elif [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="$1"
      else
        echo "Error: Too many arguments"
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$BACKUP_FILE" ] || [ -z "$INSTALL_DIR" ]; then
  echo "Error: Backup file and installation directory required"
  echo "Usage: $0 [OPTIONS] backup_file /path/to/restore/directory"
  exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
  log_error "Backup file not found: $BACKUP_FILE"
  exit 1
fi

# Normalize installation directory
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"

print_header "      Illustrator 2021 Restore Tool"

log_info "Backup file: $BACKUP_FILE"
log_info "Restore directory: $INSTALL_DIR"

# Progress tracking
TOTAL_STEPS=5
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

# Step 1: Verify backup file
log_step "Verifying backup file..."
if ! tar -tf "$BACKUP_FILE" >/dev/null 2>&1; then
  log_error "Invalid backup file or corrupted archive"
  exit 1
fi

# Check if backup contains Illustrator files
if tar -tf "$BACKUP_FILE" | grep -q "Illustrator.exe"; then
  log_success "Backup file verified"
else
  log_error "Backup does not contain Illustrator 2021 installation"
  exit 1
fi

# Step 2: Check available space
log_step "Checking disk space..."
BACKUP_SIZE=$(du -sb "$BACKUP_FILE" | cut -f1)
# Estimate uncompressed size (roughly 3x compression ratio)
ESTIMATED_SIZE=$((BACKUP_SIZE * 3))
AVAILABLE_SPACE=$(df "$INSTALL_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_BYTES=$((AVAILABLE_SPACE * 1024))

if [ "$AVAILABLE_SPACE_BYTES" -lt "$ESTIMATED_SIZE" ]; then
  log_error "Not enough disk space. Estimated required: $((ESTIMATED_SIZE/1024/1024))MB, Available: $((AVAILABLE_SPACE/1024))MB"
  exit 1
fi

log_success "Disk space check passed"

# Step 3: Prepare restore directory
log_step "Preparing restore directory..."
if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
  log_error "Restore directory is not empty: $INSTALL_DIR"
  exit 1
fi

TEMP_DIR="$INSTALL_DIR/.restore_$$"
mkdir -p "$TEMP_DIR"

# Step 4: Extract backup
log_step "Extracting backup..."
cd "$TEMP_DIR"

if [ "$VERBOSE" = true ]; then
  if [[ "$BACKUP_FILE" == *.tar.xz ]]; then
    tar -xJf "$BACKUP_FILE"
  elif [[ "$BACKUP_FILE" == *.tar.gz ]]; then
    tar -xzf "$BACKUP_FILE"
  else
    tar -xf "$BACKUP_FILE"
  fi
else
  if [[ "$BACKUP_FILE" == *.tar.xz ]]; then
    tar -xJf "$BACKUP_FILE" 2>/dev/null
  elif [[ "$BACKUP_FILE" == *.tar.gz ]]; then
    tar -xzf "$BACKUP_FILE" 2>/dev/null
  else
    tar -xf "$BACKUP_FILE" 2>/dev/null
  fi
fi

log_success "Backup extracted"

# Step 5: Move files to final location
log_step "Installing files..."
cd "$INSTALL_DIR"

# Move Illustrator installation
if [ -d "$TEMP_DIR/Adobe Illustrator 2021" ]; then
  if [ "$KEEP_PERMISSIONS" = true ]; then
    mv "$TEMP_DIR/Adobe Illustrator 2021" "Adobe-Illustrator-2021/drive_c/Program Files/"
  else
    mkdir -p "Adobe-Illustrator-2021/drive_c/Program Files/"
    cp -r "$TEMP_DIR/Adobe Illustrator 2021" "Adobe-Illustrator-2021/drive_c/Program Files/"
  fi
  log_success "Illustrator installation restored"
else
  log_error "Illustrator installation not found in backup"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Move wine prefix if exists
if [ -d "$TEMP_DIR/wineprefix" ]; then
  if [ "$KEEP_PERMISSIONS" = true ]; then
    mv "$TEMP_DIR/wineprefix" "Adobe-Illustrator-2021/"
  else
    cp -r "$TEMP_DIR/wineprefix" "Adobe-Illustrator-2021/"
  fi
  log_success "Wine prefix restored"
else
  log_info "No wine prefix found in backup"
fi

# Move launcher if exists
if [ -f "$TEMP_DIR/launcher.sh" ]; then
  if [ "$KEEP_PERMISSIONS" = true ]; then
    mv "$TEMP_DIR/launcher.sh" "Adobe-Illustrator-2021/drive_c/"
  else
    cp "$TEMP_DIR/launcher.sh" "Adobe-Illustrator-2021/drive_c/"
  fi
  chmod +x "Adobe-Illustrator-2021/drive_c/launcher.sh"
  log_success "Launcher script restored"
else
  log_info "No launcher script found in backup"
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Verify installation
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator-2021"
ILL_DIR="$WINEPREFIX/drive_c/Program Files/Adobe Illustrator 2021"

if [ -f "$ILL_DIR/Support Files/Contents/Windows/Illustrator.exe" ]; then
  log_success "Installation verified"
else
  log_error "Installation verification failed"
  exit 1
fi

# Create desktop entry
if [ "$CREATE_DESKTOP" = true ]; then
  log_step "Creating desktop entry..."
  LAUNCHER="$WINEPREFIX/drive_c/launcher.sh"
  
  # Download icon if not exists
  if [ ! -f ~/.local/share/icons/illustrator2021.svg ]; then
    ICON_URL="https://upload.wikimedia.org/wikipedia/commons/f/fb/Adobe_Illustrator_CC_icon.svg"
    mkdir -p ~/.local/share/icons/
    if download_file "$ICON_URL" "illustrator2021.svg" "" "Illustrator icon" false "$HOME/.cache"; then
      mv "$HOME/.cache/illustrator2021.svg" ~/.local/share/icons/
    fi
  fi
  
  # Create desktop entry
  cat > ~/.local/share/applications/illustrator2021.desktop << EOF
[Desktop Entry]
Name=Adobe Illustrator 2021
Exec=bash -c "$LAUNCHER %F"
Type=Application
Comment=Illustrator 2021 (Wine)
Categories=Graphics;
Icon=illustrator2021
StartupWMClass=illustrator.exe
EOF

  if [ -f ~/.local/share/applications/illustrator2021.desktop ]; then
    log_success "Desktop entry created"
  else
    log_warning "Failed to create desktop entry"
  fi
fi

echo ""
echo -e "${BOLD}${GREEN}Restore completed successfully!${NC}"
echo ""
echo -e "${BLUE}To launch Illustrator:${NC}"
echo "  $WINEPREFIX/drive_c/launcher.sh"
echo ""
echo -e "${BLUE}Or from the applications menu:${NC}"
echo "  Look for 'Adobe Illustrator 2021'"
echo ""
if [ "$CREATE_DESKTOP" = true ]; then
  echo -e "${GREEN}✓${NC} Desktop entry created"
fi
echo -e "${GREEN}✓${NC} Illustrator 2021 restored from backup"
