#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'

pushd Dependencies/ReaddleLib > /dev/null
  echo sqrt > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
popd > /dev/null

assert s7 rebind --stage

assert git commit -m '"add ReaddleLib subrepo"'

echo
git checkout -b experiment

echo "experiment" > file.cpp
git add file.cpp
git commit -m"experiment"

pushd Dependencies/ReaddleLib > /dev/null
  echo experiment > RDMath.h
popd > /dev/null

echo
git checkout main

assert test 1 -eq $?
assert test experiment = `cat Dependencies/ReaddleLib/RDMath.h`
assert test ! -f file.cpp # but Git still switched to main. Only subrepos are not in sync
