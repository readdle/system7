#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

PRE_READDLE_LIB_TIMES=`git rev-parse HEAD`

s7 add --stage Dependencies/ReaddleLib "$S7_ROOT/github/ReaddleLib"
git commit -m "add ReaddleLib subrepo"

pushd Dependencies/ReaddleLib > /dev/null
  echo sqrt > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

assert git push


cd "$S7_ROOT/nik"

assert git clone '"$S7_ROOT/github/rd2"'

cd rd2

git checkout -b experiment

pushd Dependencies/ReaddleLib > /dev/null
  echo faster-sqrt > RDMath.h
  git add RDMath.h
  git commit -m"faster sqrt"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

git push -u origin experiment


cd "$S7_ROOT/pastey/rd2"

git fetch

MODERN_TIMES=`git rev-parse HEAD`
git checkout $PRE_READDLE_LIB_TIMES

git reset --hard $MODERN_TIMES

git merge --no-ff --no-edit origin/experiment
assert test -d Dependencies/ReaddleLib
assert test faster-sqrt = `cat Dependencies/ReaddleLib/RDMath.h`
