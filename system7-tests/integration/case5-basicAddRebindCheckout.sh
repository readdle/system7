#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'

assert test -d Dependencies/ReaddleLib

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

assert s7 init

git checkout -- .

assert test -d Dependencies/ReaddleLib
