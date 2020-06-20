#!/bin/sh

set -x

which xcodebuild > /dev/null
if [ 0 -ne $? ]
then
    echo "error: failed to locate 'xcodebuild' command. Do you have Xcode? Run 'xcode-select -switch-path <path to Xcode.app>' (most common path to Xcode.app is '/Applications/Xcode.app'."
    exit 1
fi

xcodebuild -target system7 -configuration Release DSTROOT="" install
if [ 0 -ne $? ]
then
    echo "error: s7 build failed. Please contact s7 developers."
    exit 1
fi

mkdir -p "${HOME}/bin"
cp usr/local/bin/s7 "${HOME}/bin/"
