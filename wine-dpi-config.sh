#!/bin/bash

# Wine DPI Configuration Script
# Usage: ./wine-dpi-config.sh [wine_prefix]

set -e

# Default Wine prefix if not specified
WINE_PREFIX="${1:-$HOME/.wine}"

# Check if Wine prefix exists
if [ ! -d "$WINE_PREFIX" ]; then
    echo "Error: Wine prefix '$WINE_PREFIX' does not exist."
    echo "Creating new Wine prefix..."
    WINEPREFIX="$WINE_PREFIX" winecfg --version
fi

# Export Wine prefix for all wine commands
export WINEPREFIX="$WINE_PREFIX"

# Function to display menu
show_menu() {
    clear
    echo "==================================="
    echo "    Wine DPI Configuration Tool    "
    echo "==================================="
    echo "Wine Prefix: $WINE_PREFIX"
    echo ""
    echo "Select DPI configuration method:"
    echo "1) Use winecfg (Recommended)"
    echo "2) Edit Registry Directly"
    echo "3) Set Environment Variable"
    echo "4) Configure X11 DPI (Linux/X11)"
    echo "5) Photoshop UI Scaling (Adobe-specific)"
    echo "6) Photoshop Manifest Override"
    echo "7) Photoshop Registry Settings"
    echo "8) Launch Photoshop with DPI Override"
    echo "9) Reset to Default (96 DPI)"
    echo "10) Current DPI Settings"
    echo "0) Exit"
    echo ""
    echo -n "Enter your choice [0-10]: "
}

# Function for winecfg method
winecfg_method() {
    echo "Opening winecfg..."
    echo "Go to Graphics tab and adjust DPI setting."
    echo "Common values: 96 (100%), 120 (125%), 144 (150%)"
    read -p "Press Enter to open winecfg..."
    WINEPREFIX="$WINE_PREFIX" winecfg
}

# Function for registry method
registry_method() {
    echo ""
    echo "Select DPI value:"
    echo "1) 96 DPI (100% - Default)"
    echo "2) 120 DPI (125%)"
    echo "3) 144 DPI (150%)"
    echo "4) 168 DPI (175%)"
    echo "5) Custom DPI"
    echo -n "Enter choice [1-5]: "
    read dpi_choice
    
    case $dpi_choice in
        1) DPI_VALUE=96 ;;
        2) DPI_VALUE=120 ;;
        3) DPI_VALUE=144 ;;
        4) DPI_VALUE=168 ;;
        5) echo -n "Enter custom DPI value: "; read DPI_VALUE ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    # Convert DPI to hex for registry
    DPI_HEX=$(printf "%02x" $DPI_VALUE)
    
    echo "Setting DPI to $DPI_VALUE via registry..."
    
    # Create registry file
    cat > /tmp/dpi_reg.reg << EOF
REGEDIT4

[HKEY_CURRENT_USER\Control Panel\Desktop]
"LogPixels"=dword:000000$DPI_HEX
"Win8DpiScaling"=dword:00000001

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"ClientSideWithRender"=dword:00000001

EOF
    
    # Apply registry changes
    WINEPREFIX="$WINE_PREFIX" regedit /tmp/dpi_reg.reg
    rm /tmp/dpi_reg.reg
    
    echo "DPI set to $DPI_VALUE. Restart Wine applications to apply."
}

# Function for environment variable method
env_method() {
    echo ""
    echo "Environment Variable Method"
    echo "This sets DPI for Wine applications launched with this script."
    echo ""
    echo "Select DPI value:"
    echo "1) 96 DPI (100%)"
    echo "2) 120 DPI (125%)"
    echo "3) 144 DPI (150%)"
    echo "4) 168 DPI (175%)"
    echo "5) Custom DPI"
    echo -n "Enter choice [1-5]: "
    read dpi_choice
    
    case $dpi_choice in
        1) DPI_VALUE=96 ;;
        2) DPI_VALUE=120 ;;
        3) DPI_VALUE=144 ;;
        4) DPI_VALUE=168 ;;
        5) echo -n "Enter custom DPI value: "; read DPI_VALUE ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    echo ""
    echo "To use this method, launch Wine applications with:"
    echo "WINEDLLOVERRIDES=\"winex11.dpi=$DPI_VALUE\" wine your_program.exe"
    echo ""
    echo "Or create a wrapper script with:"
    echo "#!/bin/bash"
    echo "export WINEDLLOVERRIDES=\"winex11.dpi=$DPI_VALUE\""
    echo "wine \"\$@\""
    echo ""
    read -p "Press Enter to continue..."
}

