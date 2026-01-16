# Adobe Creative Suite Flatpak Packages

This directory contains Flatpak packaging configurations for Adobe Photoshop 2021 and Adobe Illustrator 2021, allowing for easy installation and management on Linux systems.

## 📦 Available Packages

- **com.adobe.photoshop2021** - Adobe Photoshop 2021 with Camera Raw 14.3
- **com.adobe.illustrator2021** - Adobe Illustrator 2021 with custom Wine optimization

## 🚀 Quick Start

### Prerequisites

```bash
# Install Flatpak
sudo apt install flatpak flatpak-builder  # Ubuntu/Debian
sudo dnf install flatpak flatpak-builder  # Fedora
sudo pacman -S flatpak flatpak-builder    # Arch

# Add Flathub remote
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install required runtimes
flatpak install --user flathub org.gnome.Platform//45 org.gnome.Sdk//45 org.winehq.Wine//stable -y
```

### Building from Source

1. **Ensure you have the application archives:**
   - `AdobePhotoshop2021.tar.xz` (for Photoshop)
   - `AdobeIllustrator2021.tar.xz` (for Illustrator)
   - `wine-illustrator-custom.tar.xz` (for Illustrator)

2. **Build individual applications:**
   ```bash
   # Build Photoshop 2021
   ./build-flatpaks.sh photoshop2021

   # Build Illustrator 2021
   ./build-flatpaks.sh illustrator2021

   # Build both applications
   ./build-flatpaks.sh all
   ```

3. **Build and export bundles for distribution:**
   ```bash
   ./build-flatpaks.sh all --export
   ```

### Installing Pre-built Bundles

If you have `.flatpak` bundle files:

```bash
# Install Photoshop
flatpak install --user com.adobe.photoshop2021.flatpak

# Install Illustrator
flatpak install --user com.adobe.illustrator2021.flatpak
```

## 🎯 Usage

After installation, you can:

### Launch from Applications Menu
- Look for "Adobe Photoshop 2021" and "Adobe Illustrator 2021" in your Graphics menu
- **Icons are now properly displayed** using PNG files from the icons folder

### Launch from Command Line
```bash
# Launch Photoshop
flatpak run com.adobe.photoshop2021

# Launch Illustrator
flatpak run com.adobe.illustrator2021
```

## 🖼️ Icon Integration

Both direct installations and Flatpak packages now properly use PNG icons from the `images/icons/` folder:

### Direct Installations
- Icons are copied to `~/.local/share/icons/hicolor/256x256/apps/`
- Desktop entries reference the copied PNG icons
- Fallback to generic icons if PNG files are not found

### Flatpak Packages
- Icons are bundled within the Flatpak package
- Installed to `/app/share/icons/hicolor/256x256/apps/`
- No external dependencies for icons

## 🏗️ Package Structure

Each Flatpak package includes:

- **Custom Wine build** - Optimized Wine 9.0 (Photoshop) or Wine-illustrator (Illustrator)
- **Pre-configured Wine prefix** - Windows 10 environment with dark theme
- **Adobe application** - Complete application installation
- **VC++ redistributables** - Required Windows components
- **Desktop integration** - Application launchers and file associations
- **Configuration scripts** - Appearance and DPI optimization tools

## 📁 File Locations

Flatpak applications store data in:
- **Application data:** `~/.var/app/com.adobe.photoshop2021/` or `~/.var/app/com.adobe.illustrator2021/`
- **Wine prefix:** `/app/Adobe-Photoshop` or `/app/Adobe-Illustrator` (within Flatpak)
- **User settings:** Preserved in Flatpak's user directories

## 🔧 Configuration

### Wine Configuration
```bash
# Access Wine configuration
flatpak run --command=winecfg com.adobe.photoshop2021
flatpak run --command=winecfg com.adobe.illustrator2021
```

### Winetricks
```bash
# Run winetricks for additional components
flatpak run --command=winetricks com.adobe.photoshop2021
flatpak run --command=winetricks com.adobe.illustrator2021
```

### Appearance Configuration
```bash
# Run appearance configuration (Photoshop)
flatpak run --command=configure-ps-appearance.sh com.adobe.photoshop2021

# Run DPI configuration
flatpak run --command=wine-dpi-config.sh com.adobe.photoshop2021
```

## 🗂️ File Associations

The packages automatically set up file associations:

### Photoshop 2021
- `.psd` - Photoshop documents
- `.jpg`, `.jpeg`, `.png`, `.tiff`, `.bmp`, `.gif` - Image formats

### Illustrator 2021
- `.ai` - Illustrator documents
- `.svg` - Scalable vector graphics
- `.eps` - Encapsulated PostScript

## 🔄 Updates

To update installed packages:
```bash
flatpak update --user
```

To rebuild and update:
```bash
./build-flatpaks.sh photoshop2021 --export
./build-flatpaks.sh illustrator2021 --export
```

## 🗑️ Uninstallation

```bash
# Remove Photoshop
flatpak uninstall --user com.adobe.photoshop2021

# Remove Illustrator
flatpak uninstall --user com.adobe.illustrator2021

# Remove application data
rm -rf ~/.var/app/com.adobe.photoshop2021
rm -rf ~/.var/app/com.adobe.illustrator2021
```

## 🐛 Troubleshooting

### Common Issues

1. **Application won't launch:**
   - Check if all dependencies are installed
   - Verify the application archives are complete
   - Try running with verbose output: `flatpak run -v com.adobe.photoshop2021`

2. **Performance issues:**
   - Ensure GPU acceleration is enabled in application preferences
   - Check if Vulkan drivers are installed and working

3. **Missing fonts:**
   - Install additional fonts via winetricks:
     ```bash
     flatpak run --command=winetricks com.adobe.photoshop2021 corefonts
     ```

4. **Display issues:**
   - Run DPI configuration script
   - Check Wine display settings

### Debug Mode

To run applications with debug output:
```bash
# Enable debug logging
flatpak run --env=WINEDEBUG=+all com.adobe.photoshop2021

# Access shell inside Flatpak
flatpak run --command=sh com.adobe.photoshop2021
```

## 📋 Build Options

The build script supports several options:

```bash
# Check dependencies only
./build-flatpaks.sh --check

# Build with bundle export
./build-flatpaks.sh photoshop2021 --export

# Export bundles only (requires built packages)
./build-flatpaks.sh --bundle photoshop2021

# Show help
./build-flatpaks.sh --help
```

## 🔄 Migration from Regular Installation

If you're migrating from the regular LinuxPS installation:

1. **Backup existing settings:**
   ```bash
   # From your existing installation
   ./scripts/backup-photoshop.sh /path/to/photoshop
   ./scripts/backup-illustrator2021.sh /path/to/illustrator
   ```

2. **Install Flatpak versions**
3. **Copy settings if needed** (manual process due to sandboxing)

## 📄 License

This Flatpak packaging is for educational and personal use only. Please respect Adobe's licensing terms and ensure you have valid subscriptions for any Adobe software you install.

## 🤝 Contributing

To contribute to the Flatpak packaging:

1. Test the packages on different distributions
2. Report issues with specific hardware configurations
3. Suggest improvements to the manifests
4. Help with documentation and troubleshooting

---

**Enjoy Adobe Creative Suite on Linux with Flatpak!** 🎨✨
