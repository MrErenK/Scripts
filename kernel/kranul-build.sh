#!/usr/bin/env bash
#
# Copyright (C) 2022-2023 Neebe3289 <neebexd@gmail.com>
# Copyright (C) 2023 MrErenK <akbaseren4751@gmail.com>
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

# Check if config.env exists
if [ ! -f "config.env" ]; then
    err "Error: config.env not found. Please create the configuration file."
    exit 1
fi

# Load variables from config.env
source config.env

# Function to show informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;31m$*\e[0m"
}

# Check Telegram variables
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT" ]; then
    err "Missing environment variable: TELEGRAM_TOKEN or TELEGRAM_CHAT! Please check and edit the configuration file."
    exit 1
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
  AvailabeCores="$(nproc --all)"

  # Kernel build user and host
  KBUILD_BUILD_USER="${USER}"
  KBUILD_BUILD_HOST="${HOSTNAME}"

  # Timezone
  TZ="Europe/Istanbul"

  if [ "${ClangName}" = "azure" ] || [ "${ClangName}" = "neutron" ] || [ "{$ClangName}" = "proton" ] || [ "${ClangName}" = "zyc" ]
  then
    ClangPath="${MainPath}"/clang-${ClangName}
    PATH=${ClangPath}/bin:$PATH
    KBUILD_COMPILER_STRING="$(${ClangPath}/bin/clang --version | head -n 1)"
    COMPILER="${KBUILD_COMPILER_STRING}"
  elif [ "${ClangName}" = "aosp" ] || [ "${ClangName}" = "yuki" ]
  then
    ClangPath="${MainPath}"/clang-${ClangName}
    PATH=${ClangPath}/bin:${MainPath}/gcc32/bin:${MainPath}/gcc64/bin:$PATH
    LD_LIBRARY_PATH=${ClangPath}/lib:$LD_LIBRARY_PATH
    KBUILD_COMPILER_STRING="$(${ClangPath}/bin/clang --version | head -n 1)"
    COMPILER="${KBUILD_COMPILER_STRING}"
  fi

  export AnyKernelPath AvailableCores ClangPath COMPILER KBUILD_BUILD_USER KBUILD_BUILD_HOST KBUILD_COMPILER_STRING PATH TZ
}

# Function to clone anykernel
clone_anykernel() {
    if ! git clone --depth=1 "${AnyKernelRepo}" -b "${AnyKernelBranch}" "${AnyKernelPath}"; then
        err "Failed to clone AnyKernel repository."
        exit 1
    fi
}

