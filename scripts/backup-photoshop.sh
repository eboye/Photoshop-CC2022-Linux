#!/bin/bash
# Photoshop 2021 Backup Script for Linux

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
OUTPUT_DIR=""
COMPRESS=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --no-compress)
      COMPRESS=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] /path/to/photoshop/installation"
      echo ""
      echo "Options:"
      echo "  -v, --verbose      Show detailed output"
      echo "  -o, --output DIR   Output directory for backup file"
      echo "  --no-compress      Create uncompressed tarball"
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
WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"
LAUNCHER="$INSTALL_DIR/launch-photoshop.sh"
if [ ! -d "$WINEPREFIX" ] || [ ! -f "$LAUNCHER" ]; then
  log_error "Not a valid Photoshop installation directory"
  log_error "Missing Adobe-Photoshop directory or launch-photoshop.sh"
  exit 1
fi

# Set default output directory
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$(pwd)"
fi

mkdir -p "$OUTPUT_DIR"

# Progress tracking
TOTAL_STEPS=5
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

print_header "           Adobe Photoshop 2021 Backup Tool              "

log_step "Validating installation..."
log_success "Valid Photoshop installation found"

log_step "Preparing backup..."
# Create metadata file with original path info
METADATA_FILE="$OUTPUT_DIR/photoshop-backup-metadata.txt"
cat > "$METADATA_FILE" << EOF
PHOTOSHOP_BACKUP_METADATA
Original Path: $INSTALL_DIR
Backup Date: $(date -Iseconds)
Hostname: $(hostname)
User: $(whoami)
Wine Version: $("$INSTALL_DIR/wine-9.0/bin/wine" --version 2>/dev/null || echo "Unknown")
EOF

log_success "Backup metadata created"

log_step "Creating archive..."
cd "$(dirname "$INSTALL_DIR")"
INSTALL_BASENAME="$(basename "$INSTALL_DIR")"
BACKUP_FILE="$OUTPUT_DIR/photoshop-2021-backup-$(date +%Y%m%d-%H%M%S)"

# Create exclude patterns
EXCLUDE_FILE=$(mktemp)
cat > "$EXCLUDE_FILE" << EOF
# Exclude cache and temporary files
*/wine-tmp
*/allredist
*/Adobe-Photoshop/dosdevices
*/Adobe-Photoshop/drive_c/windows/temp
*/Adobe-Photoshop/drive_c/users/*/AppData/Local/Temp
*/Adobe-Photoshop/drive_c/users/*/AppData/LocalLow/Adobe/Adobe Photoshop 2021/Cache
*.log
*.tmp
*.temp
EOF

if [ "$COMPRESS" = true ]; then
  BACKUP_FILE="$BACKUP_FILE.tar.xz"
  log_info "Creating compressed archive (this may take a few minutes)..."
  
  if [ "$VERBOSE" = true ]; then
    tar -cJf "$BACKUP_FILE" \
      --exclude-from="$EXCLUDE_FILE" \
      --exclude="$METADATA_FILE" \
      "$INSTALL_BASENAME"
  else
    tar -cJf "$BACKUP_FILE" \
      --exclude-from="$EXCLUDE_FILE" \
      --exclude="$METADATA_FILE" \
      "$INSTALL_BASENAME" 2>/dev/null
  fi
else
  BACKUP_FILE="$BACKUP_FILE.tar"
  log_info "Creating uncompressed archive..."
  
  if [ "$VERBOSE" = true ]; then
    tar -cf "$BACKUP_FILE" \
      --exclude-from="$EXCLUDE_FILE" \
      --exclude="$METADATA_FILE" \
      "$INSTALL_BASENAME"
  else
    tar -cf "$BACKUP_FILE" \
      --exclude-from="$EXCLUDE_FILE" \
      --exclude="$METADATA_FILE" \
      "$INSTALL_BASENAME" 2>/dev/null
  fi
fi

# Clean up exclude file
rm -f "$EXCLUDE_FILE"

log_success "Archive created: $(basename "$BACKUP_FILE")"

log_step "Verifying backup..."
if [ -f "$BACKUP_FILE" ]; then
  local size
  size=$(du -h "$BACKUP_FILE" | cut -f1)
  log_success "Backup verified (size: $size)"
else
  log_error "Backup file not found"
  exit 1
fi

log_step "Finalizing..."
# Add metadata to archive
cd "$OUTPUT_DIR"
if [ "$COMPRESS" = true ]; then
  tar -rJf "$BACKUP_FILE" "$(basename "$METADATA_FILE")" 2>/dev/null || true
else
  tar -rf "$BACKUP_FILE" "$(basename "$METADATA_FILE")" 2>/dev/null || true
fi
rm -f "$METADATA_FILE"

echo ""
echo -e "${BOLD}${GREEN}Backup completed successfully!${NC}"
echo ""
echo -e "${BLUE}Backup file:${NC} $BACKUP_FILE"
echo -e "${BLUE}Size:${NC} $(du -h "$BACKUP_FILE" | cut -f1)"
echo ""
echo -e "${BLUE}To restore on another machine:${NC}"
echo "  ./scripts/restore-photoshop.sh $BACKUP_FILE /new/installation/path"
echo ""
echo -e "${YELLOW}Note:${NC} The backup excludes temporary files and installation cache"
echo -e "${YELLOW}      to reduce size. Photoshop will recreate these as needed."
