#!/bin/bash

# Photoshop 2021 Theme Changer
# Run this AFTER launching Photoshop at least once

if [ $# -lt 2 ]; then
  echo "Usage: $0 /path/to/install/directory [dark|medium|light]"
  echo ""
  echo "Examples:"
  echo "  $0 ~/Photoshop dark"
  echo "  $0 ~/Photoshop light"
  exit 1
fi

INSTALL_DIR="$1"
THEME="$2"
WINEPREFIX="$INSTALL_DIR/Adobe-Photoshop"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PS_SETTINGS="$WINEPREFIX/drive_c/users/$(whoami)/AppData/Roaming/Adobe/Adobe Photoshop 2021/Adobe Photoshop 2021 Settings"
PREFS_FILE="$PS_SETTINGS/UIPrefs.psp"

echo "Photoshop 2021 Theme Changer"
echo "============================="
echo ""

# Check if preferences file exists
if [ ! -f "$PREFS_FILE" ]; then
  echo -e "${RED}Error: UIPrefs.psp not found!${NC}"
  echo ""
  echo "This file is created when you launch Photoshop for the first time."
  echo "Please:"
  echo "  1. Launch Photoshop"
  echo "  2. Wait for it to fully load"
  echo "  3. Close Photoshop"
  echo "  4. Run this script again"
  exit 1
fi

# Validate theme
case "$THEME" in
  dark|light|medium)
    ;;
  *)
    echo -e "${RED}Error: Invalid theme '$THEME'${NC}"
    echo "Valid options: dark, medium, light"
    exit 1
    ;;
esac

# Check if Python is available
if ! command -v python3 &> /dev/null; then
  echo -e "${RED}Error: python3 is required but not installed${NC}"
  exit 1
fi

# Backup
BACKUP_FILE="${PREFS_FILE}.backup"
if [ ! -f "$BACKUP_FILE" ]; then
  cp "$PREFS_FILE" "$BACKUP_FILE"
  echo -e "${GREEN}✓${NC} Backup created"
fi

# Determine theme strings
OLD_STR="PanelBrightnessMediumGray"
case "$THEME" in
  dark)
    NEW_STR="PanelBrightnessDarkGray"
    ;;
  light)
    NEW_STR="PanelBrightnessLightGray"
    ;;
  medium)
    echo "Medium is already the default theme."
    exit 0
    ;;
esac

echo "Changing theme to: $THEME"

# Perform replacement using Python
python3 << PYEOF
import sys

prefs_file = "$PREFS_FILE"
old_str = b"$OLD_STR"
new_str = b"$NEW_STR"

# Pad to match length
if len(new_str) < len(old_str):
    new_str = new_str + b'\x00' * (len(old_str) - len(new_str))

try:
    with open(prefs_file, "rb") as f:
        data = f.read()
    
    # Search for any theme string
    found = False
    for theme in [b"PanelBrightnessDarkGray", b"PanelBrightnessMediumGray", b"PanelBrightnessLightGray"]:
        if theme in data:
            # Pad theme to same length as old_str
            theme_padded = theme + b'\x00' * (len(old_str) - len(theme))
            data = data.replace(theme_padded[:len(old_str)], new_str)
            found = True
            break
    
    if not found:
        print("Error: Could not find theme string in preferences file")
        sys.exit(1)
    
    with open(prefs_file, "wb") as f:
        f.write(data)
    
    print(f"Success! Theme changed to $THEME")
    print("")
    print("Please restart Photoshop for changes to take effect.")
    sys.exit(0)
    
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to change theme${NC}"
  echo "Restoring backup..."
  cp "$BACKUP_FILE" "$PREFS_FILE"
  exit 1
fi
