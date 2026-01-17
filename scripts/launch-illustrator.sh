#!/bin/bash
# Simple launcher for Illustrator 2021 Flatpak

# Use wine-illustrator-custom for everything (matches regular install exactly)
export PATH="/app/wine-illustrator/bin:$PATH"
export LD_LIBRARY_PATH="/app/wine-illustrator/lib:/app/wine-illustrator/lib64:${LD_LIBRARY_PATH}"
export WINEPREFIX="/var/data/Adobe-Illustrator"
export WINELOADER="/app/wine-illustrator/bin/wine"
export WINEDLLPATH="/app/wine-illustrator/lib/wine:/app/wine-illustrator/lib64/wine"
export WINEDEBUG=-all
export WINEDLLOVERRIDES="winemenubuilder.exe=d"

# DXVK environment variables from regular install
export DXVK_LOG_PATH="$WINEPREFIX"
export DXVK_STATE_CACHE_PATH="$WINEPREFIX"

# Suppress winetricks reporting
export WINETRICKS_OPT_SHAREDPREFIX=0
export W_OPT_UNATTENDED=1

# Initialize wine prefix if needed (silent install)
if [ ! -d "/var/data/Adobe-Illustrator/dosdevices" ]; then
    echo "Initializing Wine prefix..."
    # Kill any existing wineserver
    "/app/wine-illustrator/bin/wineserver" -k 2>/dev/null || true
    sleep 2
    
    # Create wine prefix silently
    "/app/wine-illustrator/bin/wineboot" -u 2>/dev/null || true
    
    # Set Windows 10 mode
    echo "Setting Windows 10 mode..."
    WINEPREFIX="/var/data/Adobe-Illustrator" "/app/wine-illustrator/bin/wine" reg add "HKCU\\Software\\Wine" /v Version /d "win10" /f 2>/dev/null || true
    
    # Install Wine components (fonts, libraries)
    echo "Installing Wine components..."
    WINEPREFIX="/var/data/Adobe-Illustrator" "/app/wine-illustrator/bin/wine" "/app/bin/winetricks" -q fontsmooth=rgb gdiplus msxml3 msxml6 atmlib corefonts 2>/dev/null || true
    
    # Install VC++ redistributables
    echo "Installing VC++ redistributables..."
    for version in 2010 2012 2013; do
        echo "Installing VC++ $version..."
        WINEPREFIX="/var/data/Adobe-Illustrator" timeout 30 "/app/wine-illustrator/bin/wine" "/app/bin/winetricks" -q vcrun$version 2>/dev/null || true
    done
    
    # Try 2015 and 2019 with shorter timeout and verbose output
    for version in 2015 2019; do
        echo "Installing VC++ $version..."
        WINEPREFIX="/var/data/Adobe-Illustrator" timeout 20 "/app/wine-illustrator/bin/wine" "/app/bin/winetricks" -q vcrun$version || echo "VC++ $version installation failed or incomplete"
    done
    
    # Auto-install Mono silently
    echo "Installing Mono (silent)..."
    "/app/wine-illustrator/bin/wine" msiexec /i "/app/wine-illustrator/share/wine/mono/wine-mono-6.4.0.msi" /quiet 2>/dev/null || true
    
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
    
    WINEPREFIX="/var/data/Adobe-Illustrator" "/app/wine-illustrator/bin/wine" regedit /S /tmp/adobe_csxs_fix.reg 2>/dev/null || true
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
    
    WINEPREFIX="/var/data/Adobe-Illustrator" "/app/wine-illustrator/bin/wine" regedit /S /tmp/dark-theme.reg 2>/dev/null || true
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
    
    WINEPREFIX="/var/data/Adobe-Illustrator" "/app/wine-illustrator/bin/wine" regedit /S /tmp/font-settings.reg 2>/dev/null || true
    rm -f /tmp/font-settings.reg
    
    echo "Adobe compatibility fixes and appearance settings applied"
fi

# Find Illustrator executable
ILLUSTRATOR_EXE=$(find /app/Adobe-Illustrator -name "Illustrator.exe" -type f 2>/dev/null | head -1)

if [ -z "$ILLUSTRATOR_EXE" ]; then
    echo "Error: Illustrator.exe not found in /app/Adobe-Illustrator"
    echo "Available directories:"
    find /app/Adobe-Illustrator -type d 2>/dev/null | head -10
    exit 1
fi

ILLUSTRATOR_DIR=$(dirname "$ILLUSTRATOR_EXE")
echo "Starting Illustrator from: $ILLUSTRATOR_EXE"

# Use wine-illustrator-custom for running Illustrator (matches regular install exactly)
export PATH="/app/wine-illustrator/bin:$PATH"
export LD_LIBRARY_PATH="/app/wine-illustrator/lib:/app/wine-illustrator/lib64:${LD_LIBRARY_PATH}"
export WINELOADER="/app/wine-illustrator/bin/wine"
export WINEDLLPATH="/app/wine-illustrator/lib/wine:/app/wine-illustrator/lib64/wine"

cd "$ILLUSTRATOR_DIR"
"/app/wine-illustrator/bin/wine64" Illustrator.exe "$@"
