#!/bin/sh

git clone github/rd2 pastey/rd2

cd "$S7_ROOT/pastey/rd2"

assert s7 init
assert git add .
assert s7 add --stage ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
git commit -m "\"init s7\""

assert git checkout -b no-s7
assert s7 deinit
assert git add -u
assert git commit -m "\"deinit s7\""
assert git clean -ffd
assert test ! -d ReaddleLib

assert git checkout master
assert git merge --no-edit no-s7
assert test ! -f .s7substate
assert test ! -f .s7control
assert test ! -d ReaddleLib
