#!/bin/bash
# After Effects 2022 Restore Script for Linux

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
BACKUP_FILE=""
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -f|--file)
      BACKUP_FILE="$2"
      shift 2
      ;;
    -t|--target)
      TARGET_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 -f /path/to/backup.tar.xz -t /path/to/install/directory"
      echo ""
      echo "Options:"
      echo "  -v, --verbose     Show detailed output"
      echo "  -f, --file PATH   Path to backup archive"
      echo "  -t, --target DIR  Target installation directory"
      echo "  -h, --help        Show this help message"
      exit 0
      ;;
    *)
      if [ -z "$BACKUP_FILE" ]; then
        BACKUP_FILE="$1"
      elif [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$BACKUP_FILE" ] || [ -z "$TARGET_DIR" ]; then
  echo "Error: Both backup file (-f) and target directory (-t) are required"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  log_error "Backup file does not exist: $BACKUP_FILE"
  exit 1
fi

TARGET_DIR="$(mkdir -p "$TARGET_DIR" && cd "$TARGET_DIR" && pwd)"

print_header "      After Effects 2022 Restore Tool"

log_info "Restoring from: $BACKUP_FILE"
log_info "Target directory: $TARGET_DIR"

cd "$TARGET_DIR"
tar -xf "$BACKUP_FILE"

# Recreate launcher and desktop entries
"$SCRIPT_DIR/create-aftereffects2022-desktop.sh" "$TARGET_DIR"

log_success "After Effects 2022 restored successfully!"
