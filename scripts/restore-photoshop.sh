#!/bin/bash
# Photoshop 2021 Restore Script for Linux

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
      echo "Usage: $0 [OPTIONS] backup-file.tar.xz /path/to/restore"
      echo ""
      echo "Options:"
      echo "  -v, --verbose         Show detailed output"
      echo "  -k, --keep-permissions Keep original file permissions"
      echo "  -h, --help            Show this help message"
      exit 0
      ;;
    *)
      if [ -z "$BACKUP_FILE" ]; then
        BACKUP_FILE="$1"
      elif [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="$1"
      else
        echo "Too many arguments"
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$BACKUP_FILE" ] || [ -z "$INSTALL_DIR" ]; then
  echo "Usage: $0 [OPTIONS] backup-file.tar.xz /path/to/restore"
  echo "Use -h for help"
  exit 1
fi

# Validate backup file
if [ ! -f "$BACKUP_FILE" ]; then
  log_error "Backup file not found: $BACKUP_FILE"
  exit 1
fi

# Progress tracking
TOTAL_STEPS=6
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

print_header "           Adobe Photoshop 2021 Restore Tool              "

log_step "Validating backup..."
# Extract and read metadata
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Determine compression type
if [[ "$BACKUP_FILE" == *.xz ]]; then
  tar -xJf "$BACKUP_FILE" photoshop-backup-metadata.txt 2>/dev/null || true
else
  tar -xf "$BACKUP_FILE" photoshop-backup-metadata.txt 2>/dev/null || true
fi

if [ -f "photoshop-backup-metadata.txt" ]; then
  ORIGINAL_PATH=$(grep "Original Path:" photoshop-backup-metadata.txt | cut -d' ' -f3-)
  BACKUP_DATE=$(grep "Backup Date:" photoshop-backup-metadata.txt | cut -d' ' -f3-)
  log_info "Backup created on: $BACKUP_DATE"
  log_info "Original path: $ORIGINAL_PATH"
  log_success "Backup metadata validated"
else
  log_warning "No metadata found in backup"
  ORIGINAL_PATH="Unknown"
fi

# Clean up temp dir
rm -rf "$TEMP_DIR"

log_step "Preparing restore location..."
# Create installation directory
mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"

# Check if directory is empty
if [ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
  log_error "Installation directory is not empty"
  log_error "Please choose an empty directory or remove existing files"
  exit 1
fi

log_success "Restore location prepared"

log_step "Extracting backup..."
cd "$(dirname "$INSTALL_DIR")"
INSTALL_BASENAME="$(basename "$INSTALL_DIR")"

if [ "$VERBOSE" = true ]; then
  if [[ "$BACKUP_FILE" == *.xz ]]; then
    tar -xvJf "$BACKUP_FILE" --strip-components=1 -C "$INSTALL_BASENAME"
  else
    tar -xvf "$BACKUP_FILE" --strip-components=1 -C "$INSTALL_BASENAME"
  fi
else
  if [[ "$BACKUP_FILE" == *.xz ]]; then
    tar -xJf "$BACKUP_FILE" --strip-components=1 -C "$INSTALL_BASENAME" 2>/dev/null
  else
    tar -xf "$BACKUP_FILE" --strip-components=1 -C "$INSTALL_BASENAME" 2>/dev/null
  fi
fi

log_success "Backup extracted"

log_step "Updating paths..."
# Update launcher script with new paths
LAUNCHER="$INSTALL_DIR/launch-photoshop.sh"
if [ -f "$LAUNCHER" ]; then
  # Update all absolute paths in the launcher
  sed -i "s|PATH=.*|PATH=\"$INSTALL_DIR/wine-9.0/bin:\$PATH\"|g" "$LAUNCHER"
  sed -i "s|LD_LIBRARY_PATH=.*|LD_LIBRARY_PATH=\"$INSTALL_DIR/wine-9.0/lib:$INSTALL_DIR/wine-9.0/lib64:\${LD_LIBRARY_PATH}\"|g" "$LAUNCHER"
  sed -i "s|WINEPREFIX=.*|WINEPREFIX=\"$INSTALL_DIR/Adobe-Photoshop\"|g" "$LAUNCHER"
  sed -i "s|WINELOADER=.*|WINELOADER=\"$INSTALL_DIR/wine-9.0/bin/wine\"|g" "$LAUNCHER"
  sed -i "s|WINEDLLPATH=.*|WINEDLLPATH=\"$INSTALL_DIR/wine-9.0/lib/wine:$INSTALL_DIR/wine-9.0/lib64/wine\"|g" "$LAUNCHER"
  sed -i "s|cd.*|cd \"\$WINEPREFIX/drive_c/Program Files/Adobe/Adobe Photoshop 2021\"|g" "$LAUNCHER"
  sed -i "s|\"\$WINE_DIR/bin/wine\"|\"\$WINELOADER\"|g" "$LAUNCHER"
  
  chmod +x "$LAUNCHER"
  log_success "Launcher script updated"
fi

# Update desktop entries if they exist
for desktop in "$INSTALL_DIR"/*.desktop; do
  if [ -f "$desktop" ]; then
    sed -i "s|$ORIGINAL_PATH|$INSTALL_DIR|g" "$desktop"
    log_info "Updated desktop entry: $(basename "$desktop")"
  fi
done

log_step "Finalizing..."
# Fix permissions if requested
if [ "$KEEP_PERMISSIONS" = "false" ]; then
  # Ensure proper ownership
  chown -R "$(whoami):$(whoami)" "$INSTALL_DIR" 2>/dev/null || true
  
  # Ensure executables have proper permissions
  find "$INSTALL_DIR/wine-9.0/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
  chmod +x "$LAUNCHER" 2>/dev/null || true
  
  log_success "Permissions updated"
fi

# Recreate wine symlinks if needed
WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"
if [ -d "$WINEPREFIX" ]; then
  cd "$WINEPREFIX"
  if [ ! -L "dosdevices/c:" ]; then
    ln -sf "drive_c" "dosdevices/c:" 2>/dev/null || true
  fi
  if [ ! -L "dosdevices/z:" ]; then
    ln -sf "/" "dosdevices/z:" 2>/dev/null || true
  fi
fi

echo ""
echo -e "${BOLD}${GREEN}Restore completed successfully!${NC}"
echo ""
echo -e "${BLUE}Installation restored to:${NC} $INSTALL_DIR"
echo ""
echo -e "${BLUE}To launch Photoshop:${NC}"
echo "  $LAUNCHER"
echo ""
echo -e "${YELLOW}Note:${NC} Photoshop may need to reconfigure some settings on first launch"
echo -e "${YELLOW}      after being moved to a new system."
