#!/bin/sh

S7_OPTIONS_PATH=".s7options"
S7_SYSTEM_OPTIONS_PATH="/etc/s7options"


git clone github/rd2 pastey/rd2

cd pastey/rd2

echo "[add]\n transport-protocols = ssh, git" > "$S7_OPTIONS_PATH"

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

setTestOptionsFileContent "$S7_SYSTEM_OPTIONS_PATH" "[add]\ntransport-protocols = https, http"

s7 add --stage Dependencies/System7 "https://github.com/readdle/system7.git"
assert test $? -ne 0

restoreOriginalOptionsFileContent "$S7_SYSTEM_OPTIONS_PATH"
