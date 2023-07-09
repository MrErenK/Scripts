#!/usr/bin/env bash
#
# Copyright (C) 2022-2023 Neebe3289 <neebexd@gmail.com>
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
# Personal script for kranul compilation !!

# Load variables from config.env
export $(grep -v '^#' config.env | xargs)

# Telegram Bot Token checking
if [ "$TELEGRAM_TOKEN" = "" ];then
  echo "You have forgot to put the Telegram Bot Token! Aborting..."
  sleep 0.5
  exit 1
fi

# Telegram Chat checking
if [ "$TELEGRAM_CHAT" = "" ];then
  echo "You have forgot to put the Telegram Chat ID! Aborting..."
  sleep 0.5
  exit 1
fi

# Path
MainPath="$(readlink -f -- $(pwd))"
MainClangPath="${MainPath}/clang"
AnyKernelPath="${MainPath}/anykernel"
CrossCompileFlagTriple="aarch64-linux-gnu-"
CrossCompileFlag64="aarch64-linux-gnu-"
CrossCompileFlag32="arm-linux-gnueabi-"

# Clone toolchain
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
function getclang() {
  if [ "${ClangName}" = "azure" ]; then
    if [ ! -f "${MainClangPath}-azure/bin/clang" ]; then
      echo "[!] Clang is set to azure, cloning it..."
      git clone https://gitlab.com/Panchajanya1999/azure-clang clang-azure --depth=1
      ClangPath="${MainClangPath}"-azure
      export PATH="${ClangPath}/bin:${PATH}"
      cd ${ClangPath}
      wget "https://gist.github.com/dakkshesh07/240736992abf0ea6f0ee1d8acb57a400/raw/a835c3cf8d99925ca33cec3b210ee962904c9478/patch-for-old-glibc.sh" -O patch.sh && chmod +x patch.sh && ./patch.sh
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-azure
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]; then
    if [ ! -f "${MainClangPath}-neutron/bin/clang" ]; then
      echo "[!] Clang is set to neutron, cloning it..."
      mkdir -p "${MainClangPath}"-neutron
      ClangPath="${MainClangPath}"-neutron
      export PATH="${ClangPath}/bin:${PATH}"
      cd ${ClangPath}
      curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
      chmod +x antman && ./antman -S
      ./antman --patch=glibc
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-neutron
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "proton" ]; then
    if [ ! -f "${MainClangPath}-proton/bin/clang" ]; then
      echo "[!] Clang is set to proton, cloning it..."
      git clone https://github.com/kdrag0n/proton-clang clang-proton --depth=1
      ClangPath="${MainClangPath}"-proton
      export PATH="${ClangPath}/bin:${PATH}"
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-proton
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "zyc" ]; then
    if [ ! -f "${MainClangPath}-zyc/bin/clang" ]; then
      echo "[!] Clang is set to zyc, cloning it..."
      mkdir -p ${MainClangPath}-zyc
      cd clang-zyc
      wget -q $(curl https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
      tar -xf zyc-clang.tar.gz
      ClangPath="${MainClangPath}"-zyc
      export PATH="${ClangPath}/bin:${PATH}"
      rm -f zyc-clang.tar.gz
      cd ..
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-zyc
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  else
    echo "[!] Incorrect clang name. Check config.env for clang names."
    exit 1
  fi
  if [ ! -f '${MainClangPath}-${ClangName}/bin/clang' ]; then
    export KBUILD_COMPILER_STRING="$(${MainClangPath}-${ClangName}/bin/clang --version | head -n 1)"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi
}

