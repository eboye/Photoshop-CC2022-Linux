#!/bin/bash

# Photoshop 2021 Appearance Configurator
# Makes Photoshop look better on Linux with dark theme and proper fonts

if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/install/directory"
  echo ""
  echo "This will:"
  echo "  - Set dark Windows theme for native dialogs"
  echo "  - Configure proper font antialiasing (RGB subpixel)"
  echo "  - Improve font rendering to match GNOME"
  exit 1
fi

INSTALL_DIR="$1"
WINE_DIR="$INSTALL_DIR/wine-9.0"
WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Set Wine environment
export PATH="$WINE_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$WINE_DIR/lib:$WINE_DIR/lib64:${LD_LIBRARY_PATH}"
export WINEPREFIX
export WINELOADER="$WINE_DIR/bin/wine"
export WINEDLLPATH="$WINE_DIR/lib/wine:$WINE_DIR/lib64/wine"
export WINEDEBUG=-all

echo ""
echo -e "${BOLD}${CYAN}Photoshop Appearance Configurator${NC}"
echo "=================================="
echo ""

# Check if Wine prefix exists
if [ ! -d "$WINEPREFIX" ]; then
  echo "Error: Wine prefix not found at $WINEPREFIX"
  exit 1
fi

echo -e "${BLUE}→${NC} Configuring dark theme for Windows dialogs..."

# Set Windows 10 dark mode via registry
cat > /tmp/dark-theme.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize]
"AppsUseLightTheme"=dword:00000000
"SystemUsesLightTheme"=dword:00000000

[HKEY_CURRENT_USER\Control Panel\Colors]
"ActiveBorder"="49 54 59"
"ActiveTitle"="49 54 59"
"AppWorkSpace"="37 37 37"
"Background"="37 37 37"
"ButtonFace"="49 54 59"
"ButtonHilight"="69 73 77"
"ButtonLight"="59 64 69"
"ButtonShadow"="0 0 0"
"ButtonText"="255 255 255"
"GradientActiveTitle"="49 54 59"
"GradientInactiveTitle"="49 54 59"
"GrayText"="155 155 155"
"Hilight"="0 120 215"
"HilightText"="255 255 255"
"InactiveBorder"="49 54 59"
"InactiveTitle"="49 54 59"
"InactiveTitleText"="255 255 255"
"InfoText"="255 255 255"
"InfoWindow"="49 54 59"
"Menu"="45 45 45"
"MenuBar"="49 54 59"
"MenuHilight"="0 120 215"
"MenuText"="255 255 255"
"Scrollbar"="49 54 59"
"TitleText"="255 255 255"
"Window"="37 37 37"
"WindowFrame"="49 54 59"
"WindowText"="255 255 255"

[HKEY_CURRENT_USER\Control Panel\Desktop]
"UserPreferencesMask"=hex:9e,3e,07,80,12,00,00,00

[HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics]
"BorderWidth"="-15"
"ScrollHeight"="-255"
"ScrollWidth"="-255"
"CaptionHeight"="-330"
"CaptionWidth"="-330"
"IconSpacing"="-1125"
"IconVerticalSpacing"="-1125"
"MenuHeight"="-285"
"MenuWidth"="-285"
"MinAnimate"="0"
"SmCaptionHeight"="-285"
"SmCaptionWidth"="-285"
EOF

wine regedit /tmp/dark-theme.reg 2>/dev/null
rm /tmp/dark-theme.reg
echo -e "${GREEN}✓${NC} Dark theme applied"

echo -e "${BLUE}→${NC} Configuring font rendering..."

# Configure font smoothing and antialiasing
cat > /tmp/font-config.reg << 'EOF'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="2"
"FontSmoothingType"=dword:00000002
"FontSmoothingGamma"=dword:00000578
"FontSmoothingOrientation"=dword:00000001

[HKEY_CURRENT_USER\Software\Wine\Fonts]
"Smoothing"=dword:00000002
"AntialiasingType"=dword:00000001

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"ClientSideWithRender"="Y"
"ClientSideAntiAliasWithRender"="Y"

[HKEY_CURRENT_USER\Software\Wine\DirectWrite]
"MaxCachedFaces"=dword:00000010
"GammaBias"=dword:00000578
EOF

wine regedit /tmp/font-config.reg 2>/dev/null
rm /tmp/font-config.reg
echo -e "${GREEN}✓${NC} Font rendering configured (RGB subpixel antialiasing)"

echo -e "${BLUE}→${NC} Creating fontconfig for better rendering..."

# Create fontconfig for Wine
FONTCONFIG_DIR="$WINEPREFIX/fontconfig"
mkdir -p "$FONTCONFIG_DIR"

cat > "$FONTCONFIG_DIR/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Enable antialiasing -->
  <match target="font">
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
  </match>
  
  <!-- Enable hinting (slight) -->
  <match target="font">
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
  </match>
  
  <match target="font">
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
  </match>
  
  <!-- RGB subpixel rendering -->
  <match target="font">
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
  </match>
  
  <!-- LCD filter -->
  <match target="font">
    <edit name="lcdfilter" mode="assign">
      <const>lcddefault</const>
    </edit>
  </match>
  
  <!-- Disable autohint for better results -->
  <match target="font">
    <edit name="autohint" mode="assign">
      <bool>false</bool>
    </edit>
  </match>
  
  <!-- Font substitutions for better rendering -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Liberation Serif</family>
    </prefer>
  </alias>
  
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Liberation Sans</family>
    </prefer>
  </alias>
  
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Liberation Mono</family>
    </prefer>
  </alias>
</fontconfig>
EOF

echo -e "${GREEN}✓${NC} Fontconfig created"

echo -e "${BLUE}→${NC} Updating launcher script..."

# Update the launcher to use fontconfig
LAUNCHER="$INSTALL_DIR/launch-photoshop.sh"
if [ -f "$LAUNCHER" ]; then
  # Backup original
  cp "$LAUNCHER" "${LAUNCHER}.bak"
  
  # Add fontconfig environment variable
  sed -i '/^export WINEDEBUG/a export FONTCONFIG_FILE="'"$FONTCONFIG_DIR"'/fonts.conf"' "$LAUNCHER"
  
  echo -e "${GREEN}✓${NC} Launcher updated"
else
  echo "Warning: Launcher not found, skipping update"
fi

echo ""
echo -e "${BOLD}${GREEN}Configuration Complete!${NC}"
echo ""
echo "Changes applied:"
echo "  ✓ Dark Windows theme for native dialogs"
echo "  ✓ RGB subpixel font antialiasing"
echo "  ✓ Font smoothing matching GNOME defaults"
echo "  ✓ Improved font rendering"
echo ""
echo "Please restart Photoshop to see the changes."
echo ""
