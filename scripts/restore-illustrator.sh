#!/bin/bash
# Illustrator CC 17 Restore Script for Linux

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
    -h|--help)
      echo "Usage: $0 [OPTIONS] backup_file /path/to/restore/directory"
      echo ""
      echo "Options:"
      echo "  -v, --verbose           Show detailed output"
      echo "  -k, --keep-permissions  Keep original permissions"
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

print_header "      Illustrator CC 17 Restore Tool"

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
if tar -tf "$BACKUP_FILE" | grep -q "IllustratorCC64.exe"; then
  log_success "Backup file verified"
else
  log_error "Backup does not contain Illustrator installation"
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
if [ -d "$TEMP_DIR/IllustratorCC17" ]; then
  mkdir -p "Adobe-Illustrator/drive_c/Program Files/Adobe"
  if [ "$KEEP_PERMISSIONS" = true ]; then
    mv "$TEMP_DIR/IllustratorCC17" "Adobe-Illustrator/drive_c/Program Files/Adobe/"
  else
    cp -r "$TEMP_DIR/IllustratorCC17" "Adobe-Illustrator/drive_c/Program Files/Adobe/"
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
    mv "$TEMP_DIR/wineprefix" "Adobe-Illustrator/"
  else
    cp -r "$TEMP_DIR/wineprefix" "Adobe-Illustrator/"
  fi
  log_success "Wine prefix restored"
else
  log_info "No wine prefix found in backup"
fi

# Move launcher if exists
if [ -f "$TEMP_DIR/launch-illustrator.sh" ]; then
  if [ "$KEEP_PERMISSIONS" = true ]; then
    mv "$TEMP_DIR/launch-illustrator.sh" .
  else
    cp "$TEMP_DIR/launch-illustrator.sh" .
  fi
  chmod +x "launch-illustrator.sh"
  log_success "Launcher script restored"
else
  log_info "No launcher script found in backup"
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Verify installation
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator"
ILL_DIR="$WINEPREFIX/drive_c/Program Files/Adobe/IllustratorCC17"

if [ -f "$ILL_DIR/IllustratorCC64.exe" ]; then
  log_success "Installation verified"
else
  log_error "Installation verification failed"
  exit 1
fi

# Create desktop entry
log_step "Creating desktop entry..."
DESKTOP_ENTRY="$HOME/.local/share/applications/illustratorCC.desktop"
cat > "$DESKTOP_ENTRY" << EOF
[Desktop Entry]
Encoding=UTF-8
Name=Illustrator CC 17
Exec=bash $INSTALL_DIR/launch-illustrator.sh
Type=Application
StartupNotify=true
Comment=Illustrator CC 17 for Linux
Icon=application-x-illustrator
StartupWMClass=illustrator.exe
EOF

if [ -f "$DESKTOP_ENTRY" ]; then
  log_success "Desktop entry created"
else
  log_warning "Failed to create desktop entry"
fi

# Create system command
log_step "Creating system command..."
if [ -f "/usr/local/bin/illustrator" ]; then
  log_info "Removing existing illustrator command..."
  sudo rm "/usr/local/bin/illustrator" 2>/dev/null || true
fi

if sudo ln -s "$INSTALL_DIR/launch-illustrator.sh" "/usr/local/bin/illustrator" 2>/dev/null; then
  log_success "System command 'illustrator' created"
else
  log_warning "Could not create system command (requires sudo)"
fi

# Save path
echo "$INSTALL_DIR" > "$HOME/.illustrator_last_path"

echo ""
echo -e "${BOLD}${GREEN}Restore completed successfully!${NC}"
echo ""
echo -e "${BLUE}To launch Illustrator:${NC}"
echo "  $INSTALL_DIR/launch-illustrator.sh"
echo ""
echo -e "${BLUE}Or from the command line:${NC}"
echo "  cd \"$INSTALL_DIR\""
echo "  ./launch-illustrator.sh"
echo ""
echo -e "${BLUE}Or from the desktop/applications menu:${NC}"
echo "  Look for 'Illustrator CC 17' in your applications menu"
echo ""
if [ -f "/usr/local/bin/illustrator" ]; then
  echo -e "${BLUE}Or simply run:${NC}"
  echo "  illustrator"
  echo ""
fi
echo -e "${GREEN}✓${NC} Illustrator CC 17 restored from backup"
