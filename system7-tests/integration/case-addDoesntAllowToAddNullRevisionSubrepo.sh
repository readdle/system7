#!/bin/sh

git init --bare -q github/Empty

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

s7 add --stage Dependencies/Empty "$S7_ROOT/github/Empty"
assert test $? -ne 0