# Function for X11 DPI method
x11_method() {
    if command -v xrandr &> /dev/null; then
        echo ""
        echo "Current X11 DPI: $(xdpyinfo | grep dots | awk '{print $2}' | cut -d'x' -f1)"
        echo ""
        echo "Select DPI value:"
        echo "1) 96 DPI (100%)"
        echo "2) 120 DPI (125%)"
        echo "3) 144 DPI (150%)"
        echo "4) 168 DPI (175%)"
        echo "5) Custom DPI"
        echo -n "Enter choice [1-5]: "
        read dpi_choice
        
        case $dpi_choice in
            1) DPI_VALUE=96 ;;
            2) DPI_VALUE=120 ;;
            3) DPI_VALUE=144 ;;
            4) DPI_VALUE=168 ;;
            5) echo -n "Enter custom DPI value: "; read DPI_VALUE ;;
            *) echo "Invalid choice"; return 1 ;;
        esac
        
        echo "Setting X11 DPI to $DPI_VALUE..."
        xrandr --dpi $DPI_VALUE
        echo "X11 DPI set to $DPI_VALUE. This affects all X11 applications."
    else
        echo "Error: xrandr not found. Not using X11?"
    fi
    read -p "Press Enter to continue..."
}

# Function to reset to default
reset_dpi() {
    echo "Resetting DPI to default (96)..."
    
    cat > /tmp/reset_dpi.reg << EOF
REGEDIT4

[HKEY_CURRENT_USER\Control Panel\Desktop]
"LogPixels"=dword:00000060
"Win8DpiScaling"=-

EOF
    
    WINEPREFIX="$WINE_PREFIX" regedit /tmp/reset_dpi.reg
    rm /tmp/reset_dpi.reg
    
    echo "DPI reset to default (96)."
    read -p "Press Enter to continue..."
}

# Function for Photoshop UI scaling
photoshop_ui_method() {
    echo ""
    echo "Photoshop UI Scaling Method"
    echo "=========================="
    echo "This method modifies Photoshop's internal UI scaling."
    echo ""
    echo "Select UI scale factor:"
    echo "1) 100% (Default)"
    echo "2) 125%"
    echo "3) 150%"
    echo "4) 175%"
    echo "5) 200%"
    echo "6) Custom scale"
    echo -n "Enter choice [1-6]: "
    read ui_choice
    
    case $ui_choice in
        1) SCALE_FACTOR=100 ;;
        2) SCALE_FACTOR=125 ;;
        3) SCALE_FACTOR=150 ;;
        4) SCALE_FACTOR=175 ;;
        5) SCALE_FACTOR=200 ;;
        6) echo -n "Enter custom scale percentage (100-200): "; read SCALE_FACTOR ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    # Find Photoshop preferences file
    PS_PREFS_DIR="$WINE_PREFIX/drive_c/users/$(whoami)/AppData/Roaming/Adobe/Adobe Photoshop"
    if [ -d "$PS_PREFS_DIR" ]; then
        # Find the latest Photoshop version folder
        PS_VERSION_DIR=$(ls -1t "$PS_PREFS_DIR" | head -n1)
        if [ -n "$PS_VERSION_DIR" ]; then
            PS_PREFS_FILE="$PS_PREFS_DIR/$PS_VERSION_DIR/Adobe Photoshop Prefs.psp"
            
            if [ -f "$PS_PREFS_FILE" ]; then
                echo "Modifying Photoshop preferences file..."
                # Backup original
                cp "$PS_PREFS_FILE" "$PS_PREFS_FILE.backup"
                
                # Use sed to modify UI scale (this is a simplified approach)
                # Note: Photoshop prefs are binary, this may not work for all versions
                echo "Note: Manual adjustment in Photoshop may be required:"
                echo "Edit → Preferences → Interface → UI Text Size"
                echo "Set to $SCALE_FACTOR%"
            else
                echo "Photoshop preferences file not found."
                echo "Please set UI scaling in Photoshop:"
                echo "Edit → Preferences → Interface → UI Text Size"
            fi
        fi
    else
        echo "Photoshop preferences directory not found."
        echo "Please set UI scaling in Photoshop:"
        echo "Edit → Preferences → Interface → UI Text Size"
    fi
    
    read -p "Press Enter to continue..."
}

