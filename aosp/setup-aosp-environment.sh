#!/usr/bin/bash

# Add trap for Ctrl+C (SIGINT)
trap 'echo -e "\nScript interrupted by user. Exiting..."; exit 1' INT

set -eE
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

error_handler() {
  echo "Error $1 occurred on line $2"
  exit 1
}

# Required packages list
PACKAGES=(
    python3 bc bison build-essential curl ccache coreutils flex git
    gnupg gperf liblz4-tool libncurses5-dev libsdl1.2-dev libwxgtk3.0-gtk3-dev
    imagemagick lunzip lzop schedtool squashfs-tools xsltproc zip
    zlib1g-dev perl xmlstarlet virtualenv xz-utils jq
    git-lfs libxml2 openjdk-11-jdk wget libncurses5 libncurses5-dev
    libxml2-utils android-sdk-libsparse-utils lld x11proto-core-dev
    libx11-dev libgl1-mesa-dev unzip fontconfig ca-certificates bc cpio bsdmainutils
    lz4 aria2 rclone openssh-client libssl-dev rsync python-is-python3 libarchive-tools
)

# Parse command line arguments
SETUP_CCACHE=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-ccache)
            SETUP_CCACHE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --no-ccache    Skip ccache setup"
            echo "  --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

function check_system() {
    if ! command -v apt-get &> /dev/null; then
        echo "Error: This script requires a Debian-based system"
        exit 1
    fi
}

function installpkgs() {
  local cmd_prefix=""
  if command -v sudo &> /dev/null; then
    cmd_prefix="sudo"
  fi

  echo "Updating package lists..."
  $cmd_prefix DEBIAN_FRONTEND=noninteractive apt-get update -qq

  echo "Checking installed packages..."
  local packages_to_install=()
  local already_installed=()
  local unavailable_packages=()

  for pkg in "${PACKAGES[@]}"; do
    # Check if package is already installed
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
      already_installed+=("$pkg")
    else
      # Check if package is available
      if $cmd_prefix apt-cache show "$pkg" &>/dev/null; then
        packages_to_install+=("$pkg")
      else
        unavailable_packages+=("$pkg")
      fi
    fi
  done

  # Report already installed packages
  if [ ${#already_installed[@]} -ne 0 ]; then
    echo "The following ${#already_installed[@]} packages are already installed:"
    printf "  - %s\n" "${already_installed[@]}"
  fi

  # Install packages that are available but not installed
  if [ ${#packages_to_install[@]} -ne 0 ]; then
    echo "Installing ${#packages_to_install[@]} packages..."
    $cmd_prefix DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages_to_install[@]}"
  else
    echo "No new packages to install."
  fi

  # Handle unavailable packages
  if [ ${#unavailable_packages[@]} -ne 0 ]; then
    echo "The following packages were not found in repositories:"
    for pkg in "${unavailable_packages[@]}"; do
      echo "  - $pkg"

      # Search for similar packages
      echo "Searching for alternatives to $pkg..."
      local similar_packages=($($cmd_prefix apt-cache search "$pkg" | head -n 3 | cut -d' ' -f1))

      if [ ${#similar_packages[@]} -ne 0 ]; then
        echo "Found similar packages:"
        select alt_pkg in "${similar_packages[@]}" "Skip this package"; do
          if [[ "$alt_pkg" != "Skip this package" ]]; then
            echo "Installing alternative package: $alt_pkg"
            $cmd_prefix DEBIAN_FRONTEND=noninteractive apt-get install -y "$alt_pkg"
          else
            echo "Skipped installation of $pkg"
          fi
          break
        done
      else
        echo "No alternatives found for $pkg. Skipping."
      fi
    done
  fi

  echo "Package installation completed!"
}

function installrepo() {
  # Check if repo is already installed and working
  if command -v repo &> /dev/null; then
    echo "repo is already installed at $(which repo)"
    return 0
  fi

  echo "Installing repo command to /usr/bin..."

  # Determine if sudo is required
  local cmd_prefix=""
  if command -v sudo &> /dev/null; then
    cmd_prefix="sudo"
  fi

  # Download the repo script
  local temp_repo=$(mktemp)
  curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$temp_repo"

  # Make it executable and move to /usr/bin
  chmod +x "$temp_repo"
  $cmd_prefix mv "$temp_repo" /usr/bin/repo

  # Verify installation
  if command -v repo &> /dev/null; then
    echo "repo successfully installed to /usr/bin/repo"
  else
    echo "Failed to install repo"
    return 1
  fi
}

function setupccache() {
    local CCACHE_SIZE="50G"
    local CCACHE_DIR="/mnt/ccache"

    echo "Setting up ccache..."
    mkdir -p ~/ccache
    $cmd_prefix mkdir -p $CCACHE_DIR
    $cmd_prefix mount --bind ~/ccache $CCACHE_DIR

    # Add to both .bashrc and .zshrc if exists
    for rc in ~/.bashrc ~/.zshrc; do
        if [ -f "$rc" ]; then
            echo "Updating $rc..."
            {
                echo 'export USE_CCACHE=1'
                echo "export CCACHE_DIR=$CCACHE_DIR"
                echo 'export CCACHE_EXEC=$(which ccache)'
            } >> "$rc"
        fi
    done

    ccache -o compression=true
    ccache -M $CCACHE_SIZE
    ccache -z
}

# Main execution
check_system
installpkgs
installrepo
if $SETUP_CCACHE; then
    setupccache
else
    echo "Skipping ccache setup as requested"
fi

echo "Environment setup completed successfully!"