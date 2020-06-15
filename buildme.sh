#!/bin/sh

xcodebuild -target system7 -configuration Release DSTROOT="" install
mkdir -p "${HOME}/bin"
cp usr/local/bin/s7 "${HOME}/bin"