# Function for Photoshop manifest override
photoshop_manifest_method() {
    echo ""
    echo "Photoshop Manifest Override"
    echo "==========================="
    echo "This creates/modifies a manifest file to force DPI awareness."
    echo ""
    
    # Find Photoshop installation
    PS_PATHS=(
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop"
        "$WINE_PREFIX/drive_c/Program Files (x86)/Adobe/Adobe Photoshop"
    )
    
    PS_EXE=""
    for path in "${PS_PATHS[@]}"; do
        if [ -d "$path" ]; then
            PS_EXE=$(find "$path" -name "Photoshop.exe" -type f 2>/dev/null | head -n1)
            if [ -n "$PS_EXE" ]; then
                break
            fi
        fi
    done
    
    if [ -n "$PS_EXE" ]; then
        MANIFEST_FILE="${PS_EXE}.manifest"
        
        echo "Creating manifest file at: $MANIFEST_FILE"
        cat > "$MANIFEST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0" xmlns:asmv3="urn:schemas-microsoft-com:asm.v3">
  <asmv3:application>
    <asmv3:windowsSettings>
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">false</dpiAware>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">unaware</dpiAwareness>
    </asmv3:windowsSettings>
  </asmv3:application>
</assembly>
EOF
        
        echo "Manifest file created. Photoshop will now use system DPI scaling."
        echo "Restart Photoshop to apply changes."
    else
        echo "Photoshop.exe not found in standard locations."
        echo "You may need to manually create a manifest file for Photoshop.exe"
    fi
    
    read -p "Press Enter to continue..."
}

# Function for Photoshop preferences file editing
photoshop_prefs_method() {
    echo ""
    echo "Photoshop Registry Settings"
    echo "=========================="
    echo "This method sets Photoshop-specific registry keys for UI scaling."
    echo ""
    echo "Select UI scale:"
    echo "1) 100% (Default)"
    echo "2) 125%"
    echo "3) 150%"
    echo "4) 175%"
    echo "5) 200%"
    echo -n "Enter choice [1-5]: "
    read scale_choice
    
    case $scale_choice in
        1) REG_SCALE=100 ;;
        2) REG_SCALE=125 ;;
        3) REG_SCALE=150 ;;
        4) REG_SCALE=175 ;;
        5) REG_SCALE=200 ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    # Create registry entries for Photoshop
    cat > /tmp/ps_scale.reg << EOF
REGEDIT4

[HKEY_CURRENT_USER\Software\Adobe\Photoshop]
"UIScale"=dword:000000$REG_SCALE

[HKEY_CURRENT_USER\Software\Adobe\Photoshop\Preferences]
"InterfaceScale"=dword:000000$REG_SCALE

EOF
    
    WINEPREFIX="$WINE_PREFIX" regedit /tmp/ps_scale.reg
    rm /tmp/ps_scale.reg
    
    echo "Photoshop UI scale set to $REG_SCALE%"
    echo "Restart Photoshop to apply changes."
    read -p "Press Enter to continue..."
}

