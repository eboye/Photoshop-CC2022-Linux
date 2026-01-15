#!/bin/bash
# Adobe Creative Suite Manager - TUI for Photoshop and Illustrator scripts

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
BACKUP_FILE=""
BASE_PATH_FILE="$HOME/.adobe_base_path"
VERBOSE=false
KEEP_CACHE=false
SKIP_VERIFY=false
SKIP_APPEARANCE=false
PURGE=false
KEEP_PERMISSIONS=false
DESKTOP_NAME=""
FORCE_DESKTOP=false

# Load base path
load_base_path() {
  if [ -f "$BASE_PATH_FILE" ]; then
    BASE_PATH=$(cat "$BASE_PATH_FILE")
  else
    BASE_PATH="$HOME/AdobeApps"
  fi
}

# Get app-specific installation path
get_app_path() {
  local app_name="$1"
  case "$app_name" in
    photoshop)
      INSTALL_PATH="$BASE_PATH/Photoshop2021"
      ;;
    illustrator)
      INSTALL_PATH="$BASE_PATH/IllustratorCC17"
      ;;
    illustrator2021)
      INSTALL_PATH="$BASE_PATH/Illustrator2021"
      ;;
    *)
      INSTALL_PATH="$BASE_PATH/$app_name"
      ;;
  esac
}

# Save base path
save_base_path() {
  echo "$BASE_PATH" > "$BASE_PATH_FILE"
}

# Show main menu
show_main_menu() {
  local choice
  choice=$($DIALOG_CMD --title "Adobe Creative Suite Manager" \
                    --menu "Select an action:" \
                    22 60 12 \
                    "1" "Install Photoshop (Standard)" \
                    "2" "Install Photoshop (with Camera Raw)" \
                    "3" "Install Illustrator CC 17" \
                    "4" "Install Illustrator 2021" \
                    "5" "Uninstall Photoshop" \
                    "6" "Uninstall Illustrator CC 17" \
                    "7" "Uninstall Illustrator 2021" \
                    "8" "Backup Installation" \
                    "9" "Restore from Backup" \
                    "10" "Utilities" \
                    3>&1 1>&2 2>&3)
  
  case $choice in
    1) SELECTED_SCRIPT="install" ;;
    2) SELECTED_SCRIPT="installcr" ;;
    3) SELECTED_SCRIPT="illustrator" ;;
    4) SELECTED_SCRIPT="illustrator2021" ;;
    5) SELECTED_SCRIPT="uninstall" ;;
    6) SELECTED_SCRIPT="uninstall-illustrator" ;;
    7) SELECTED_SCRIPT="uninstall-illustrator2021" ;;
    8) SELECTED_SCRIPT="backup" ;;
    9) SELECTED_SCRIPT="restore" ;;
    10) show_utilities_menu ;;
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

# Show options for desktop entry
show_desktop_options() {
  local temp_file=$(mktemp)
  
  # Get custom name
  DESKTOP_NAME=$($DIALOG_CMD --title "Desktop Entry" \
                             --inputbox "Enter name for desktop entry:" \
                             8 40 "Photoshop 2021" \
                             3>&1 1>&2 2>&3)
  
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Show force option
  $DIALOG_CMD --title "Desktop Entry" \
              --yesno "Overwrite existing desktop entry?" \
              6 40
  
  if [ $? -eq 0 ]; then
    FORCE_DESKTOP=true
  else
    FORCE_DESKTOP=false
  fi
}

# Show options for Illustrator install
show_illustrator_options() {
  local temp_file=$(mktemp)
  
  $DIALOG_CMD --title "Illustrator Installation Options" \
              --separate-output \
              --checklist "Select options:" \
              10 50 3 \
              "VERBOSE" "Verbose output" OFF \
              "KEEP_CACHE" "Keep downloaded cache" OFF \
              "SKIP_VERIFY" "Skip checksum verification" OFF \
              2> "$temp_file"
  
  if [ $? -eq 0 ]; then
    VERBOSE=false
    KEEP_CACHE=false
    SKIP_VERIFY=false
    
    while read -r option; do
      case $option in
        VERBOSE) VERBOSE=true ;;
        KEEP_CACHE) KEEP_CACHE=true ;;
        SKIP_VERIFY) SKIP_VERIFY=true ;;
      esac
    done < "$temp_file"
  fi
  
  rm -f "$temp_file"
}

