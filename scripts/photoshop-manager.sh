#!/bin/bash
# Photoshop 2021 Manager - TUI for all Photoshop scripts

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

# Check for dialog or whiptail
DIALOG_CMD=""
if command -v dialog >/dev/null 2>&1; then
  DIALOG_CMD="dialog"
elif command -v whiptail >/dev/null 2>&1; then
  DIALOG_CMD="whiptail"
else
  log_error "Requires 'dialog' or 'whiptail' to run"
  log_info "Install with: sudo apt install dialog (Ubuntu/Debian)"
  log_info "Install with: sudo dnf install dialog (Fedora)"
  log_info "Install with: sudo pacman -S dialog (Arch)"
  exit 1
fi

# Global variables
SELECTED_SCRIPT=""
INSTALL_PATH=""
LAST_PATH_FILE="$HOME/.photoshop_last_path"
VERBOSE=false
KEEP_CACHE=false
SKIP_VERIFY=false
SKIP_APPEARANCE=false
PURGE=false
KEEP_PERMISSIONS=false

# Load last used path
load_last_path() {
  if [ -f "$LAST_PATH_FILE" ]; then
    INSTALL_PATH=$(cat "$LAST_PATH_FILE")
  else
    INSTALL_PATH="$HOME/Photoshop2021"
  fi
}

# Save last used path
save_last_path() {
  echo "$INSTALL_PATH" > "$LAST_PATH_FILE"
}

# Show main menu
show_main_menu() {
  local choice
  choice=$($DIALOG_CMD --title "Photoshop 2021 Manager" \
                    --menu "Select an action:" \
                    15 60 5 \
                    "1" "Install Photoshop (Standard)" \
                    "2" "Install Photoshop (with Camera Raw)" \
                    "3" "Uninstall Photoshop" \
                    "4" "Backup Installation" \
                    "5" "Restore from Backup" \
                    3>&1 1>&2 2>&3)
  
  case $choice in
    1) SELECTED_SCRIPT="install" ;;
    2) SELECTED_SCRIPT="installcr" ;;
    3) SELECTED_SCRIPT="uninstall" ;;
    4) SELECTED_SCRIPT="backup" ;;
    5) SELECTED_SCRIPT="restore" ;;
    *) exit 0 ;;
  esac
}

# Show options for install scripts
show_install_options() {
  local temp_file=$(mktemp)
  
  $DIALOG_CMD --title "Installation Options" \
              --separate-output \
              --checklist "Select options:" \
              12 50 5 \
              "VERBOSE" "Verbose output" OFF \
              "KEEP_CACHE" "Keep downloaded cache" OFF \
              "SKIP_VERIFY" "Skip checksum verification" OFF \
              "SKIP_APPEARANCE" "Skip appearance config" OFF \
              2> "$temp_file"
  
  if [ $? -eq 0 ]; then
    VERBOSE=false
    KEEP_CACHE=false
    SKIP_VERIFY=false
    SKIP_APPEARANCE=false
    
    while read -r option; do
      case $option in
        VERBOSE) VERBOSE=true ;;
        KEEP_CACHE) KEEP_CACHE=true ;;
        SKIP_VERIFY) SKIP_VERIFY=true ;;
        SKIP_APPEARANCE) SKIP_APPEARANCE=true ;;
      esac
    done < "$temp_file"
  fi
  
  rm -f "$temp_file"
}

# Show options for uninstall script
show_uninstall_options() {
  local temp_file=$(mktemp)
  
  $DIALOG_CMD --title "Uninstall Options" \
              --separate-output \
              --checklist "Select options:" \
              8 50 2 \
              "VERBOSE" "Verbose output" OFF \
              "PURGE" "Remove cached downloads" OFF \
              2> "$temp_file"
  
  if [ $? -eq 0 ]; then
    VERBOSE=false
    PURGE=false
    
    while read -r option; do
      case $option in
        VERBOSE) VERBOSE=true ;;
        PURGE) PURGE=true ;;
      esac
    done < "$temp_file"
  fi
  
  rm -f "$temp_file"
}

# Show options for backup script
show_backup_options() {
  local temp_file=$(mktemp)
  
  $DIALOG_CMD --title "Backup Options" \
              --separate-output \
              --checklist "Select options:" \
              8 50 2 \
              "VERBOSE" "Verbose output" OFF \
              "NO_COMPRESS" "Uncompressed backup" OFF \
              2> "$temp_file"
  
  if [ $? -eq 0 ]; then
    VERBOSE=false
    local NO_COMPRESS=false
    
    while read -r option; do
      case $option in
        VERBOSE) VERBOSE=true ;;
        NO_COMPRESS) NO_COMPRESS=true ;;
      esac
    done < "$temp_file"
    
    if [ "$NO_COMPRESS" = true ]; then
      BACKUP_OPTS="--no-compress"
    else
      BACKUP_OPTS=""
    fi
  fi
  
  rm -f "$temp_file"
}