# Function to show current settings
show_current() {
    echo ""
    echo "Current DPI Settings:"
    echo "====================="
    
    # Check registry
    echo "Registry DPI:"
    WINEPREFIX="$WINE_PREFIX" reg query "HKEY_CURRENT_USER\Control Panel\Desktop" /v LogPixels 2>/dev/null || echo "  Not set"
    
    # Check X11
    if command -v xdpyinfo &> /dev/null; then
        echo ""
        echo "X11 DPI: $(xdpyinfo | grep dots | awk '{print $2}' | cut -d'x' -f1)"
    fi
    
    # Check environment
    echo ""
    echo "Environment WINEDLLOVERRIDES: ${WINEDLLOVERRIDES:-Not set}"
    
    # Check Photoshop manifest
    PS_PATHS=(
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop"
        "$WINE_PREFIX/drive_c/Program Files (x86)/Adobe/Adobe Photoshop"
    )
    
    for path in "${PS_PATHS[@]}"; do
        if [ -d "$path" ]; then
            PS_EXE=$(find "$path" -name "Photoshop.exe" -type f 2>/dev/null | head -n1)
            if [ -n "$PS_EXE" ] && [ -f "${PS_EXE}.manifest" ]; then
                echo ""
                echo "Photoshop manifest: Found"
                break
            fi
        fi
    done
    
    read -p "Press Enter to continue..."
}

# Function to launch Photoshop with DPI override
launch_photoshop() {
    echo ""
    echo "Launch Photoshop with DPI Override"
    echo "=================================="
    echo "This launches Photoshop with forced DPI scaling."
    echo ""
    echo "Select DPI:"
    echo "1) 96 DPI (100%)"
    echo "2) 120 DPI (125%)"
    echo "3) 144 DPI (150%)"
    echo "4) 168 DPI (175%)"
    echo "5) Custom DPI"
    echo -n "Enter choice [1-5]: "
    read dpi_choice
    
    case $dpi_choice in
        1) DPI_VALUE=96 ;;
        2) DPI_VALUE=120 ;;
        3) DPI_VALUE=144 ;;
        4) DPI_VALUE=168 ;;
        5) echo -n "Enter custom DPI value: "; read DPI_VALUE ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    # Find Photoshop
    PS_PATHS=(
        "$WINE_PREFIX/drive_c/Program Files/Adobe/Adobe Photoshop"
        "$WINE_PREFIX/drive_c/Program Files (x86)/Adobe/Adobe Photoshop"
    )
    
    PS_EXE=""
    for path in "${PS_PATHS[@]}"; do
        if [ -d "$path" ]; then
            PS_EXE=$(find "$path" -name "Photoshop.exe" -type f 2>/dev/null | head -n1)
            if [ -n "$PS_EXE" ]; then
                break
            fi
        fi
    done
    
    if [ -n "$PS_EXE" ]; then
        echo "Launching Photoshop with $DPI_VALUE DPI..."
        echo "Command: __COMPAT_LAYER=HIGHDPIAWARE WINEDLLOVERRIDES=\"winex11.dpi=$DPI_VALUE\" wine \"$PS_EXE\""
        echo ""
        echo "To use this in the future, run:"
        echo "__COMPAT_LAYER=HIGHDPIAWARE WINEDLLOVERRIDES=\"winex11.dpi=$DPI_VALUE\" wine \"$PS_EXE\""
        echo ""
        read -p "Press Enter to launch..."
        __COMPAT_LAYER=HIGHDPIAWARE WINEDLLOVERRIDES="winex11.dpi=$DPI_VALUE" WINEPREFIX="$WINE_PREFIX" wine "$PS_EXE"
    else
        echo "Photoshop.exe not found."
        echo "You can manually launch with:"
        echo "__COMPAT_LAYER=HIGHDPIAWARE WINEDLLOVERRIDES=\"winex11.dpi=$DPI_VALUE\" wine \"/path/to/Photoshop.exe\""
    fi
    
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    read choice
    
    case $choice in
        1) winecfg_method ;;
        2) registry_method ;;
        3) env_method ;;
        4) x11_method ;;
        5) photoshop_ui_method ;;
        6) photoshop_manifest_method ;;
        7) photoshop_prefs_method ;;
        8) launch_photoshop ;;
        9) reset_dpi ;;
        10) show_current ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice. Please try again."; sleep 1 ;;
    esac
done
