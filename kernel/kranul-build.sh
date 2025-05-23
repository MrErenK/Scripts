#!/usr/bin/env bash
#
# Copyright (C) 2022-2023 Neebe3289 <neebexd@gmail.com>
# Copyright (C) 2023-2025 MrErenK <akbaseren4751@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# A bash script to build Android Kernel
# Inspired from Panchajanya1999's script
#

# Exit on error
set -e

# Function to show informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

# Function to show error message
err() {
    echo -e "\e[1;31m$*\e[0m"
}

# Function to show warning message
warn() {
    echo -e "\e[1;33m$*\e[0m"
}

# Function to cleanup leftovers from build
cleanup() {
    local skip_msg=${1:-0}
    
    if [[ $skip_msg -eq 0 ]]; then
        msg "Cleaning up build artifacts..."
    fi
    
    if [[ -d "${AnyKernelPath}" ]]; then
        rm -rf "${AnyKernelPath}"
    fi
    
    if [[ -d "out/" ]]; then
        rm -rf "out/"
    fi
}

# Check if config.env exists
if [ ! -f "config.env" ]; then
    err "Error: config.env not found. Please create the configuration file."
    exit 1
fi

# Load variables from config.env
source config.env

# Function to read user input securely
get_input() {
    local prompt="$1"
    local var_name="$2"
    local is_optional="${3:-0}"
    
    while true; do
        echo -n "$prompt"
        # Turn off echoing and store input in the given variable name
        IFS= read -rs "$var_name"
        # Print a newline after the user input
        echo
        # Check if the user input is empty except for optional fields
        if [ -z "${!var_name}" ] && [ "$is_optional" -eq 0 ]; then
            err "Error: Input cannot be empty!"
        else
            break
        fi
    done
}

# Read Telegram credentials only if Telegram is enabled
if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
    # Read Telegram token
    get_input "Enter your bot's Telegram token: " TELEGRAM_TOKEN
    # Read Telegram chat ID
    get_input "Enter the Telegram chat ID to send information: " TELEGRAM_CHAT
    # Read Telegram channel ID for announcements (optional)
    get_input "Enter the Telegram channel ID to send announcement (optional): " TELEGRAM_CHANNEL 1
    
    # Export the Telegram token and chat IDs
    export TELEGRAM_TOKEN TELEGRAM_CHAT TELEGRAM_CHANNEL
    
    # Set announcement flag based on channel availability
    SEND_ANNOUNCEMENT=$([ -n "${TELEGRAM_CHANNEL}" ] && echo "yes" || echo "no")
else
    msg "Telegram notifications are disabled."
    SEND_ANNOUNCEMENT="no"
fi

###############
# Basic Setup #
###############

# Current branch of the kernel
Branch="$(git rev-parse --abbrev-ref HEAD)"

# Current date
Date="$(date +%H.%M-%d.%m)"

# Full path of current path
MainPath="$(readlink -f -- $(pwd))"

# AnyKernel3 path
AnyKernelPath="${MainPath}/anykernel"

# Image to put to the zip
Image="${MainPath}/out/arch/arm64/boot/Image.gz"

# Kernel name
KernelName="$(cat "arch/arm64/configs/${DefConfig}" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )"

# Kernel sublevell
Sublevel="v4.14.$(cat "${MainPath}/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"

# Main clang path
MainClangPath="${MainPath}/clang"

# Setup variables
export_variables()
{
  # Available cores to compile the kernel
  AvailableCores="$(nproc --all)"

  # Kernel build user and host
  KBUILD_BUILD_USER="${USER:-builder}"
  KBUILD_BUILD_HOST="${HOSTNAME:-localhost}"

  # Timezone
  TZ="Europe/Istanbul"

  # Validate ClangName
  if [[ ! "${ClangName}" =~ ^(azure|neutron|proton|zyc|aosp|yuki)$ ]]; then
    err "Invalid ClangName: ${ClangName}. Supported values: azure, neutron, proton, zyc, aosp, yuki"
    cleanup
    exit 1
  fi

  # Set up Clang environment based on compiler choice
  ClangPath="${MainPath}/clang-${ClangName}"
  
  if [[ "${ClangName}" =~ ^(aosp|yuki)$ ]]; then
    PATH="${ClangPath}/bin:${MainPath}/gcc32/bin:${MainPath}/gcc64/bin:$PATH"
    LD_LIBRARY_PATH="${ClangPath}/lib:$LD_LIBRARY_PATH"
  else
    PATH="${ClangPath}/bin:$PATH"
  fi
  
  KBUILD_COMPILER_STRING="$(${ClangPath}/bin/clang --version 2>/dev/null | head -n 1 || echo "Clang ${ClangName}")"
  COMPILER="${KBUILD_COMPILER_STRING}"

  # Export all necessary variables
  export AnyKernelPath AvailableCores ClangPath COMPILER KBUILD_BUILD_USER KBUILD_BUILD_HOST KBUILD_COMPILER_STRING PATH TZ LD_LIBRARY_PATH
}