function updateclang() {
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
  if [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]; then
    echo "[!] Clang is set to neutron, checking for updates..."
    cd clang-neutron
    if [ "$(./antman -U | grep "Nothing to do")" = "" ];then
      ./antman --patch=glibc
    else
      echo "[!] No updates have been found, skipping"
    fi
    cd ..
    elif [ "${ClangName}" = "zyc" ]; then
      echo "[!] Clang is set to zyc, checking for updates..."
      cd clang-zyc
      ZycLatest="$(curl https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-lastbuild.txt)"
      if [ "$(cat README.md | grep "Build Date : " | cut -d: -f2 | sed "s/ //g")" != "${ZycLatest}" ];then
        echo "[!] An update have been found, updating..."
        sudo rm -rf ./*
        wget -q $(curl https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
        tar -xf zyc-clang.tar.gz
        rm -f zyc-clang.tar.gz
      else
        echo "[!] No updates have been found, skipping..."
      fi
      cd ..
    elif [ "${ClangName}" = "azure" ]; then
      cd clang-azure
      git fetch -q origin main
      git pull origin main
      cd ..
    elif [ "${ClangName}" = "proton" ]; then
      cd clang-proton
      git fetch -q origin master
      git pull origin master
      cd ..
  fi
}

# Enviromental variable
STARTTIME="$(TZ='Asia/Jakarta' date +%H%M)"
export TZ="Asia/Jakarta"
DEVICE_MODEL="Redmi Note 8 Pro"
DEVICE_CODENAME="begonia"
export DEVICE_DEFCONFIG="begonia_user_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_USER="EreN"
export KBUILD_BUILD_HOST="kernel"
export KERNEL_NAME="$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )"
export SUBLEVEL="v4.14.$(cat "${MainPath}/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"
IMAGE="${MainPath}/out/arch/arm64/boot/Image.gz-dtb"
CORES="$(nproc --all)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
DATE="$(date +%H.%M-%d.%m)"

# Function of telegram
if [ ! -f "${MainPath}/Telegram/telegram" ]; then
  git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
fi
TELEGRAM="${MainPath}/Telegram/telegram"

# Telegram message sending function
tgm() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

# Telegram file sending function
tgf() {
  "${TELEGRAM}" -H \
  -f "$1" \
  "$2"
}

tgannounce() {
  "${TELEGRAM}" -c ${TELEGRAM_CHANNEL} -H \
  -f "$1" \
  "$2"
}

# Function for uploaded kernel file
function push() {
  cd ${AnyKernelPath}
  ZIP=$(echo *.zip)
  tgf "$ZIP" "✅ Compile took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)."
  sleep 3
  if [ "${SEND_ANNOUNCEMENT}" = "yes" ];then
    sendannouncement
  else
    if [ "$CLEANUP" = "yes" ];then
      cleanup
    fi
  fi
}

function sendannouncement(){
  if [ "$TELEGRAM_CHANNEL" = "" ];then
    echo "You have forgot to put the Telegram Channel ID, so can't send the announcement! Aborting..." 
    sleep 0.5
    exit 1
  fi
  if [ "$KERNELSU" = "yes" ];then
    ksuannounce
  else
    announce
  fi
}

function announce() {
  cd ${AnyKernelPath}
  ZIP=$(echo *.zip)
  tgannounce "$ZIP" "
📢 | <i>New kernel build!</i>

<b>• DATE :</b> <code>$(TZ=Asia/Jakarta date +"%A, %d %b %Y, %H:%M:%S")</code>
<b>• DEVICE :</b> <code>${DEVICE_MODEL} ($DEVICE_CODENAME)</code>
<b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>
<b>• KERNEL LINUX VERSION :</b> <code>${SUBLEVEL}</code>
<b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
<b>• KERNELSU :</b> <code>${KERNELSU}</code>

<i>Compilation took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</i>
"
  if [ "$CLEANUP" = "yes" ];then
    cleanup
  fi
}

function ksuannounce() {
  cd ${AnyKernelPath}
  ZIP=$(echo *.zip)
  tgannounce "$ZIP" "
📢 | <i>New kernel build!</i>

<b>• DATE :</b> <code>$(TZ=Asia/Jakarta date +"%A, %d %b %Y, %H:%M:%S")</code>
<b>• DEVICE :</b> <code>${DEVICE_MODEL} ($DEVICE_CODENAME)</code>
<b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>
<b>• KERNEL LINUX VERSION :</b> <code>${SUBLEVEL}</code>
<b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
<b>• KERNELSU :</b> <code>${KERNELSU}</code>
<b>• KERNELSU VERSION :</b> <code>${KERNELSU_VERSION}</code>

<i>Compilation took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</i>
"
  if [ "$CLEANUP" = "yes" ];then
    cleanup
  fi
}

# Send info build to telegram channel
function ksusendinfo(){
  tgm "
  ⚙ <i>Compilation has been started</i>
  <b>===========================================</b>
  <b>• DATE :</b> <code>$(TZ=Asia/Jakarta date +"%A, %d %b %Y, %H:%M:%S")</code>
  <b>• DEVICE :</b> <code>${DEVICE_MODEL} ($DEVICE_CODENAME)</code>
  <b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>
  <b>• KERNEL LINUX VERSION :</b> <code>${SUBLEVEL}</code>
  <b>• BRANCH NAME :</b> <code>${BRANCH}</code>
  <b>• COMPILER :</b> <code>${KBUILD_COMPILER_STRING}</code>
  <b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
  <b>• KERNELSU :</b> <code>${KERNELSU}</code>
  <b>• KERNELSU VERSION :</b> <code>${KERNELSU_VERSION}</code>
  <b>===========================================</b>
  "
}

function sendinfo(){
  tgm "
  ⚙ <i>Compilation has been started</i>
  <b>===========================================</b>
  <b>• DATE :</b> <code>$(TZ=Asia/Jakarta date +"%A, %d %b %Y, %H:%M:%S")</code>
  <b>• DEVICE :</b> <code>${DEVICE_MODEL} ($DEVICE_CODENAME)</code>
  <b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>
  <b>• KERNEL LINUX VERSION :</b> <code>${SUBLEVEL}</code>
  <b>• BRANCH NAME :</b> <code>${BRANCH}</code>
  <b>• COMPILER :</b> <code>${KBUILD_COMPILER_STRING}</code>
  <b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
  <b>• KERNELSU :</b> <code>${KERNELSU}</code>
  <b>===========================================</b>
  "
}

# Start Compile
START=$(date +"%s")

compile(){
if [ "$ClangName" = "proton" ]; then
  sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' ${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG || echo ""
else
  sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' ${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG || echo ""
fi
make O=out ARCH=$ARCH $DEVICE_DEFCONFIG
make -j"$CORES" ARCH=$ARCH O=out \
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

   if [[ -f "$IMAGE" ]]; then
      cd ${MainPath}
      cp out/.config arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git add arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git commit -m "defconfig: Regenerate"
      git clone --depth=1 https://github.com/Neebe3289/AnyKernel3 -b begonia-r-oss ${AnyKernelPath}
      cp $IMAGE ${AnyKernelPath}
   else
      tgm "<i> ❌ Compile Kernel for $DEVICE_CODENAME failed, Check console log to fix it!</i>"
      if [ "$CLEANUP" = "yes" ];then
        cleanup
      fi
      exit 1
   fi
}

# Zipping function
function zipping() {
    cd ${AnyKernelPath} || exit 1
    if [ "$KERNELSU" = "yes" ];then
      sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME}) | KernelSU Version: ${KERNELSU_VERSION}/g" anykernel.sh
    else
      sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME})/g" anykernel.sh
    fi
    zip -r9 "[${KERNEL_VARIANT}]"-${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}.zip * -x .git README.md *placeholder
    cd ..
    mkdir -p builds
    zipname="$(basename $(echo ${AnyKernelPath}/*.zip | sed "s/.zip//g"))"
    cp ${AnyKernelPath}/*.zip ./builds/${zipname}-$DATE.zip
}

# Cleanup function
function cleanup() {
    cd ${MainPath}
    sudo rm -rf ${AnyKernelPath}
    sudo rm -rf out/
}

# KernelSU function
function kernelsu() {
    if [ "$KERNELSU" = "yes" ];then
      KERNEL_VARIANT="${KERNEL_VARIANT}-KernelSU"
      KERNELSU_VERSION="$((10000 + $(cd KernelSU && git rev-list --count HEAD) + 200))"
      if [ ! -f "${MainPath}/KernelSU/README.md" ]; then
        cd ${MainPath}
        curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
        echo "CONFIG_KPROBES=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
        echo "CONFIG_HAVE_KPROBES=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
        echo "CONFIG_KPROBE_EVENTS=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
        echo "CONFIG_OVERLAY_FS=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
      fi
      sudo rm -rf KernelSU && git clone https://github.com/tiann/KernelSU
      ksusendinfo
    else
      sendinfo
    fi
}

getclang
updateclang
kernelsu
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
