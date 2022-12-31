#! /bin/bash
# Copyright © 2022, XSans0 <xsansdroid@gmail.com>
# Copyright © 2022, Neebe3289 <neebexd@gmail.com>
# Just a simple script for auto push aosp-clang

# Send info
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

# Dependencies
apt-get install -y git wget tar git-lfs

# Path
export MainPath="$(pwd ...)"
# Clang version
export ClangVer="clang-r475365b"

mkdir ${MainPath}/tmp
cd ${MainPath}/tmp

msg "Start to clone aosp clang"
wget --quiet https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/${ClangVer}.tgz
tar -xf ${ClangVer}.tgz
rm -rf ${ClangVer}.tgz

msg "Clone repository of ur gitlab"
git clone "https://$GH_USER:$GL_TOKEN@$GL_REPO" ${MainPath}/push
rm -rf ${MainPath}/push/*
cp -rf ${MainPath}/tmp/* ${MainPath}/push/

msg "Start to push"

git config --global user.name "$GH_USER"
git config --global user.email "$GH_EMAIL"

cd ${MainPath}/push/
git add .
git commit -s --quiet -m "Import prebuilts clang from https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/${ClangVer}"
git branch -m ${ClangVer}
git push -u origin ${ClangVer}

