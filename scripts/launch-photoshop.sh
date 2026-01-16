#!/bin/bash
# Simple launcher for Photoshop 2021 Flatpak

# Use Wine 9.0 for prefix setup (matches regular install)
export PATH="/app/wine-9.0/bin:$PATH"
export LD_LIBRARY_PATH="/app/wine-9.0/lib:/app/wine-9.0/lib64:${LD_LIBRARY_PATH}"
export WINEPREFIX="/var/data/Adobe-Photoshop"
export WINELOADER="/app/wine-9.0/bin/wine"
export WINEDLLPATH="/app/wine-9.0/lib/wine:/app/wine-9.0/lib64/wine"
export WINEDEBUG=-all
export WINEDLLOVERRIDES="winemenubuilder.exe=d"

# DXVK environment variables from regular install
export DXVK_LOG_PATH="$WINEPREFIX"
export DXVK_STATE_CACHE_PATH="$WINEPREFIX"

# Suppress winetricks reporting
export WINETRICKS_OPT_SHAREDPREFIX=0
export W_OPT_UNATTENDED=1

# Initialize wine prefix if needed (silent install)
if [ ! -d "/var/data/Adobe-Photoshop/dosdevices" ]; then
    echo "Initializing Wine prefix..."
    # Kill any existing wineserver
    "/app/wine-9.0/bin/wineserver" -k 2>/dev/null || true
    sleep 2
    
    # Create wine prefix silently
    "/app/wine-9.0/bin/wineboot" -u 2>/dev/null || true
    
    # Set Windows 10 mode
    echo "Setting Windows 10 mode..."
    WINEPREFIX="/var/data/Adobe-Photoshop" "/app/wine-9.0/bin/wine" reg add "HKCU\\Software\\Wine" /v Version /d "win10" /f 2>/dev/null || true
    
    # Install Wine components (fonts, libraries)
    echo "Installing Wine components..."
    WINEPREFIX="/var/data/Adobe-Photoshop" "/app/wine-9.0/bin/wine" "/app/bin/winetricks" -q fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts 2>/dev/null || true
    
    # Install VC++ redistributables
    echo "Installing VC++ redistributables..."
    for version in 2010 2012 2013; do
        echo "Installing VC++ $version..."
        WINEPREFIX="/var/data/Adobe-Photoshop" timeout 30 "/app/wine-9.0/bin/wine" "/app/bin/winetricks" -q vcrun$version 2>/dev/null || true
    done
    
    # Try 2015 and 2019 with shorter timeout
    for version in 2015 2019; do
        echo "Installing VC++ $version..."
        WINEPREFIX="/var/data/Adobe-Photoshop" timeout 20 "/app/wine-9.0/bin/wine" "/app/bin/winetricks" -q vcrun$version 2>/dev/null || true
    done
    
    # Auto-install Mono silently
    echo "Installing Mono (silent)..."
    "/app/wine-9.0/bin/wine" msiexec /i "/app/wine-9.0/share/wine/mono/wine-mono-6.4.0.msi" /quiet 2>/dev/null || true
    
    # Apply Adobe CSXS registry fixes
    echo "Applying Adobe compatibility fixes..."
    cat > /tmp/adobe_csxs_fix.reg << 'EOF'
REGEDIT4

[HKEY_CURRENT_USER\Software\Adobe\CSXS.11]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.12]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.13]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.14]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.15]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.16]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.17]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.18]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.19]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.20]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.21]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.22]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.23]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.24]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.25]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.26]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.27]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.28]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.29]
"PlayerDebugMode"=dword:00000001

[HKEY_CURRENT_USER\Software\Adobe\CSXS.30]
"PlayerDebugMode"=dword:00000001
EOF
    
    WINEPREFIX="/var/data/Adobe-Photoshop" "/app/wine-9.0/bin/wine" regedit /S /tmp/adobe_csxs_fix.reg 2>/dev/null || true
    rm -f /tmp/adobe_csxs_fix.reg
    
    # Apply Windows 10 dark theme
    echo "Applying dark theme..."
    cat > /tmp/dark-theme.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize]
"AppsUseLightTheme"=dword:00000000
"SystemUsesLightTheme"=dword:00000000

[HKEY_CURRENT_USER\Control Panel\Colors]
"Window"="255 255 255"
"WindowText"="0 0 0"
EOF
    
    WINEPREFIX="/var/data/Adobe-Photoshop" "/app/wine-9.0/bin/wine" regedit /S /tmp/dark-theme.reg 2>/dev/null || true
    rm -f /tmp/dark-theme.reg
    
    # Configure font smoothing settings
    echo "Configuring font settings..."
    cat > /tmp/font-settings.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="2"
"FontSmoothingType"=dword:00000002
"FontSmoothingGamma"=dword:00000578
"FontSmoothingOrientation"=dword:00000001
EOF
    
    WINEPREFIX="/var/data/Adobe-Photoshop" "/app/wine-9.0/bin/wine" regedit /S /tmp/font-settings.reg 2>/dev/null || true
    rm -f /tmp/font-settings.reg
    
    echo "Adobe compatibility fixes and appearance settings applied"
fi

# Find Photoshop executable
PHOTOSHOP_EXE=$(find /app/Adobe-Photoshop -name "photoshop.exe" -type f 2>/dev/null | head -1)

if [ -z "$PHOTOSHOP_EXE" ]; then
    echo "Error: photoshop.exe not found in /app/Adobe-Photoshop"
    echo "Available directories:"
    find /app/Adobe-Photoshop -type d 2>/dev/null | head -10
    exit 1
fi

PHOTOSHOP_DIR=$(dirname "$PHOTOSHOP_EXE")
echo "Starting Photoshop from: $PHOTOSHOP_EXE"

cd "$PHOTOSHOP_DIR"
"/app/wine-9.0/bin/wine64" photoshop.exe "$@"
