#!/bin/bash

# ./build.sh -c <chat_id> -t <bot_token> -d <defconfig_used> -p <compiler_binary_path> -v <mirai_version> -n <circleci build num>
while getopts c:t:d:p:v:n: flag
do
    case "${flag}" in
        c) chat=${OPTARG};;
        t) tokentg=${OPTARG};;
        d) defconfigs=${OPTARG};;
        p) compiler=${OPTARG};;
        v) version=${OPTARG};;
        n) circlenum=${OPTARG};;
    esac
done

KERNEL_DIR=$(pwd)
CHAT_ID=$chat
TOKEN=$tokentg
PARSE_MODE=Markdown

MIRAI_VERSION=$version
BUILD_USER=ckagenou
BUILD_HOST=scavenger
DEFCONFIG=$defconfigs
TOOLCHAIN_PATH_CLANG=$compiler

KERNEL_BUILD_VERSION=1
ZIP_NAME="Mirai-Kernel-${MIRAI_VERSION}-k4.9-$(date +%d%m)-$(date +%H%M)-ulysse.zip"

# Color
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NOCOL='\033[0m'

clang_build() {
    sendMessage "#$circlenum Mirai Build Started!"
    make PATH=${TOOLCHAIN_PATH_CLANG}:${PATH} -j12 \
    ARCH=arm64 \
    O=out \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJDUMP=llvm-objdump \
    OBJCOPY=llvm-objcopy \
    STRIP=llvm-strip
}

sendMessage() {
    # sendMessage <TEXT>
    MESSAGE=$1
    curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" -F chat_id=${CHAT_ID}  -F "text=${MESSAGE}" -F parse_mode=${PARSE_MODE}
}

sendDocument() {
    # sendDocument <@file_name or file_id> <caption>
    FILE=$1
    CAPTION=$2
    curl -s "https://api.telegram.org/bot${TOKEN}/sendDocument" -F chat_id=${CHAT_ID} -F document=${FILE} -F "caption=${CAPTION}" -F parse_mode=${PARSE_MODE}
}

export KBUILD_BUILD_USER=${BUILD_USER}
export KBUILD_BUILD_HOST=${BUILD_HOST}
export KERNEL_BUILD_VERSION=$KERNEL_BUILD_VERSION
echo -e " "
echo -e "Build started...$NOCOL"

date1=$(date +"%s")
make ARCH=arm64 O=out $DEFCONFIG
clang_build
if [ $? -ne 0 ]; then
    echo "Build failed"
    sendMessage "Mirai Kernel Build Failed!"
    return 1
else
    date2=$(date +"%s")
    diff=$(($date2-$date1))
    kernel_ver=$(cat out/.config | grep -oP '(?<=Linux/arm64 )[^ ]*')
    echo "Build completed in : $(($diff / 3600 )) hours $((($diff % 3600) / 60)) minutes $(($diff % 60)) seconds"
    commit=$(git log --pretty=format:'%h %s' -1)
    if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
        cp out/arch/arm64/boot/Image.gz-dtb ../AK3/
        pushd ../AK3
        zip -r9 ../upload/${ZIP_NAME} ./* -x *.zip*
        popd
        sendDocument @../upload/${ZIP_NAME} "#$circlenum *Mirai Kernel Build completed in *: \`$((($diff % 3600) / 60)) minutes $(($diff % 60)) seconds\` using \`ulysse_defconfig\` at latest commit :
\`$commit\`.

*Kernel ver *: \`$kernel_ver\`" > /dev/null
        sendDocument @out/arch/arm64/boot/Image.gz-dtb > /dev/null
        echo " "
        echo "Upload Success"
        rm ../upload/${ZIP_NAME} -rf
        echo "zip cleaned"
        return 0
    fi

fi

echo " "
