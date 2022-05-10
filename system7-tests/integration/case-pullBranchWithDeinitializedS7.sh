#!/bin/sh

git clone github/rd2 pastey/rd2

cd "$S7_ROOT/pastey/rd2"

assert s7 init
assert git add .
assert s7 add --stage ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m "\"init s7\""

assert s7 deinit
assert git add -u
assert git commit -m "\"deinit s7\""
assert git clean -ffd

assert git push
assert git checkout -B master HEAD~1
assert test -f .s7control
assert test -d ReaddleLib

assert git pull
assert test ! -f .s7control
assert test ! -d ReaddleLib