# Function to clone anykernel
clone_anykernel() {
    msg "Cloning AnyKernel repository..."
    if ! git clone --depth=1 "${AnyKernelRepo}" -b "${AnyKernelBranch}" "${AnyKernelPath}"; then
        err "Failed to clone AnyKernel repository."
        cleanup
        exit 1
    fi
    msg "AnyKernel repository cloned successfully."
}

# Function to check if KernelSU patch is already applied
is_ksu_patch_applied() {
    # Check for KernelSU patch signature in one of the modified files
    if grep -q "ksu_handle_input_handle_event" "${MainPath}/drivers/input/input.c" 2>/dev/null; then
        msg "KernelSU patch is already applied."
        return 0  # Already applied
    else
        return 1  # Not applied
    fi
}

# Function to add KernelSU
add_kernelsu() {
    if [ "${KERNELSU}" != "yes" ] && [ "${KERNELSU_NEXT}" != "yes" ]; then
        return 0
    fi
    
    msg "Setting up KernelSU..."
    
    # Return to main path if not already there
    [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
    
    # Update kernel variant name
    if [ "${KERNELSU}" = "yes" ]; then
        KERNEL_VARIANT="${KERNEL_VARIANT}-KSU"
        KSU_PATH="${MainPath}/KernelSU"
    elif [ "${KERNELSU_NEXT}" = "yes" ]; then
        KERNEL_VARIANT="${KERNEL_VARIANT}-KSUNEXT"
        KSU_PATH="${MainPath}/KernelSU-Next"
    fi
    
    # Download and setup KernelSU if not already present
    if [ ! -f "${KSU_PATH}/LICENSE" ]; then
        msg "Downloading KernelSU..."
        
        if [ "${KERNELSU_NEXT}" = "yes" ]; then
            # Use KernelSU-next branch
            if ! curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -; then
                err "Failed to download and setup KernelSU-next."
                cleanup
                exit 1
            fi
        else
            # Use KernelSU stable branch (v0.x.x)
            if ! curl -LSsk "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5; then
                err "Failed to download and setup KernelSU."
                cleanup
                exit 1
            fi
        fi
        
        # Check if patch is already applied
        if ! is_ksu_patch_applied; then
            if ! git apply ./KSU.patch; then
                err "Failed to apply KernelSU patch."
                cleanup
                exit 1
            fi
            msg "KernelSU patch applied successfully."
        fi
    fi
    
    # Update KernelSU version
    KERNELSU_VERSION="$((10000 + $(cd ${KSU_PATH} && git rev-list --count HEAD) + 200))"
    
    # Update submodules and KernelSU
    git submodule update --init
    (cd ${KSU_PATH} && git pull origin $([ "${KERNELSU_NEXT}" = "yes" ] && echo "next" || echo "v0.9.5"))
    
    msg "KernelSU setup completed. Version: ${KERNELSU_VERSION}"
}

###################
# Toolchain setup #
###################

# Function to clone toolchain
clone_clang() {
  # Return to main path if not already there
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"

  # Validate ClangName
  if [[ ! "${ClangName}" =~ ^(azure|neutron|proton|zyc|aosp|yuki)$ ]]; then
    err "Incorrect clang name. Supported values: azure, neutron, proton, zyc, aosp, yuki"
    cleanup
    exit 1
  fi
  
  # Create target directory if it doesn't exist
  local target_dir="clang-${ClangName}"
  
  # Check if clang is already cloned
  if [ -d "${target_dir}" ] && [ -x "${target_dir}/bin/clang" ]; then
    msg "Clang already exists at ${target_dir}. Skipping clone."
    return 0
  fi
  
  msg "Clang is set to ${ClangName}, cloning it..."
  
  case "${ClangName}" in
    aosp)
      git clone https://gitlab.com/Neebe3289/android_prebuilts_clang_host_linux-x86.git -b clang-r498229 ${target_dir} --depth=1
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 -b lineage-19.1 gcc64
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 -b lineage-19.1 gcc32
      patch_glibc
      ;;
    azure)
      git clone https://gitlab.com/Panchajanya1999/azure-clang ${target_dir} --depth=1
      patch_glibc
      ;;
    neutron)
      mkdir -p ${target_dir}
      cd ${target_dir}
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman && ./antman -S
      cd "${MainPath}"
      patch_glibc
      ;;
    proton)
      git clone https://github.com/kdrag0n/proton-clang ${target_dir} --depth=1
      patch_glibc
      ;;
    yuki)
      git clone https://gitlab.com/TheXPerienceProject/yuki_clang ${target_dir} -b "17.0.0" --depth=1
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 -b lineage-19.1 gcc64
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 -b lineage-19.1 gcc32
      patch_glibc
      ;;
    zyc)
      mkdir -p ${target_dir}
      cd ${target_dir}
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
      tar -xf zyc-clang.tar.gz && rm -f zyc-clang.tar.gz
      cd "${MainPath}"
      patch_glibc
      ;;
  esac
  
  msg "Clang ${ClangName} cloned successfully."
}

