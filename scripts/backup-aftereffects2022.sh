#!/bin/bash
# After Effects 2022 Backup Script for Linux

set -e

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

if [ -f "$LIB_DIR/common.sh" ]; then
  source "$LIB_DIR/common.sh"
else
  echo "Error: Could not find common.sh at $LIB_DIR/common.sh"
  exit 1
fi

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
      echo "Usage: $0 [OPTIONS] /path/to/aftereffects/installation"
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
  echo "Usage: $0 [OPTIONS] /path/to/aftereffects/installation"
  exit 1
fi

INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$INSTALL_DIR/backups}"
mkdir -p "$OUTPUT_DIR"

print_header "      After Effects 2022 Backup Tool"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [ "$COMPRESS" = true ]; then
  BACKUP_FILE="$OUTPUT_DIR/aftereffects2022_backup_$TIMESTAMP.tar.xz"
else
  BACKUP_FILE="$OUTPUT_DIR/aftereffects2022_backup_$TIMESTAMP.tar"
fi

log_info "Backing up from: $INSTALL_DIR"
log_info "Target backup file: $BACKUP_FILE"

# Stop wine
wineserver -k 2>/dev/null || true
sleep 1

cd "$INSTALL_DIR"
if [ "$COMPRESS" = true ]; then
  tar -cf - Adobe-AfterEffects | xz -T0 -3 > "$BACKUP_FILE"
else
  tar -cf "$BACKUP_FILE" Adobe-AfterEffects
fi

log_success "Backup completed successfully at $BACKUP_FILE"