# Function to add KernelSU
add_kernelsu() {
    if [ "${KERNELSU}" = "yes" ]
    then
      [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
      KERNEL_VARIANT="${KERNEL_VARIANT}-KSU"
      if [ ! -f "${MainPath}/KernelSU/README.md" ]
      then
        curl -LSsk "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
        git apply KSU.patch
      fi
      KERNELSU_VERSION="$((10000 + $(cd KernelSU && git rev-list --count HEAD) + 200))"
      git submodule update --init; cd KernelSU; git pull origin main; cd ..
    fi
}

###################
# Toolchain setup #
###################

# Function to clone toolchain
clone_clang()
{
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"

  if [ "${ClangName}" != "aosp" ] && [ "${ClangName}" != "azure" ] && [ "${ClangName}" != "neutron" ] && [ "${ClangName}" != "proton" ] && [ "${ClangName}" != "yuki" ] && [ "${ClangName}" != "zyc" ]
  then
    msg "[!] Incorrect clang name. Check config.env for clang names."
    exit 1
  elif [ "${ClangName}" = "aosp" ]
  then
    msg "[!] Clang is set to aosp, cloning it..."
    if [ -x "clang-aosp/bin/clang" ]
    then
      msg "[-] Clang already exists. skipping"
    else
      git clone https://gitlab.com/Neebe3289/android_prebuilts_clang_host_linux-x86.git -b clang-r498229 clang-aosp --depth=1
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 -b lineage-19.1 gcc64
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 -b lineage-19.1 gcc32
      patch_glibc
    fi
  elif [ "${ClangName}" = "azure" ]
  then
    msg "[!] Clang is set to azure, cloning it..."
    if [ -x "clang-azure/bin/clang" ]
    then
      msg "[-] Clang already exists. skipping"
    else
      git clone https://gitlab.com/Panchajanya1999/azure-clang clang-azure --depth=1
      patch_glibc
    fi
  elif [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]
  then
    msg "[!] Clang is set to neutron, cloning it..."
    if [ -x "clang-neutron/bin/clang" ]
    then
      msg "[-] Clang already exists. skipping"
    else
      mkdir -p clang-neutron; cd clang-neutron
      curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman && ./antman -S
      patch_glibc
    fi
  elif [ "${ClangName}" = "proton" ]
  then
    msg "[!] Clang is set to proton, cloning it..."
    if [ -x "clang-proton/bin/clang" ]
    then
      msg "[-] Clang already exists. skipping"
    else
      git clone https://github.com/kdrag0n/proton-clang clang-proton --depth=1
      patch_glibc
    fi
  elif [ "${ClangName}" = "yuki" ]
  then
    msg "[!] Clang is set to yuki, cloning it..."
    if [ -x "clang-yuki/bin/clang" ]
    then
      msg "[-] Clang already exists. skipping"
    else
      git clone https://gitlab.com/TheXPerienceProject/yuki_clang clang-yuki -b "17.0.0" --depth=1
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 -b lineage-19.1 gcc64
      git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 -b lineage-19.1 gcc32
      patch_glibc
    fi
  elif [ "${ClangName}" = "zyc" ]
  then
    msg "[!] Clang is set to zyc, cloning it..."
    if [ -x "clang-zyc/bin/clang" ]
    then
      msg "[-] Clang already exists. skipping"
    else
      mkdir -p clang-zyc; cd clang-zyc
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
      tar -xf zyc-clang.tar.gz && rm -f zyc-clang.tar.gz
      patch_glibc
    fi
  else
    msg "[!] Clang already exists, skipping..."
  fi
}

# Update clang
update_clang()
{
  # cd info MainPath if not in there
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"

  # Start checking updates by clang name
  if [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]
  then
    msg "[!] Clang is set to neutron, checking for updates..."
    cd clang-neutron
    if [ "$(./antman -U | grep "Nothing to do")" = "" ]
    then
      patch_glibc
    else
      msg "[!] No updates have been found, skipping"
    fi
    cd ..
  elif [ "${ClangName}" = "zyc" ]
  then
    msg "[!] Clang is set to zyc, checking for updates..."
    cd clang-zyc
    ZycLatest="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-lastbuild.txt)"
    if [ "$(cat README.md | grep "Build Date : " | cut -d: -f2 | sed "s/ //g")" != "${ZycLatest}" ]
    then
      msg "[!] An update have been found, updating..."
      sudo rm -rf ./*
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
      tar -xf zyc-clang.tar.gz
      rm -f zyc-clang.tar.gz
    else
      msg "[!] No updates have been found, skipping..."
    fi
    cd ..
  elif [ "${ClangName}" = "azure" ]
  then
    msg "[!] Clang is set to azure, checking for updates..."
    cd clang-azure
    git fetch -q origin main
    git pull origin main
    cd ..
  elif [ "${ClangName}" = "proton" ]
  then
    msg "[!] Clang is set to proton, checking for updates..."
    cd clang-proton
    git fetch -q origin master
    git pull origin master
    cd ..
  elif [ "${ClangName}" = "yuki" ]
  then
    msg "[!] Clang is set to yuki, checking for updates..."
    cd clang-yuki
    git fetch -q origin "17.0.0"
    git pull origin "17.0.0"
    cd ..
  fi
}

# Patch glibc to prevent glibc version related errors
patch_glibc()
{
  cd ${MainClangPath}-${ClangName}
  if [ ${ClangName} = "neutron" ]
  then
    ./antman --patch=glibc
    cd ..
  else
    curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman --patch=glibc
    cd ..
  fi
}

##################
# Telegram Setup #
##################

# Clone and set Telegram script
if [ ! -f "${MainPath}/Telegram/telegram" ]
then
  git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
fi
TELEGRAM=${MainPath}/Telegram/telegram

# Function to send telegram messages
send_msg()
{
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

# Function to upload files to telegram
send_file()
{
  "${TELEGRAM}" -H \
  -f "$1" \
  "$2"
}

# Function to push announcements to telegram
send_announcement() {
  "${TELEGRAM}" -c ${TELEGRAM_CHANNEL} -H \
  -f "$1" \
  "$2"
}

# Function to upload kernel to telegram
push()
{
  cd ${AnyKernelPath}
  ZIP=$(echo *.zip)
  MD5=$(md5sum "$ZIP" | cut -d' ' -f1)
  send_file "$ZIP" "✅ Compilation took ${MinsTook} minute(s) and ${SecsTook} second(s). MD5: ${MD5}"
  sleep 1
  if [ "${SEND_ANNOUNCEMENT}" = "yes" ]
  then
    sendannouncement
  else
    if [ "${CLEANUP}" = "yes" ]
    then
      cleanup
    fi
  fi
}

# Function to send announcement to given telegram channel
sendannouncement()
{
  if [ "${TELEGRAM_CHANNEL}" = "" ]
  then
    msg "You have forgot to put the Telegram Channel ID, so can't send the announcement! Aborting..." 
    sleep 0.5
    exit 1
  fi
  if [ "${KERNELSU}" = "yes" ]
  then
    ksuannounce
  else
    announce
  fi
}

#################################################
# Stuffs to run after a successfull compilation #
#################################################

# Function of sending announcement
announce()
{
  cd ${AnyKernelPath}
  ZIP=$(echo *.zip)
  send_announcement "$ZIP" "
📢 | <i>New kernel build!</i>

<b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>
<b>• DEVICE :</b> <code>$DeviceModel (${DeviceCodename})</code>
<b>• KERNEL NAME :</b> <code>${KernelName}</code>
<b>• KERNEL LINUX VERSION :</b> <code>${Sublevel}</code>
<b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
<b>• KERNELSU :</b> <code>${KERNELSU}</code>
<b>• MD5 :</b> <code>${MD5}</code>

<i>Compilation took ${MinsTook} minute(s) and ${SecsTook} second(s)</i>
"
  if [ "${CLEANUP}" = "yes" ]
  then
    cleanup
  fi
}

# Function of sending announcement (KernelSU variant)
ksuannounce()
{
  cd ${AnyKernelPath}
  ZIP=$(echo *.zip)
  send_announcement "$ZIP" "
📢 | <i>New kernel build!</i>

<b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>
<b>• DEVICE :</b> <code>$DeviceModel (${DeviceCodename})</code>
<b>• KERNEL NAME :</b> <code>${KernelName}</code>
<b>• KERNEL LINUX VERSION :</b> <code>${Sublevel}</code>
<b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
<b>• KERNELSU :</b> <code>${KERNELSU}</code>
<b>• KERNELSU VERSION :</b> <code>${KERNELSU_VERSION}</code>
<b>• MD5 :</b> <code>${MD5}</code>

<i>Compilation took ${MinsTook} minute(s) and ${SecsTook} second(s)</i>
"
  if [ "${CLEANUP}" = "yes" ]
  then
    cleanup
  fi
}

# Function to send build info to the given telegram chat
ksusendinfo()
{
  send_msg "
  ⚙ <i>Kernel compilation has been started</i>
  <b>===========================================</b>
  <b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>
  <b>• DEVICE :</b> <code>$DeviceModel (${DeviceCodename})</code>
  <b>• KERNEL NAME :</b> <code>${KernelName}</code>
  <b>• KERNEL LINUX VERSION :</b> <code>${Sublevel}</code>
  <b>• BRANCH NAME :</b> <code>${Branch}</code>
  <b>• COMPILER :</b> <code>${COMPILER}</code>
  <b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
  <b>• KERNELSU :</b> <code>${KERNELSU}</code>
  <b>• KERNELSU VERSION :</b> <code>${KERNELSU_VERSION}</code>
  <b>===========================================</b>
  "
}

# Function to send build info to the given telegram chat
sendinfo()
{
  send_msg "
  ⚙ <i>Kernel compilation has been started</i>
  <b>===========================================</b>
  <b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>
  <b>• DEVICE :</b> <code>$DeviceModel (${DeviceCodename})</code>
  <b>• KERNEL NAME :</b> <code>${KernelName}</code>
  <b>• KERNEL LINUX VERSION :</b> <code>${Sublevel}</code>
  <b>• BRANCH NAME :</b> <code>${Branch}</code>
  <b>• COMPILER :</b> <code>${COMPILER}</code>
  <b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
  <b>• KERNELSU :</b> <code>${KERNELSU}</code>
  <b>===========================================</b>
  "
}

# Function to make a flashable zip
make_zip()
{
    cd ${AnyKernelPath} || exit 1
    if [ "${KERNELSU}" = "yes" ]
    then
      sed -i "s/kernel.string=.*/kernel.string=${KernelName} ${Sublevel} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DeviceModel} (${DeviceCodename}) | KernelSU Version: ${KERNELSU_VERSION}/g" anykernel.sh
    else
      sed -i "s/kernel.string=.*/kernel.string=${KernelName} ${Sublevel} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DeviceModel} (${DeviceCodename})/g" anykernel.sh
    fi
    zip -r9 "[${KERNEL_VARIANT}]"-${KernelName}-${Sublevel}-${DeviceCodename}.zip * -x .git README.md *placeholder
    cd ..
    mkdir -p builds
    zipname="$(basename $(echo ${AnyKernelPath}/*.zip | sed "s/.zip//g"))"
    cp ${AnyKernelPath}/*.zip ./builds/${zipname}-${Date}.zip
}

# Function to cleanup leftovers from previous build
cleanup() {
    cd ${MainPath}
    sudo rm -rf ${AnyKernelPath}
    sudo rm -rf out/
}

# Function to automatically regenerate defconfig
regen_config()
{
  cd ${MainPath}
  cp out/.config arch/${DeviceArch}/configs/${DefConfig}
  git add arch/${DeviceArch}/configs/${DefConfig}
  git commit -m "defconfig: Regenerate"
}

#####################
# Begin compilation #
#####################

# Function to start compilation of the kernel
compile_kernel()
{
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"

  # The time when compilation have started
  StartTime="$(date +"%s")"

  # Send info to telegram chat
  if [ "${KERNELSU}" = "yes" ]
  then
    ksusendinfo
  else
    sendinfo
  fi

  # Disable LLVM POLLY on proton clang
  if [ "${ClangName}" = "proton" ]
  then
    sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' ${MainPath}/arch/${DeviceArch}/configs/${DefConfig} || echo ""
  else
    sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' ${MainPath}/arch/${DeviceArch}/configs/${DefConfig} || echo ""
  fi

  # Use different make command for aosp and yuki clang
  if [ "${ClangName}" = "aosp" ] || [ "${ClangName}" = "yuki" ]
  then
    MAKE+=(
      CC=clang \
      LD=ld.lld \
      LLVM=1 \
      LLVM_IAS=1 \
      AR=llvm-ar \
      NM=llvm-nm \
      OBJCOPY=llvm-objcopy \
      OBJDUMP=llvm-objdump \
      STRIP=llvm-strip \
      CLANG_TRIPLE=aarch64-linux-gnu- \
      CROSS_COMPILE=aarch64-linux-android- \
      CROSS_COMPILE_ARM32=arm-linux-androideabi-
    )
  else
    MAKE+=(
      CC=clang \
      LD=ld.lld \
      LLVM=1 \
      LLVM_IAS=1 \
      AR=llvm-ar \
      NM=llvm-nm \
      OBJCOPY=llvm-objcopy \
      OBJDUMP=llvm-objdump \
      STRIP=llvm-strip \
      CLANG_TRIPLE=${CrossCompileFlagTriple} \
      CROSS_COMPILE=${CrossCompileFlag64} \
      CROSS_COMPILE_ARM32=${CrossCompileFlag32}
    )
  fi

  msg "Compilation has been started.."
  make O=out ARCH=${DeviceArch} ${DefConfig}

  if [ "${GenBuildLog}" = "yes" ]; then
      make -j"${AvailableCores}" ARCH=${DeviceArch} O=out "${MAKE[@]}" 2>&1 | tee build.log
  else
      make -j"${AvailableCores}" ARCH=${DeviceArch} O=out "${MAKE[@]}" 2>&1 | tee build.log
  fi

  # Copy and notice the chosen Image
  if [[ ! -f "${Image}" ]]; then
      if [ "${GenBuildLog}" = "yes" ]; then
          BuildLog=$(echo build.log)
          err "Failed to compile, check build log to fix it!"
          send_file "${BuildLog}" "Failed to compile kernel for ${DeviceCodename}, check build log to fix it!"
      else
          err "Failed to compile, check console log to fix it!"
          send_msg "Failed to compile kernel for ${DeviceCodename}, check console log to fix it!"
      fi
      cleanup
      exit 1
  else
      msg "Successfully compiled the kernel!"
      if [ "${GenBuildLog}" = "yes" ]; then
          BuildLog=$(echo build.log)
          send_file "${BuildLog}" "Successfully compiled the kernel! Here is the log if you want to check for what's going on."
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
compile_kernel
make_zip
EndTime=$(date +"%s")
MinsTook=$(((${EndTime} - ${StartTime}) / 60))
SecsTook=$(((${EndTime} - ${StartTime}) % 60))
push