# Update clang
update_clang() {
  # Return to main path if not already there
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"

  local target_dir="clang-${ClangName}"
  
  # Check if clang directory exists
  if [ ! -d "${target_dir}" ]; then
    err "Clang directory ${target_dir} not found. Cannot update."
    return 1
  fi

  msg "Checking for updates to ${ClangName} clang..."
  
  case "${ClangName}" in
    neutron)
      cd "${target_dir}"
      if [ "$(./antman -U | grep "Nothing to do")" = "" ]; then
        msg "Updates found for neutron clang, updating..."
        patch_glibc
      else
        msg "No updates found for neutron clang."
      fi
      cd "${MainPath}"
      ;;
    zyc)
      cd "${target_dir}"
      local ZycLatest="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-lastbuild.txt)"
      if [ "$(cat README.md | grep "Build Date : " | cut -d: -f2 | sed "s/ //g")" != "${ZycLatest}" ]; then
        msg "Updates found for zyc clang, updating..."
        rm -rf ./*
        wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
        tar -xf zyc-clang.tar.gz
        rm -f zyc-clang.tar.gz
      else
        msg "No updates found for zyc clang."
      fi
      cd "${MainPath}"
      ;;
    azure|proton)
      cd "${target_dir}"
      msg "Updating ${ClangName} clang..."
      git fetch -q origin $([ "${ClangName}" = "azure" ] && echo "main" || echo "master")
      git pull origin $([ "${ClangName}" = "azure" ] && echo "main" || echo "master")
      cd "${MainPath}"
      ;;
    yuki)
      cd "${target_dir}"
      msg "Updating yuki clang..."
      git fetch -q origin "17.0.0"
      git pull origin "17.0.0"
      cd "${MainPath}"
      ;;
    *)
      msg "No update mechanism defined for ${ClangName} clang."
      ;;
  esac
}

# Function to patch glibc to prevent glibc version related errors
patch_glibc() {
  local target_dir="${ClangPath}"
  
  # Check if directory exists
  if [ ! -d "${target_dir}" ]; then
    err "Clang directory ${target_dir} not found. Cannot patch glibc."
    return 1
  fi
  
  msg "Patching glibc for ${ClangName} clang..."
  
  cd "${target_dir}"
  
  if [ "${ClangName}" = "neutron" ]; then
    ./antman --patch=glibc
  else
    if [ ! -f "./antman" ]; then
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman
    fi
    ./antman --patch=glibc
  fi
  
  cd "${MainPath}"
  
  msg "Glibc patched successfully."
}

##################
# Telegram Setup #
##################

# Clone and set Telegram script only if Telegram is enabled
if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
    if [ ! -f "${MainPath}/Telegram/telegram" ]; then
      git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
    fi
    TELEGRAM="${MainPath}/Telegram/telegram"
fi

# Function to send telegram messages
send_msg() {
  if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
    "${TELEGRAM}" -H -D \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
  fi
}

# Function to upload files to telegram
send_file() {
  if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
    "${TELEGRAM}" -H \
    -f "$1" \
    "$2"
  fi
}

# Function to push announcements to telegram
send_announcement() {
  if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
    "${TELEGRAM}" -c "${TELEGRAM_CHANNEL}" -H \
    -f "$1" \
    "$2"
  fi
}

# Function to upload kernel to telegram and handle announcements
push() {
  cd "${AnyKernelPath}" || { 
    err "AnyKernel path not found!"; 
    cleanup 1; 
    exit 1; 
  }
  
  ZIP=$(echo *.zip)
  MD5=$(md5sum "$ZIP" | cut -d' ' -f1)
  
  if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
    send_file "$ZIP" "✅ Compilation took ${MinsTook} minute(s) and ${SecsTook} second(s). MD5: ${MD5}"
    sleep 1
    
    # Send announcement to channel if configured
    if [ "${SEND_ANNOUNCEMENT}" = "yes" ]; then
      send_build_announcement
    fi
  else
    msg "✅ Compilation completed successfully!"
    msg "Build time: ${MinsTook} minute(s) and ${SecsTook} second(s)"
    msg "ZIP file: $ZIP"
    msg "MD5: ${MD5}"
  fi
  
  # Cleanup if enabled
  if [ "${CLEANUP}" = "yes" ]; then
    cleanup
  fi
}

#################################################
# Stuffs to run after a successfull compilation #
#################################################

# Unified function to send build announcement to Telegram channel
send_build_announcement() {
  cd "${AnyKernelPath}" || return 1
  
  ZIP=$(echo *.zip)
  
  # Build announcement message
  local announcement_msg="📢 | <i>New kernel build!</i>

<b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>
<b>• DEVICE :</b> <code>$DeviceModel (${DeviceCodename})</code>
<b>• KERNEL NAME :</b> <code>${KernelName}</code>
<b>• KERNEL LINUX VERSION :</b> <code>${Sublevel}</code>
<b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
<b>• KERNELSU :</b> <code>${KERNELSU}</code>"

  # Add KernelSU version if enabled
  if [ "${KERNELSU}" = "yes" ] || [ "${KERNELSU_NEXT}" = "yes" ]; then
    announcement_msg+="\n<b>• KERNELSU VERSION :</b> <code>${KERNELSU_VERSION}</code>"
  fi
  
  announcement_msg+="\n<b>• MD5 :</b> <code>${MD5}</code>

<i>Compilation took ${MinsTook} minute(s) and ${SecsTook} second(s)</i>
<i>!! Make sure to backup your boot and dtbo on TWRP before flashing !!</i>"

  send_announcement "$ZIP" "$announcement_msg"
}

# Unified function to send build info to the given telegram chat
send_build_info() {
  local build_info_msg="⚙ <i>Kernel compilation has been started</i>
  <b>===========================================</b>
  <b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>
  <b>• DEVICE :</b> <code>$DeviceModel (${DeviceCodename})</code>
  <b>• KERNEL NAME :</b> <code>${KernelName}</code>
  <b>• KERNEL LINUX VERSION :</b> <code>${Sublevel}</code>
  <b>• KERNEL BRANCH :</b> <code>${Branch}</code>
  <b>• COMPILER :</b> <code>${COMPILER}</code>
  <b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
  <b>• KERNELSU :</b> <code>${KERNELSU}</code>
  <b>• KERNELSU NEXT :</b> <code>${KERNELSU_NEXT}</code>"

  # Add KernelSU version if enabled
  if [ "${KERNELSU}" = "yes" ] || [ "${KERNELSU_NEXT}" = "yes" ]; then
    build_info_msg+="\n  <b>• KERNELSU VERSION :</b> <code>${KERNELSU_VERSION}</code>"
  fi
  
  build_info_msg+="\n  <b>===========================================</b>"
  
  send_msg "$build_info_msg"
}

# Function to make a flashable zip
make_zip() {
    cd "${AnyKernelPath}" || exit 1
    
    local kernel_string
    if [ "${KERNELSU}" = "yes" ]; then
      kernel_string="${KernelName} ${Sublevel} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DeviceModel} (${DeviceCodename}) | KernelSU Version: ${KERNELSU_VERSION}"
    else
      kernel_string="${KernelName} ${Sublevel} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DeviceModel} (${DeviceCodename})"
    fi
    
    sed -i "s/kernel.string=.*/kernel.string=${kernel_string}/g" anykernel.sh
    
    local zip_name="[${KERNEL_VARIANT}]-${KernelName}-${Sublevel}-${DeviceCodename}.zip"
    zip -r9 "${zip_name}" * -x .git README.md *placeholder
    
    cd "${MainPath}" || exit 1
    
    # Create the builds directory if it doesn't exist
    mkdir -p builds
    
    # Copy the ZIP file to the builds directory with date
    zipname=$(basename "${AnyKernelPath}/${zip_name}" .zip)
    cp "${AnyKernelPath}/${zip_name}" "./builds/${zipname}-${Date}.zip"
}

