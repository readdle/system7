#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init

assert git add .
assert git commit -m "\"init s7\""

assert git push
