#!/bin/bash
# Illustrator 2021 Backup Script for Linux

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
      echo "Usage: $0 [OPTIONS] /path/to/illustrator/installation"
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
  echo "Error: Installation directory required"
  echo "Usage: $0 [OPTIONS] /path/to/illustrator/installation"
  exit 1
fi

# Normalize installation directory
INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"

# Check if installation exists
WINEPREFIX="$INSTALL_DIR/Adobe-Illustrator-2021"
ILL_DIR="$WINEPREFIX/drive_c/Program Files/Adobe Illustrator 2021"

if [ ! -d "$ILL_DIR" ]; then
  log_error "Illustrator 2021 installation not found at $ILL_DIR"
  exit 1
fi

# Set output directory
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$HOME"
fi

OUTPUT_DIR="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"

# Generate backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="illustrator-2021-backup-$TIMESTAMP"

if [ "$COMPRESS" = true ]; then
  BACKUP_FILE="$OUTPUT_DIR/$BACKUP_NAME.tar.xz"
else
  BACKUP_FILE="$OUTPUT_DIR/$BACKUP_NAME.tar"
fi

print_header "      Illustrator 2021 Backup Tool"

log_info "Installation directory: $INSTALL_DIR"
log_info "Output directory: $OUTPUT_DIR"
log_info "Backup file: $(basename "$BACKUP_FILE")"

# Progress tracking
TOTAL_STEPS=5
CURRENT_STEP=0

log_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
  echo -e "${GREEN}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC} ${CYAN}(${percent}%)${NC}"
}

# Step 1: Verify installation
log_step "Verifying Illustrator 2021 installation..."
if [ -f "$ILL_DIR/Support Files/Contents/Windows/Illustrator.exe" ]; then
  log_success "Illustrator 2021 installation verified"
else
  log_error "Illustrator executable not found"
  exit 1
fi

# Step 2: Check available space
log_step "Checking disk space..."
REQUIRED_SPACE=$(du -sb "$ILL_DIR" | cut -f1)
AVAILABLE_SPACE=$(df "$OUTPUT_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_BYTES=$((AVAILABLE_SPACE * 1024))

if [ "$AVAILABLE_SPACE_BYTES" -lt "$REQUIRED_SPACE" ]; then
  log_error "Not enough disk space. Required: $((REQUIRED_SPACE/1024/1024))MB, Available: $((AVAILABLE_SPACE/1024))MB"
  exit 1
fi

log_success "Disk space check passed"

# Step 3: Create backup directory
log_step "Preparing backup..."
TEMP_DIR="$OUTPUT_DIR/.illustrator2021_backup_$$"
mkdir -p "$TEMP_DIR"

# Copy Illustrator installation
log_info "Copying Illustrator files..."
if [ "$VERBOSE" = true ]; then
  cp -r "$ILL_DIR" "$TEMP_DIR/"
  cp -r "$WINEPREFIX" "$TEMP_DIR/wineprefix"
else
  cp -r "$ILL_DIR" "$TEMP_DIR/" 2>/dev/null
  cp -r "$WINEPREFIX" "$TEMP_DIR/wineprefix" 2>/dev/null
fi

# Copy launcher if exists
LAUNCHER="$WINEPREFIX/drive_c/launcher.sh"
if [ -f "$LAUNCHER" ]; then
  cp "$LAUNCHER" "$TEMP_DIR/"
fi

log_success "Files copied to temporary directory"

# Step 4: Create archive
log_step "Creating backup archive..."
cd "$TEMP_DIR"

if [ "$COMPRESS" = true ]; then
  if [ "$VERBOSE" = true ]; then
    tar -cJf "$BACKUP_FILE" .
  else
    tar -cJf "$BACKUP_FILE" 2>/dev/null
  fi
else
  if [ "$VERBOSE" = true ]; then
    tar -cf "$BACKUP_FILE" .
  else
    tar -cf "$BACKUP_FILE" 2>/dev/null
  fi
fi

cd "$OUTPUT_DIR"
rm -rf "$TEMP_DIR"

# Verify backup was created
if [ -f "$BACKUP_FILE" ]; then
  BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  log_success "Backup created: $BACKUP_SIZE"
else
  log_error "Backup creation failed"
  exit 1
fi

# Step 5: Verify backup integrity
log_step "Verifying backup integrity..."
if tar -tf "$BACKUP_FILE" >/dev/null 2>&1; then
  log_success "Backup integrity verified"
else
  log_error "Backup integrity check failed"
  rm -f "$BACKUP_FILE"
  exit 1
fi

echo ""
echo -e "${BOLD}${GREEN}Backup completed successfully!${NC}"
echo ""
echo -e "${BLUE}Backup file:${NC} $BACKUP_FILE"
echo -e "${BLUE}Size:${NC} $BACKUP_SIZE"
echo ""
echo -e "${BLUE}To restore:${NC}"
echo "  ./restore-illustrator2021.sh \"$BACKUP_FILE\" /path/to/restore/directory"
echo ""
echo -e "${GREEN}✓${NC} Illustrator 2021 backup completed"
