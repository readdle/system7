#!/bin/sh

git init --bare -q github/Detached

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

git clone "$S7_ROOT/github/Detached" Dependencies/Detached

pushd Dependencies/Detached > /dev/null
    echo asdf > f
    git add f
    git commit -m"add file"

    git checkout --detach HEAD
popd > /dev/null

s7 add --stage Dependencies/Detached
assert test $? -ne 0
