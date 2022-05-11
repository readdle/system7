#!/bin/sh

S7_OPTIONS_PATH=".s7options"
export S7_USER_OPTIONS_PATH=".s7-user-options"


git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

echo "[add]\n transport-protocols = ssh, git" > "$S7_OPTIONS_PATH"
echo "[add]\ntransport-protocols = https, http" > "$S7_USER_OPTIONS_PATH"

s7 add --stage Dependencies/System7 "https://github.com/readdle/system7.git"
assert test $? -ne 0
