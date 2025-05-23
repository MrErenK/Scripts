# Scripts for AOSP/Kernel Development

This repository contains useful shell scripts to simplify AOSP/Kernel development workflow. While primarily designed for Redmi Note 8 Pro (begonia), these scripts can be adapted for other devices with minimal modifications.

## Kernel Build Script

### Setup

1. Clone your kernel source and cd into it
2. Clone this repo and copy required files:
   ```bash
   git clone https://github.com/MrErenK/Scripts.git
   cp Scripts/kernel/{config.env,kranul-build.sh,KSU.patch} .
   ```
3. Configure build settings in `config.env`
4. Run the build script:
   ```bash
   chmod +x kranul-build.sh
   ./kranul-build.sh
   ```

### Features

- Multiple compiler support (AOSP, Azure, Neutron, Proton, ZyC, Yuki)
- KernelSU integration (optional)
- Telegram notifications
- Build logging
- Automatic defconfig regeneration
- ccache support

## AOSP Environment Setup

### Usage

```bash
wget https://raw.githubusercontent.com/MrErenK/Scripts/main/aosp/setup-aosp-environment.sh
chmod +x ./setup-aosp-environment.sh
./setup-aosp-environment.sh [options]
```

### Options

- `--no-ccache`: Skip ccache setup
- `--help`: Show help message

### Features

- Automatic installation of required packages
- repo tool setup
- ccache configuration (optional)
- Smart package alternative suggestions

## Requirements

- Ubuntu 22.04 or newer recommended
- Sufficient storage space (50GB+ recommended)
- Good internet connection
- Basic knowledge of kernel/ROM building

## License

Licensed under Apache License 2.0. See [LICENSE](LICENSE) for more information.
