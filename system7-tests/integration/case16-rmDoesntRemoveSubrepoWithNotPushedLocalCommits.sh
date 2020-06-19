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

pushd Dependencies/ReaddleLib > /dev/null
  echo experiment > RDMath.h
  git commit -am"experiment"
popd > /dev/null

echo

s7 rm Dependencies/ReaddleLib

assert test 0 -ne $?
assert test experiment = `cat Dependencies/ReaddleLib/RDMath.h`
