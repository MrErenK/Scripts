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
  wget "https://gist.github.com/dakkshesh07/240736992abf0ea6f0ee1d8acb57a400/raw/a835c3cf8d99925ca33cec3b210ee962904c9478/patch-for-old-glibc.sh" -O patch.sh && chmod +x patch.sh && ./patch.sh
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
KERNEL_VARIANT="Neutron"
KERNELSU="no"

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
      cd ${MainPath}
      cp out/.config arch/${ARCH}/configs/${DEVICE_DEFCONFIG}
      git clone --depth=1 https://github.com/Neebe3289/AnyKernel3 -b begonia-r-oss ${AnyKernelPath}
      cp $IMAGE ${AnyKernelPath}
   else
      echo "❌ Compile Kernel for $DEVICE_CODENAME failed, Check build log to fix it!"
      exit 1
   fi
}

# Zipping function
function zipping() {
    cd ${AnyKernelPath} || exit 1
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME}-${SUBLEVEL}-${KERNEL_VARIANT} by ${KBUILD_BUILD_USER}/g" anykernel.sh
    zip -r9 "[${KERNEL_VARIANT}]"-${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}-${DATE}.zip * -x .git README.md *placeholder
    cd ..
    mkdir builds
    mv ${AnyKernelPath}/*.zip ./builds
}

# KernelSU function
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