# Show options for Illustrator 2021 install
show_illustrator2021_options() {
  local temp_file=$(mktemp)
  
  $DIALOG_CMD --title "Illustrator 2021 Installation Options" \
              --separate-output \
              --checklist "Select options:" \
              11 50 4 \
              "VERBOSE" "Verbose output" OFF \
              "KEEP_CACHE" "Keep downloaded cache" OFF \
              "SKIP_VERIFY" "Skip checksum verification" OFF \
              "NO_DESKTOP" "Skip desktop entry creation" OFF \
              2> "$temp_file"
  
  if [ $? -eq 0 ]; then
    VERBOSE=false
    KEEP_CACHE=false
    SKIP_VERIFY=false
    CREATE_DESKTOP=true
    
    while read -r option; do
      case $option in
        VERBOSE) VERBOSE=true ;;
        KEEP_CACHE) KEEP_CACHE=true ;;
        SKIP_VERIFY) SKIP_VERIFY=true ;;
        NO_DESKTOP) CREATE_DESKTOP=false ;;
      esac
    done < "$temp_file"
  fi
  
  rm -f "$temp_file"
}

# Show utilities menu
show_utilities_menu() {
  local choice
  choice=$($DIALOG_CMD --title "Utilities" \
                    --menu "Select utility:" \
                    10 50 3 \
                    "1" "System Information" \
                    "2" "Clear All Caches" \
                    "3" "Back to Main Menu" \
                    3>&1 1>&2 2>&3)
  
  case $choice in
    1) show_system_info ;;
    2) clear_all_caches ;;
    3) return ;;
    *) return ;;
  esac
}

# Show system information
show_system_info() {
  local temp_file=$(mktemp)
  
  {
    echo "System Information"
    echo "================="
    echo "OS: $(uname -s) $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "Disk Space: $(df -h / | tail -1 | awk '{print $4}') available"
    echo ""
    echo "Base Directory:"
    if [ -f "$BASE_PATH_FILE" ]; then
      echo "Adobe Apps: $(cat "$BASE_PATH_FILE")"
    else
      echo "Adobe Apps: $HOME/AdobeApps (default)"
    fi
    echo ""
    echo "Installation Paths:"
    if [ -f "$BASE_PATH_FILE" ]; then
      local base=$(cat "$BASE_PATH_FILE")
      echo "Photoshop: $base/Photoshop2021"
      echo "Illustrator CC 17: $base/IllustratorCC17"
      echo "Illustrator 2021: $base/Illustrator2021"
    else
      echo "Photoshop: $HOME/AdobeApps/Photoshop2021"
      echo "Illustrator CC 17: $HOME/AdobeApps/IllustratorCC17"
      echo "Illustrator 2021: $HOME/AdobeApps/Illustrator2021"
    fi
    echo ""
    echo "Cache Directories:"
    echo "Photoshop: $HOME/.cache/photoshop2021cr-installer"
    echo "Illustrator CC 17: $HOME/.cache/illustratorcc17-installer"
    echo "Illustrator 2021: $HOME/.cache/illustrator2021cr-installer"
  } > "$temp_file"
  
  $DIALOG_CMD --title "System Information" \
              --textbox "$temp_file" \
              20 70
  
  rm -f "$temp_file"
}

# Clear all caches
clear_all_caches() {
  $DIALOG_CMD --title "Clear Caches" \
              --yesno "Remove all cached download files?\n\nThis will free up disk space but downloads will be needed again." \
              8 50
  
  if [ $? -eq 0 ]; then
    rm -rf "$HOME/.cache/photoshop2021cr-installer"
    rm -rf "$HOME/.cache/illustratorcc17-installer"
    rm -rf "$HOME/.cache/illustrator2021cr-installer"
    $DIALOG_CMD --title "Success" \
                --msgbox "All caches cleared successfully." \
                6 40
  fi
}

# Input path with tab completion
input_path() {
  local title="$1"
  local default="$2"
  local result
  local is_base_path_selection="$3"
  
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
  
  if [ "$is_base_path_selection" = "true" ]; then
    BASE_PATH="$result"
    save_base_path
  else
    INSTALL_PATH="$result"
  fi
}

