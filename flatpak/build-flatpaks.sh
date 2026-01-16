#!/bin/bash

# Adobe Flatpak Build Script
# This script builds Adobe applications as Flatpaks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Set build directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_TEMP_DIR="$PROJECT_ROOT/.build-temp/flatpak"
FLATPAK_DIR="$SCRIPT_DIR"
REPO_DIR="$BUILD_TEMP_DIR/repo"
BUILD_OUTPUT_DIR="$PROJECT_ROOT/build"

# Check if we're in the right directory
if [ ! -f "$FLATPAK_DIR/com.adobe.photoshop2021.yml" ] && [ ! -f "$FLATPAK_DIR/com.adobe.illustrator2021.yml" ]; then
    error "Adobe Flatpak manifests not found in $FLATPAK_DIR"
    exit 1
fi

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v flatpak &> /dev/null; then
        error "flatpak is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v flatpak-builder &> /dev/null; then
        error "flatpak-builder is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Flathub is added
    if ! flatpak remotes | grep -q "flathub"; then
        log "Adding Flathub remote..."
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    # Install required runtimes
    log "Installing required runtimes..."
    flatpak install --user --or-update flathub org.gnome.Platform//49 org.gnome.Sdk//49 -y
    
    success "Dependencies checked and installed"
}

# Prepare build directory
prepare_build() {
    local app_name="$1"
    local build_dir="$BUILD_TEMP_DIR/build-$app_name"
    
    log "Preparing build directory for $app_name..." >&2
    
    if [ -d "$build_dir" ]; then
        log "Cleaning existing build directory..." >&2
        rm -rf "$build_dir"
    fi
    
    mkdir -p "$build_dir"
    mkdir -p "$REPO_DIR"
    
    # Return the build directory (to stdout)
    echo "$build_dir"
}

# Build Flatpak
build_flatpak() {
    local app_name="$1"
    local skip_bundle="${2:-false}"
    local manifest="$FLATPAK_DIR/com.adobe.$app_name.yml"
    
    if [ ! -f "$manifest" ]; then
        error "Manifest not found: $manifest"
        return 1
    fi
    
    log "Building $app_name Flatpak..."
    
    # Prepare build directory
    local build_dir=$(prepare_build "$app_name")
    
    # Copy required files to build directory
    log "Copying application files..."
    
    # Only copy the manifest - let flatpak-builder handle source downloads
    cp "$manifest" "$build_dir/"
    
    # Build the Flatpak
    cd "$FLATPAK_DIR"
    local manifest_file=$(basename "$manifest")
    flatpak-builder --force-clean --disable-cache --repo="$REPO_DIR" --state-dir="$BUILD_TEMP_DIR/.flatpak-builder" "$build_dir" "$build_dir/$manifest_file"
    
    if [ $? -eq 0 ]; then
        success "$app_name Flatpak built successfully!"
        
        # Install the Flatpak
        log "Installing $app_name Flatpak..."
        flatpak install --user "$REPO_DIR" com.adobe.$app_name -y
        
        success "$app_name is now installed via Flatpak!"
        log "You can run it with: flatpak run com.adobe.$app_name"
        
        # Export bundle to build directory (skip if requested)
        if [ "$skip_bundle" = "false" ]; then
            mkdir -p "$BUILD_OUTPUT_DIR"
            
            # Export bundle to build directory
            log "Exporting $app_name bundle to build directory..."
            flatpak build-bundle "$REPO_DIR" "$BUILD_OUTPUT_DIR/com.adobe.$app_name.flatpak" com.adobe.$app_name
            
            if [ $? -eq 0 ]; then
                success "$app_name bundle copied to $BUILD_OUTPUT_DIR/com.adobe.$app_name.flatpak"
            else
                warning "Failed to copy bundle to build directory, but installation succeeded"
            fi
        else
            log "Skipping bundle export (test mode)"
        fi
        
        # Cleanup build artifacts
        log "Cleaning up build artifacts..."
        rm -rf "$build_dir"
        rm -rf "$BUILD_TEMP_DIR/.flatpak-builder"
        
        # Clean temporary files
        rm -f /tmp/flatpak_build.log /tmp/flatpak_export.log /tmp/flathub_setup.log /tmp/runtimes_install.log
        
        success "Build completed and cleaned up successfully!"
    else
        error "Failed to build $app_name Flatpak"
        return 1
    fi
}

# Export Flatpak bundle
export_bundle() {
    local app_name="$1"
    
    if ! command -v flatpak &> /dev/null; then
        error "flatpak is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v flatpak-builder &> /dev/null; then
        error "flatpak-builder is not installed. Please install it first."
        exit 1
    fi
    
    log "Exporting $app_name Flatpak bundle..."
    
    mkdir -p "$REPO_DIR"
    mkdir -p "$BUILD_OUTPUT_DIR"
    
    # Export the bundle to both flatpak directory and build directory
    flatpak build-bundle "$REPO_DIR" "$FLATPAK_DIR/com.adobe.$app_name.flatpak" com.adobe.$app_name
    flatpak build-bundle "$REPO_DIR" "$BUILD_OUTPUT_DIR/com.adobe.$app_name.flatpak" com.adobe.$app_name
    
    if [ $? -eq 0 ]; then
        success "$app_name Flatpak bundle exported successfully!"
        log "Bundle saved as: $FLATPAK_DIR/com.adobe.$app_name.flatpak"
        log "Bundle also copied to: $BUILD_OUTPUT_DIR/com.adobe.$app_name.flatpak"
    else
        error "Failed to export $app_name Flatpak bundle"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "Adobe Flatpak Build Script"
    echo ""
    echo "Usage: $0 [command] [app] [options]"
    echo ""
    echo "Commands:"
    echo "  build [app] [test]     Build the specified Flatpak (photoshop2021, illustrator2021)"
    echo "                          Add 'test' to skip bundle export"
    echo "  export [app]    Export the specified Flatpak as a bundle"
    echo "  clean           Clean all build artifacts"
    echo ""
    echo "Examples:"
    echo "  $0 build photoshop2021"
    echo "  $0 build illustrator2021 test"
    echo "  $0 export photoshop2021"
    echo "  $0 clean"
}

# Clean build artifacts
clean_build() {
    log "Cleaning build artifacts..."
    
    rm -rf "$BUILD_TEMP_DIR"
    rm -rf "$FLATPAK_DIR"/*.flatpak
    rm -rf "$BUILD_OUTPUT_DIR"/*.flatpak
    rm -f /tmp/flatpak_*.log
    
    success "Build artifacts cleaned successfully!"
}

# Main script logic
case "${1:-}" in
    "build")
        case "${2:-}" in
            "photoshop2021"|"illustrator2021")
                check_dependencies
                if [ "${3:-}" = "test" ]; then
                    build_flatpak "$2" true
                else
                    build_flatpak "$2" false
                fi
                ;;
            *)
                error "Unknown application: ${2:-}"
                show_usage
                exit 1
                ;;
        esac
        ;;
    "export")
        case "${2:-}" in
            "photoshop2021"|"illustrator2021")
                export_bundle "$2"
                ;;
            *)
                error "Unknown application: ${2:-}"
                show_usage
                exit 1
                ;;
        esac
        ;;
    "clean")
        clean_build
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

success "Build process completed!"
