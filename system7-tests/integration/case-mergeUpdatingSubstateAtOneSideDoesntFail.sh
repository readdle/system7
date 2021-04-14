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

echo master > main.m
git add main.m

assert git commit -am '"add ReaddleLib subrepo"'


echo
git checkout -b experiment

echo experiment > main.m

assert git commit -am '"experiment in main.m"'

echo
git switch master

pushd Dependencies/ReaddleLib > /dev/null
  echo log2 >> RDMath.h
  git commit -am"add more math fun"
popd > /dev/null

assert s7 rebind --stage
assert git commit -am '"up ReaddleLib"'


echo
git switch experiment

git merge --no-edit master

assert test 0 -eq $?

cmp .s7substate .s7control
assert test 0 -eq $? # subrepos must be in sync

assert grep '"sqrt"' Dependencies/ReaddleLib/RDMath.h > /dev/null
assert grep '"log2"' Dependencies/ReaddleLib/RDMath.h > /dev/null
