# Photoshop CC 2021 for Linux

A complete installer for Adobe Photoshop CC 2021 on Linux using Wine 9.0. This installer includes Camera Raw support and provides an isolated Wine environment for maximum compatibility.

**DISCLAIMER:**
**Please use this software only if you have an active Photoshop subscription. I'm not responsible for any use without subscription.**

## Features

- **Photoshop CC 2021** with full compatibility
- **Camera Raw 12.2.1** included and pre-installed
- **Wine 9.0** isolated installation (doesn't affect system Wine)
- **DXVK and VKD3D** for better graphics performance
- **Desktop integration** with application launcher and icon
- **Colored progress output** with detailed installation steps

## Requirements

- **Linux distribution** (tested on openSUSE Tumbleweed, Ubuntu, Fedora)
- **Basic utilities:**
  - tar
  - wget
  - curl
  - zenity (for notifications)
- **Vulkan-capable GPU or APU** (older GPUs may encounter issues)
- **Write permissions** to the installation directory
- **Active internet connection** (downloads ~2GB of data)

## Installation

### Standard Installation (with Camera Raw)

```bash
# Clone the repository
git clone https://github.com/yourusername/LinuxPS.git
cd LinuxPS

# Run the installer
./scripts/photoshop2021installcr.sh /path/to/install/directory
```

### Verbose Installation

For detailed output during installation:

```bash
./scripts/photoshop2021installcr.sh -v /path/to/install/directory
```

### Without Camera Raw

If you prefer to install without Camera Raw:

```bash
./scripts/photoshop2021install.sh /path/to/install/directory
```

## Usage

After installation, you can launch Photoshop in two ways:

1. **From applications menu:** Graphics → Photoshop CC 2021
2. **From terminal:**
   ```bash
   /path/to/install/directory/Adobe-Photoshop/drive_c/launcher.sh
   ```

### Camera Raw Configuration

If you encounter issues with Camera Raw:

1. Open Photoshop
2. Go to **Edit → Preferences → Camera Raw... → Performance**
3. Set **"Use graphics processor"** to **Off**
4. If Camera Raw is grayed out, go to **Edit → Preferences → Tools** and uncheck **"Show Tooltips"**

## Uninstallation

To completely remove Photoshop:

```bash
./scripts/uninstaller.sh /path/to/install/directory
```

The uninstaller will remove:
- Photoshop installation
- Wine 9.0 installation
- Desktop entry and icon
- Empty installation directory (if applicable)

## Script Parameters

### Install Scripts

```bash
./scripts/photoshop2021install[cr].sh [OPTIONS] /path/to/install/directory
```

**Options:**
- `-v, --verbose` - Show detailed output during installation

**Arguments:**
- `/path/to/install/directory` - Where Photoshop will be installed (absolute or relative path)

### Uninstaller Script

```bash
./scripts/uninstaller.sh [OPTIONS] /path/to/install/directory
```

**Options:**
- `-v, --verbose` - Show detailed output during uninstallation

**Arguments:**
- `/path/to/install/directory` - The directory where Photoshop was installed

## File Structure After Installation

```
/path/to/install/directory/
├── Adobe-Photoshop/          # Wine prefix and Photoshop files
│   ├── drive_c/
│   │   ├── Program Files/Adobe/Adobe Photoshop 2021/
│   │   └── launcher.sh       # Launch script
│   └── ...                   # Wine configuration files
└── wine-9.0/                 # Isolated Wine 9.0 installation
    ├── bin/
    ├── lib/
    └── lib64/
```

## Troubleshooting

### Common Issues

1. **"Wine is not working correctly"**
   - Ensure you have proper permissions in the installation directory
   - Try running with verbose mode to see detailed error messages

2. **Photoshop won't launch**
   - First launch may take longer as Wine configures components
   - Check if all redistributables were installed successfully

3. **Performance issues**
   - Ensure your GPU drivers are up to date
   - Consider disabling GPU acceleration in Photoshop preferences

### Getting Help

When reporting issues, please include:
- Your Linux distribution
- The exact command used
- Verbose output if available
- Any error messages

## Special Thanks

- **The WineHQ team** - For making Wine possible
- **Kron4ek** - For providing Wine builds
- **Adobe** - For making Photoshop (please release an official Linux version!)

## Donate

This isn't necessary but helps with hosting and development costs:

- **BTC:** 1LDKrdTKGHtGRjDSL2ULxGGzX4onL5YUsp
- **ETH:** 0x57bf06a94ead7b18beb237e9aec9ae3ef06fe29a
- **BUSD:** 0x57bf06a94ead7b18beb237e9aec9ae3ef06fe29a
