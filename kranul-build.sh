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

# Path
MainPath="$(readlink -f -- $(pwd))"
MainClangPath="${MainPath}/clang"
ClangPath="${MainClangPath}"
AnyKernelPath="${MainPath}/anykernel"
STARTTIME="$(TZ='Asia/Jakarta' date +%H%M)"

# Clone toolchain
ClangPath=${MainClangPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
if [ ! -f "${ClangPath}/bin/clang" ]; then
  mkdir ${ClangPath}
  cd ${ClangPath}
  curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
  chmod +x antman && ./antman -S
  cd ..
fi

# Toolchain setup
export PATH="${ClangPath}/bin:${PATH}"
export KBUILD_COMPILER_STRING="$(${ClangPath}/bin/clang --version | head -n 1)"

# Enviromental variable
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
BUILD_LOG="${MainPath}/out/log-${STARTTIME}.txt"
CORES="$(nproc --all)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
DATE="$(date +%H.%M-%d.%m)"
OSS="R-OSS"
KERNEL_VARIANT="Neutron"
KERNELSU="no"

# Function of telegram
if [ ! -f "${MainPath}/Telegram/telegram" ]; then
  git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
fi

TELEGRAM="${MainPath}/Telegram/telegram"
tgm() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

tgf() {
    "${TELEGRAM}" -H \
    -f "$1" \
    "$2"
}

# Function for uploaded kernel file
function push() {
    cd ${AnyKernelPath}
    ZIP=$(echo *.zip)
    tgf "$ZIP" "✅ Compile took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). Cleaning workspace..."
    tgf "$BUILD_LOG" "Here is the build log if you want to check warnings etc."
    cleanup
}

# Send info build to telegram channel
tgm "
⚙ <i>Compilation has been started</i>
<b>===========================================</b>
<b>• DATE :</b> <code>$(TZ=Asia/Jakarta date +"%A, %d %b %Y, %H:%M:%S")</code>
<b>• DEVICE :</b> <code>${DEVICE_MODEL} ($DEVICE_CODENAME)</code>
<b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>
<b>• LINUX VERSION :</b> <code>${SUBLEVEL}</code>
<b>• BRANCH NAME :</b> <code>${BRANCH}</code>
<b>• COMPILER :</b> <code>${KBUILD_COMPILER_STRING}</code>
<b>• OSS VERSION :</b> <code>${OSS}</code>
<b>• KERNEL VARIANT :</b> <code>${KERNEL_VARIANT}</code>
<b>• KERNELSU :</b> <code>${KERNELSU}</code>
<b>===========================================</b>
"

# Start Compile
START=$(date +"%s")

compile(){
make O=out ARCH=arm64 $DEVICE_DEFCONFIG
make -j"$CORES" ARCH=arm64 O=out \
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
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    2>&1 | tee "${BUILD_LOG}"

   if [[ -f "$IMAGE" ]]; then
      git clone --depth=1 https://github.com/Neebe3289/AnyKernel3 -b begonia-r-oss ${AnyKernelPath}
      cp $IMAGE ${AnyKernelPath}
   else
      tgf "$BUILD_LOG" "<i> ❌ Compile Kernel for $DEVICE_CODENAME failed, Check build log to fix it!</i>"
      exit 1
   fi
}

# Function zipping environment
function zipping() {
    cd ${AnyKernelPath} || exit 1
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME}-${SUBLEVEL}-${KERNEL_VARIANT} by ${KBUILD_BUILD_USER}/g" anykernel.sh
    zip -r9 "[${KERNEL_VARIANT}]"${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}-${OSS}-${DATE}.zip * -x .git README.md *placeholder
    cd ..
}

function cleanup() {
    cd ${MainPath}
    sudo rm -rf anykernel/
    sudo rm -rf out/
}

function kernelsu() {
    if [ "$KERNELSU" = "yes" ];then
      KERNEL_VARIANT="${KERNEL_VARIANT}-KernelSU"
      if [ ! -f "${MainPath}/KernelSU/README.md" ]; then
        cd ${MainPath}
        curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
        echo "CONFIG_KPROBES=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
        echo "CONFIG_HAVE_KPROBES=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
        echo "CONFIG_KPROBE_EVENTS=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
        echo "CONFIG_OVERLAY_FS=y" >> arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
      fi
    fi
}

kernelsu
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push