# Function to automatically regenerate defconfig
regen_config() {
    [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
    
    msg "Regenerating defconfig..."
    
    if [ ! -f "out/.config" ]; then
        err "Cannot find .config file to regenerate defconfig!"
        return 1
    fi
    
    cp out/.config "arch/${DeviceArch}/configs/${DefConfig}"
    
    if git diff --quiet "arch/${DeviceArch}/configs/${DefConfig}"; then
        msg "No changes detected in defconfig."
        return 0
    fi
    
    git add "arch/${DeviceArch}/configs/${DefConfig}"
    git commit -m "defconfig: Regenerate"
    
    msg "Defconfig regenerated successfully."
}

#####################
# Begin compilation #
#####################

# Function to start compilation of the kernel
compile_kernel() {
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"

  # The time when compilation have started
  StartTime="$(date +"%s")"

  # Send build info to telegram chat
  send_build_info

  # Disable LLVM POLLY on proton clang
  if [ "${ClangName}" = "proton" ]; then
    sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' "${MainPath}/arch/${DeviceArch}/configs/${DefConfig}" || true
  else
    sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' "${MainPath}/arch/${DeviceArch}/configs/${DefConfig}" || true
  fi

  # Configure make command based on compiler
  MAKE=()
  if [[ "${ClangName}" =~ ^(aosp|yuki)$ ]]; then
    MAKE+=(
      CC=clang
      LD=ld.lld
      LLVM=1
      LLVM_IAS=1
      AR=llvm-ar
      NM=llvm-nm
      OBJCOPY=llvm-objcopy
      OBJDUMP=llvm-objdump
      STRIP=llvm-strip
      CLANG_TRIPLE=aarch64-linux-gnu-
      CROSS_COMPILE=aarch64-linux-android-
      CROSS_COMPILE_ARM32=arm-linux-androideabi-
    )
  else
    MAKE+=(
      CC=clang
      LD=ld.lld
      LLVM=1
      LLVM_IAS=1
      AR=llvm-ar
      NM=llvm-nm
      OBJCOPY=llvm-objcopy
      OBJDUMP=llvm-objdump
      STRIP=llvm-strip
      CLANG_TRIPLE=${CrossCompileFlagTriple}
      CROSS_COMPILE=${CrossCompileFlag64}
      CROSS_COMPILE_ARM32=${CrossCompileFlag32}
    )
  fi

  msg "Compilation has been started.."
  make O=out ARCH=${DeviceArch} ${DefConfig}

  if [ "${GenBuildLog}" = "yes" ]; then
      make -j"${AvailableCores}" ARCH=${DeviceArch} O=out "${MAKE[@]}" 2>&1 | tee build.log
  else
      make -j"${AvailableCores}" ARCH=${DeviceArch} O=out "${MAKE[@]}"
  fi

  # Check if build was successful
  if [[ ! -f "${Image}" ]]; then
      if [ "${GenBuildLog}" = "yes" ];then
          BuildLog="build.log"
          err "Failed to compile, check build log to fix it!"
          if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
              send_file "${BuildLog}" "Failed to compile kernel for ${DeviceCodename}, check build log to fix it!"
          fi
      else
          err "Failed to compile, check console log to fix it!"
          if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
              send_msg "Failed to compile kernel for ${DeviceCodename}, check console log to fix it!"
          fi
      fi
      cleanup
      exit 1
  else
      msg "Successfully compiled the kernel!"
      if [ "${GenBuildLog}" = "yes" ]; then
          BuildLog="build.log"
          if [ "${ENABLE_TELEGRAM}" = "yes" ]; then
              send_file "${BuildLog}" "Successfully compiled the kernel! Here is the log if you want to check for what's going on."
          else
              msg "Build log saved as: ${BuildLog}"
          fi
      fi
      if [ "${RegenerateDefconfig}" = "yes" ]; then
          regen_config
      fi
      clone_anykernel
      cp "${Image}" "${AnyKernelPath}"
  fi
}

# Calling functions
export_variables
clone_clang
update_clang
add_kernelsu

# Ensure clang exists before compiling
if [ ! -x "${ClangPath}/bin/clang" ]; then
    err "Clang executable not found at ${ClangPath}/bin/clang after cloning"
    exit 1
fi

compile_kernel
make_zip
EndTime=$(date +"%s")
MinsTook=$(((${EndTime} - ${StartTime}) / 60))
SecsTook=$(((${EndTime} - ${StartTime}) % 60))
push
