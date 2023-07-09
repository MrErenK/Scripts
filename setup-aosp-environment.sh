#!/usr/bin/bash

function installpkgs() {
  if ! command -v sudo &> /dev/null
  then
    echo "[!] sudo command not found... Not using it to install packages..."
    DEBIAN_FRONTEND=noninteractive apt update -yqq
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3 bc bison build-essential curl ccache coreutils flex git gnupg gperf lib32z1-dev liblz4-tool \
    libncurses5-dev libsdl1.2-dev libwxgtk3.0-gtk3-dev imagemagick lunzip lzop schedtool squashfs-tools xsltproc zip zlib1g-dev perl xmlstarlet virtualenv xz-utils rr jq libncurses5 pngcrush \
    lib32ncurses5-dev git-lfs libxml2 openjdk-11-jdk wget lib32readline-dev libxml2-utils android-sdk-libsparse-utils lld gcc-multilib g++-multilib libc6-dev-i386 \
    x11proto-core-dev libx11-dev libgl1-mesa-dev unzip fontconfig ca-certificates bc cpio bsdmainutils lz4 aria2 rclone ssh-client libssl-dev rsync python-is-python3 libarchive-tools
  else
    echo "[!] sudo command found... Using it to install packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt update -yqq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 bc bison build-essential curl ccache coreutils flex git gnupg gperf lib32z1-dev liblz4-tool \
    libncurses5-dev libsdl1.2-dev libwxgtk3.0-gtk3-dev imagemagick lunzip lzop schedtool squashfs-tools xsltproc zip zlib1g-dev perl xmlstarlet virtualenv xz-utils rr jq libncurses5 pngcrush \
    lib32ncurses5-dev git-lfs libxml2 openjdk-11-jdk wget lib32readline-dev libxml2-utils android-sdk-libsparse-utils lld gcc-multilib g++-multilib libc6-dev-i386 \
    x11proto-core-dev libx11-dev libgl1-mesa-dev unzip fontconfig ca-certificates bc cpio bsdmainutils lz4 aria2 rclone ssh-client libssl-dev rsync python-is-python3 libarchive-tools
  fi
}

function setupccache() {
  BASH_ENV=~/.bashrc
  cd ~
  mkdir ccache
  if ! command -v sudo &> /dev/null
  then
    mkdir /mnt/ccache
  else
    sudo mkdir /mnt/ccache
  fi
  sudo mount --bind ./ccache /mnt/ccache # Using this kind of ccache because of on most servers, it does not let you to use direct ccache folder
  echo 'export USE_CCACHE=1' >> $BASH_ENV
  echo 'export CCACHE_DIR=/mnt/ccache' >> $BASH_ENV
  echo 'export CCACHE_EXEC=$(which ccache)' >> $BASH_ENV
  source $BASH_ENV
  ccache -o compression=true
  ccache -M 50G
  ccache -z
}

installpkgs
setupccache
