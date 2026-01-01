#!/bin/bash
# Common functions for Photoshop installer scripts

# Colors for better UI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# System requirements
readonly MIN_DISK_SPACE_GB=10
readonly MIN_RAM_GB=4

# Print functions
print_header() {
  local title="$1"
  echo ""
  echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
  printf "${BOLD}${CYAN}║%57s║${NC}\n" "$title"
  echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_step_header() {
  local current="$1"
  local total="$2"
  local step="$3"
  local percent=0
  if [ "$total" != "?" ]; then
    percent=$((current * 100 / total))
  fi
  echo -e "${GREEN}[${current}/${total}]${NC} ${BOLD}$step${NC} ${CYAN}(${percent}%)${NC}"
}

log_info() {
  echo -e "    ${BLUE}→${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_error() {
  echo -e "${RED}✗ ERROR:${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# System requirements check
check_requirements() {
  local install_dir="$1"
  
  # Use log_step if available (defined in main script), otherwise use print_step_header
  if declare -f log_step >/dev/null 2>&1; then
    log_step "Checking system requirements..."
  else
    print_step_header "1" "?" "Checking system requirements..."
  fi
  
  # Check disk space
  local available_space
  available_space=$(df -BG "$install_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
  if [ "$available_space" -lt "$MIN_DISK_SPACE_GB" ]; then
    log_error "Insufficient disk space. Required: ${MIN_DISK_SPACE_GB}GB, Available: ${available_space}GB"
    exit 1
  fi
  log_success "Disk space: ${available_space}GB available"
  
  # Check RAM
  local total_ram
  total_ram=$(free -g | awk 'NR==2{print $2}')
  if [ "$total_ram" -lt "$MIN_RAM_GB" ]; then
    log_error "Insufficient RAM. Required: ${MIN_RAM_GB}GB, Available: ${total_ram}GB"
    exit 1
  fi
  log_success "RAM: ${total_ram}GB available"
  
  # Check required commands
  local missing_commands=()
  for cmd in tar wget curl sha256sum xdotool; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_commands+=("$cmd")
    fi
  done
  
  if [ ${#missing_commands[@]} -gt 0 ]; then
    log_error "Missing required commands: ${missing_commands[*]}"
    if [[ " ${missing_commands[*]} " =~ " xdotool " ]]; then
      log_info "Install xdotool with:"
      log_info "  Ubuntu/Debian: sudo apt install xdotool"
      log_info "  Fedora: sudo dnf install xdotool"
      log_info "  Arch: sudo pacman -S xdotool"
    fi
    exit 1
  fi
  log_success "All required commands found"
}

# Verify file checksum
verify_checksum() {
  local file="$1"
  local expected_sha256="$2"
  local skip_verify="${3:-false}"
  
  if [ "$skip_verify" = "true" ]; then
    log_info "Skipping checksum verification"
    return 0
  fi
  
  if [ -z "$expected_sha256" ]; then
    log_info "No checksum provided - skipping verification"
    return 0
  fi
  
  if [ ! -f "$file" ]; then
    log_error "File not found: $file"
    return 1
  fi
  
  local actual_sha256
  actual_sha256=$(sha256sum "$file" | cut -d' ' -f1)
  
  if [ "$actual_sha256" != "$expected_sha256" ]; then
    log_error "Checksum verification failed for $file"
    log_error "Expected: $expected_sha256"
    log_error "Actual: $actual_sha256"
    log_error "Tip: Use --skip-verify to bypass (not recommended)"
    return 1
  fi
  
  return 0
}

# Download with resume and verification
download_file() {
  local url="$1"
  local output="$2"
  local sha256="$3"
  local description="$4"
  local skip_verify="${5:-false}"
  local cache_dir="${6:-}"
  
  if [ -f "$output" ] && verify_checksum "$output" "$sha256" "$skip_verify"; then
    log_info "Using existing $description"
    return 0
  fi
  
  log_info "Downloading $description..."
  
  # Use cache if available
  if [ -n "$cache_dir" ]; then
    local cache_file="$cache_dir/$(basename "$output")"
    if [ -f "$cache_file" ] && verify_checksum "$cache_file" "$sha256" "$skip_verify"; then
      log_info "Using cached $description"
      cp "$cache_file" "$output"
      return 0
    fi
  fi
  
  # Special handling for Google Drive URLs
  if [[ "$url" == *"drive.google.com"* ]]; then
    if command -v gdown >/dev/null 2>&1; then
      gdown "$url" -O "$output" 2>/dev/null
    else
      curl -L "${url}&confirm=t" > "$output" 2>/dev/null
    fi
  else
    # Regular download
    wget -c --show-progress "$url" -O "$output" 2>/dev/null
  fi
  
  # Verify
  if ! verify_checksum "$output" "$sha256" "$skip_verify"; then
    rm -f "$output"
    return 1
  fi
  
  # Cache if enabled
  if [ -n "$cache_dir" ]; then
    mkdir -p "$cache_dir"
    cp "$output" "$cache_file"
  fi
  
  log_success "$description downloaded and verified"
}

# Setup Wine environment
setup_wine_env() {
  local wine_dir="$1"
  local wineprefix="$2"
  
  export PATH="$wine_dir/bin:$PATH"
  export LD_LIBRARY_PATH="$wine_dir/lib:$wine_dir/lib64:${LD_LIBRARY_PATH}"
  export WINEPREFIX="$wineprefix"
  export WINELOADER="$wine_dir/bin/wine"
  export WINEDLLPATH="$wine_dir/lib/wine:$wine_dir/lib64/wine"
  export WINEDEBUG=-all
  export WINEDLLOVERRIDES="winemenubuilder.exe=d"
  
  # Suppress winetricks reporting
  export WINETRICKS_OPT_SHAREDPREFIX=0
  export W_OPT_UNATTENDED=1
}

# Wait for Photoshop to start and then close it
wait_for_photoshop() {
  local wine_dir="$1"
  local timeout="${2:-60}"
  local count=0
  
  log_info "Starting Photoshop for first-time initialization..."
  
  # Start Photoshop in background
  "$wine_dir/bin/wine" "C:/Program Files/Adobe/Adobe Photoshop 2021/Photoshop.exe" >/dev/null 2>&1 &
  local ps_pid=$!
  
  # Wait for Photoshop window to appear
  while [ $count -lt $timeout ]; do
    if command -v xdotool >/dev/null 2>&1; then
      if xdotool search --name "Photoshop" >/dev/null 2>&1; then
        log_success "Photoshop window detected"
        log_info "Waiting for complete initialization..."
        
        # Wait for Photoshop to create necessary files
        sleep 15  # Extended wait for full initialization
        
        # Check if Photoshop has created its preferences directory
        local user_appdata="$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Adobe/Adobe Photoshop 2021"
        if [ -d "$user_appdata" ]; then
          log_success "Photoshop fully initialized"
        else
          log_warning "Photoshop preferences directory not found, but continuing..."
        fi
        
        break
      fi
    fi
    sleep 1
    count=$((count + 1))
  done
  
  if [ $count -ge $timeout ]; then
    log_warning "Timeout waiting for Photoshop to start"
  fi
  
  # Close Photoshop
  log_info "Closing Photoshop..."
  kill $ps_pid 2>/dev/null || true
  wineserver -k 2>/dev/null || true
  sleep 3  # Wait for processes to fully terminate
  
  log_success "Photoshop closed"
}

# Apply appearance configuration
apply_appearance_config() {
  local install_dir="$1"
  local wine_dir="$2"
  local wineprefix="$3"
  
  log_info "Applying appearance configuration..."
  
  # Set Wine environment
  setup_wine_env "$wine_dir" "$wineprefix"
  
  # Set Windows 10 dark mode via registry
  cat > /tmp/dark-theme.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize]
"AppsUseLightTheme"=dword:00000000
"SystemUsesLightTheme"=dword:00000000

[HKEY_CURRENT_USER\Control Panel\Colors]
"Window"="255 255 255"
"WindowText"="0 0 0"
EOF
  
  # Apply registry settings
  "$wine_dir/bin/wine" regedit /C /tmp/dark-theme.reg 2>/dev/null || true
  rm -f /tmp/dark-theme.reg
  
  # Configure font settings
  cat > /tmp/font-settings.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="2"
"FontSmoothingType"=dword:00000002
"FontSmoothingGamma"=dword:00000578
"FontSmoothingOrientation"=dword:00000001
EOF
  
  "$wine_dir/bin/wine" regedit /C /tmp/font-settings.reg 2>/dev/null || true
  rm -f /tmp/font-settings.reg
  
  log_success "Appearance configuration applied"
}

# Cleanup on exit
cleanup_on_exit() {
  if [ $? -ne 0 ]; then
    log_error "Operation failed. Cleaning up..."
    wineserver -k 2>/dev/null || true
  fi
}

# Parse common arguments
parse_common_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
}
