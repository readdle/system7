#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

git checkout -b s7

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'

assert git push -u origin s7


git switch master

assert test ! -d Dependencies/ReaddleLib
assert test ! -f .s7control
if [[ $(git status -s) ]]
then
    # git status must be clean
    assert false
fi

git switch s7

assert test -d Dependencies/ReaddleLib
assert test -f .s7control
if [[ $(git status -s) ]]
then
    # git status must be clean
    assert false
fi
