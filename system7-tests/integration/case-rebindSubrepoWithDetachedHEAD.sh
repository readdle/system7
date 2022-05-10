#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'

pushd Dependencies/ReaddleLib > /dev/null
  echo "sqrt" > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
  FIRST_READDLE_LIB_COMMIT=`git rev-parse HEAD`

  echo "matrix" >> RDMath.h
  git commit -am"the matrix"

  git checkout "$FIRST_READDLE_LIB_COMMIT"
popd > /dev/null

s7 rebind

assert test $? -ne 0