# Select backup file
select_backup_file() {
  local temp_file=$(mktemp)
  
  # Find backup files in common locations
  local backup_files=()
  local locations=("$HOME" "$(pwd)" "/tmp")
  
  for location in "${locations[@]}"; do
    # Photoshop backups
    while IFS= read -r -d '' file; do
      backup_files+=("$(basename "$file")" "$file")
    done < <(find "$location" -maxdepth 1 -name "photoshop-2021-backup-*.tar.xz" -print0 2>/dev/null)
    
    # Illustrator CC 17 backups
    while IFS= read -r -d '' file; do
      backup_files+=("$(basename "$file")" "$file")
    done < <(find "$location" -maxdepth 1 -name "illustrator-cc17-backup-*.tar.xz" -print0 2>/dev/null)
    
    # Illustrator 2021 backups
    while IFS= read -r -d '' file; do
      backup_files+=("$(basename "$file")" "$file")
    done < <(find "$location" -maxdepth 1 -name "illustrator-2021-backup-*.tar.xz" -print0 2>/dev/null)
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

# Detect backup type
detect_backup_type() {
  if [[ "$BACKUP_FILE" == *"photoshop-2021-backup"* ]]; then
    echo "photoshop"
  elif [[ "$BACKUP_FILE" == *"illustrator-cc17-backup"* ]]; then
    echo "illustrator"
  elif [[ "$BACKUP_FILE" == *"illustrator-2021-backup"* ]]; then
    echo "illustrator2021"
  else
    echo "unknown"
  fi
}

# Execute selected script
execute_script() {
  local cmd=""
  local title=""
  
  case $SELECTED_SCRIPT in
    install)
      title="Installing Photoshop..."
      cmd="./photoshop2021install.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$KEEP_CACHE" = true ] && cmd="$cmd -k"
      [ "$SKIP_VERIFY" = true ] && cmd="$cmd -s"
      [ "$SKIP_APPEARANCE" = true ] && cmd="$cmd --skip-appearance"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    installcr)
      title="Installing Photoshop with Camera Raw..."
      cmd="./photoshop2021installcr.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$KEEP_CACHE" = true ] && cmd="$cmd -k"
      [ "$SKIP_VERIFY" = true ] && cmd="$cmd -s"
      [ "$SKIP_APPEARANCE" = true ] && cmd="$cmd --skip-appearance"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    illustrator)
      title="Installing Illustrator CC 17..."
      cmd="./illustrator2021installcr.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$KEEP_CACHE" = true ] && cmd="$cmd -k"
      [ "$SKIP_VERIFY" = true ] && cmd="$cmd -s"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    illustrator2021)
      title="Installing Illustrator 2021..."
      cmd="./illustrator2021install.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$KEEP_CACHE" = true ] && cmd="$cmd -k"
      [ "$SKIP_VERIFY" = true ] && cmd="$cmd -s"
      [ "$CREATE_DESKTOP" = false ] && cmd="$cmd --no-desktop"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    uninstall)
      title="Uninstalling Photoshop..."
      cmd="./uninstaller.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$PURGE" = true ] && cmd="$cmd --purge"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    uninstall-illustrator)
      title="Uninstalling Illustrator CC 17..."
      cmd="./uninstall-illustrator.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$PURGE" = true ] && cmd="$cmd --purge"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    uninstall-illustrator2021)
      title="Uninstalling Illustrator 2021..."
      cmd="./uninstall-illustrator2021.sh"
      [ "$VERBOSE" = true ] && cmd="$cmd -v"
      [ "$PURGE" = true ] && cmd="$cmd --purge"
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    backup)
      # Detect which application to backup based on path
      if [[ "$INSTALL_PATH" == *"Illustrator2021"* ]] || [ -f "$INSTALL_PATH/launch-illustrator.sh" ]; then
        title="Creating Illustrator 2021 backup..."
        cmd="./backup-illustrator2021.sh"
        [ "$VERBOSE" = true ] && cmd="$cmd -v"
        [ -n "$BACKUP_OPTS" ] && cmd="$cmd $BACKUP_OPTS"
      elif [[ "$INSTALL_PATH" == *"IllustratorCC17"* ]] || [ -f "$INSTALL_DIR/launcher/launcher.sh" ]; then
        title="Creating Illustrator CC 17 backup..."
        cmd="./backup-illustrator.sh"
        [ "$VERBOSE" = true ] && cmd="$cmd -v"
        [ -n "$BACKUP_OPTS" ] && cmd="$cmd $BACKUP_OPTS"
      else
        title="Creating Photoshop backup..."
        cmd="./backup-photoshop.sh"
        [ "$VERBOSE" = true ] && cmd="$cmd -v"
        [ -n "$BACKUP_OPTS" ] && cmd="$cmd $BACKUP_OPTS"
      fi
      cmd="$cmd \"$INSTALL_PATH\""
      ;;
    restore)
      # Detect backup type and use appropriate restore script
      local backup_type=$(detect_backup_type)
      if [ "$backup_type" = "illustrator2021" ]; then
        title="Restoring Illustrator 2021 from backup..."
        cmd="./restore-illustrator2021.sh"
        [ "$VERBOSE" = true ] && cmd="$cmd -v"
        [ "$KEEP_PERMISSIONS" = true ] && cmd="$cmd -k"
      elif [ "$backup_type" = "illustrator" ]; then
        title="Restoring Illustrator CC 17 from backup..."
        cmd="./restore-illustrator.sh"
        [ "$VERBOSE" = true ] && cmd="$cmd -v"
        [ "$KEEP_PERMISSIONS" = true ] && cmd="$cmd -k"
      else
        title="Restoring Photoshop from backup..."
        cmd="./restore-photoshop.sh"
        [ "$VERBOSE" = true ] && cmd="$cmd -v"
        [ "$KEEP_PERMISSIONS" = true ] && cmd="$cmd -k"
      fi
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
  load_base_path
  
  while true; do
    show_main_menu
    
    # Get options based on script type
    case $SELECTED_SCRIPT in
      install|installcr)
        show_install_options
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        get_app_path "photoshop"
        ;;
      illustrator)
        show_illustrator_options
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        get_app_path "illustrator"
        ;;
      illustrator2021)
        show_illustrator2021_options
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        get_app_path "illustrator2021"
        ;;
      uninstall)
        show_uninstall_options
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        get_app_path "photoshop"
        ;;
      uninstall-illustrator)
        show_uninstall_options
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        get_app_path "illustrator"
        ;;
      uninstall-illustrator2021)
        show_uninstall_options
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        get_app_path "illustrator2021"
        ;;
      backup)
        show_backup_options
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        # Auto-detect which app to backup based on existing installations
        if [ -d "$BASE_PATH/Photoshop2021" ] && [ ! -d "$BASE_PATH/IllustratorCC17" ] && [ ! -d "$BASE_PATH/Illustrator2021" ]; then
          get_app_path "photoshop"
        elif [ -d "$BASE_PATH/IllustratorCC17" ] && [ ! -d "$BASE_PATH/Photoshop2021" ] && [ ! -d "$BASE_PATH/Illustrator2021" ]; then
          get_app_path "illustrator"
        elif [ -d "$BASE_PATH/Illustrator2021" ] && [ ! -d "$BASE_PATH/Photoshop2021" ] && [ ! -d "$BASE_PATH/IllustratorCC17" ]; then
          get_app_path "illustrator2021"
        else
          # Both exist or neither exist, ask user
          local temp_file=$(mktemp)
          $DIALOG_CMD --title "Select Application to Backup" \
                      --menu "Choose application:" \
                      12 50 3 \
                      "1" "Photoshop 2021" \
                      "2" "Illustrator CC 17" \
                      "3" "Illustrator 2021" \
                      3>&1 1>&2 2>&3 > "$temp_file"
          
          if [ $? -eq 0 ]; then
            local choice=$(cat "$temp_file")
            case $choice in
              1) get_app_path "photoshop" ;;
              2) get_app_path "illustrator" ;;
              3) get_app_path "illustrator2021" ;;
            esac
          fi
          rm -f "$temp_file"
        fi
        ;;
      restore)
        show_restore_options
        if ! select_backup_file; then
          continue
        fi
        input_path "Select Base Directory for Adobe Apps" "$BASE_PATH" true
        # Auto-detect restore path based on backup type
        local backup_type=$(detect_backup_type)
        get_app_path "$backup_type"
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
