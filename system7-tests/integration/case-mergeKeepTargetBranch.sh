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

git checkout -b release

pushd Dependencies/ReaddleLib > /dev/null
  git checkout -b release
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

echo

git checkout main

echo "" >> .s7substate
git commit -am"fake change of .s7substate"

echo
S7_MERGE_DRIVER_KEEP_TARGET_BRANCH="main" S7_MERGE_DRIVER_RESPONSE="m" git merge --no-edit release
assert test 0 -eq $?

echo
echo "resulting .s7substate:"
cat .s7substate
echo

grep "release" .s7substate > /dev/null
assert test 0 -ne $? # config must not contain 'release'

grep "main" .s7substate > /dev/null
assert test 0 -eq $? # config must not contain 'main'
