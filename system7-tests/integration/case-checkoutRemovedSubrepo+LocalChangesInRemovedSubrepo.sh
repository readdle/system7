#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'

assert test -d Dependencies/ReaddleLib

git checkout -b experiment

pushd Dependencies/ReaddleLib > /dev/null
  echo iPad11 > RDSystemInfo.h
  git add RDSystemInfo.h
  git commit -m"add RDSystemInfo.h"
popd > /dev/null

git checkout main

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

assert test -d Dependencies/ReaddleLib

assert s7 rm Dependencies/ReaddleLib

assert git add .s7substate .gitignore
assert git commit -m'"drop ReaddleLib"'

assert git push



cd "$S7_ROOT/pastey/rd2"

assert git pull

assert test ! -d Dependencies/ReaddleLib

git checkout experiment

assert test -d Dependencies/ReaddleLib

pushd Dependencies/ReaddleLib > /dev/null
  echo iPhoneX >> RDSystemInfo.h
  git add RDSystemInfo.h
  git commit -m"up RDSystemInfo.h"
popd > /dev/null

git checkout main

# in case checkout leaves subrepo, checkout still succeeds
assert test 0 -eq $?

assert test -d Dependencies/ReaddleLib
assert grep '"iPhoneX"' Dependencies/ReaddleLib/RDSystemInfo.h > /dev/null
