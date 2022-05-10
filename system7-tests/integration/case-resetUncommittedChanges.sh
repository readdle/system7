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
popd > /dev/null

echo

assert s7 reset Dependencies/ReaddleLib

echo
echo "s7 status:"
s7 status
echo

assert test sqrt = `cat Dependencies/ReaddleLib/RDMath.h`

pushd Dependencies/ReaddleLib > /dev/null
  git status
  git rev-parse HEAD
popd > /dev/null