# Show options for restore script
show_restore_options() {
  local temp_file=$(mktemp)
  
  $DIALOG_CMD --title "Restore Options" \
              --separate-output \
              --checklist "Select options:" \
              8 50 2 \
              "VERBOSE" "Verbose output" OFF \
              "KEEP_PERMISSIONS" "Keep original permissions" OFF \
              2> "$temp_file"
  
  if [ $? -eq 0 ]; then
    VERBOSE=false
    KEEP_PERMISSIONS=false
    
    while read -r option; do
      case $option in
        VERBOSE) VERBOSE=true ;;
        KEEP_PERMISSIONS) KEEP_PERMISSIONS=true ;;
      esac
    done < "$temp_file"
  fi
  
  rm -f "$temp_file"
}

# Input path with tab completion
input_path() {
  local title="$1"
  local default="$2"
  local result
  
  # Clear screen and show input prompt
  clear
  echo "$title"
  echo "Press Tab for autocompletion"
  echo "Default: $default"
  echo ""
  
  # Use read -e for readline support (tab completion)
  read -e -p "Enter path: " -i "$default" result
  
  if [ -z "$result" ]; then
    result="$default"
  fi
  
  INSTALL_PATH="$result"
  save_last_path
}

# Select backup file
select_backup_file() {
  local temp_file=$(mktemp)
  
  # Find backup files in common locations
  local backup_files=()
  local locations=("$HOME" "$(pwd)" "/tmp")
  
  for location in "${locations[@]}"; do
    while IFS= read -r -d '' file; do
      backup_files+=("$(basename "$file")" "$file")
    done < <(find "$location" -maxdepth 1 -name "photoshop-2021-backup-*.tar.xz" -print0 2>/dev/null)
  done
  
  if [ ${#backup_files[@]} -eq 0 ]; then
    $DIALOG_CMD --title "Error" \
                --msgbox "No backup files found. Please ensure backup files are in:\n- Home directory\n- Current directory\n- /tmp" \
                10 50
    return 1
  fi
  
  $DIALOG_CMD --title "Select Backup File" \
              --menu "Choose backup file to restore:" \
              15 70 5 \
              "${backup_files[@]}" \
              2> "$temp_file"
  
  if [ $? -eq 0 ]; then
    BACKUP_FILE=$(cat "$temp_file")
  else
    return 1
  fi
  
  rm -f "$temp_file"
}

# Execute selected script
execute_script() {
  local cmd=""
  local title=""
  
  case $SELECTED_SCRIPT in
    install)
      title="Installing Photoshop..."
      cmd="./scripts/photoshop2021install.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$KEEP_CACHE" = true ] && cmd="$cmd -k"
      [ "$SKIP_VERIFY" = true ] && cmd="$cmd -s"
      [ "$SKIP_APPEARANCE" = true ] && cmd="$cmd --skip-appearance"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    installcr)
      title="Installing Photoshop with Camera Raw..."
      cmd="./scripts/photoshop2021installcr.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$KEEP_CACHE" = true ] && cmd="$cmd -k"
      [ "$SKIP_VERIFY" = true ] && cmd="$cmd -s"
      [ "$SKIP_APPEARANCE" = true ] && cmd="$cmd --skip-appearance"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    uninstall)
      title="Uninstalling Photoshop..."
      cmd="./scripts/uninstaller.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$PURGE" = true ] && cmd="$cmd --purge"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    backup)
      title="Creating backup..."
      cmd="./scripts/backup-photoshop.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ -n "$BACKUP_OPTS" ] && cmd="$cmd $BACKUP_OPTS"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    restore)
      title="Restoring from backup..."
      cmd="./scripts/restore-photoshop.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$KEEP_PERMISSIONS" = true ] && cmd="$cmd -k"
      cmd="$cmd \"$BACKUP_FILE\" \"$INSTALL_PATH\""
      ;;
  esac
  
  # Show confirmation
  $DIALOG_CMD --title "Confirm" \
              --yesno "Ready to execute:\n\n$cmd\n\nContinue?" \
              10 60
  
  if [ $? -ne 0 ]; then
    return
  fi
  
  # Clear screen and run command
  clear
  echo "$title"
  echo "Command: $cmd"
  echo "----------------------------------------"
  echo ""
  
  # Change to script directory
  cd "$SCRIPT_DIR"
  
  # Execute the command
  eval "$cmd"
  
  echo ""
  echo "----------------------------------------"
  echo "Press Enter to continue..."
  read -r
}

# Main program
main() {
  load_last_path
  
  while true; do
    show_main_menu
    
    # Get options based on script type
    case $SELECTED_SCRIPT in
      install|installcr)
        show_install_options
        input_path "Select Installation Directory" "$INSTALL_PATH"
        ;;
      uninstall)
        show_uninstall_options
        input_path "Select Installation Directory to Uninstall" "$INSTALL_PATH"
        ;;
      backup)
        show_backup_options
        input_path "Select Installation Directory to Backup" "$INSTALL_PATH"
        ;;
      restore)
        show_restore_options
        if ! select_backup_file; then
          continue
        fi
        input_path "Select Restore Directory" "$INSTALL_PATH"
        ;;
    esac
    
    # Execute the script
    execute_script
  done
}

# Check dependencies
if ! command -v dialog >/dev/null 2>&1 && ! command -v whiptail >/dev/null 2>&1; then
  log_error "Requires 'dialog' or 'whiptail' to run"
  exit 1
fi

# Run main program
main
