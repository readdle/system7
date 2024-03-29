#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'

pushd Dependencies/ReaddleLib > /dev/null
  echo matrix > RDMath.h
  git add RDMath.h
  git commit -m"the matrix"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'


git checkout -b release/documents-7.2.4

pushd Dependencies/ReaddleLib > /dev/null
  echo sqrt > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'


git switch main

echo
echo
echo cherry-pick

assert git cherry-pick release/documents-7.2.4

assert test sqrt = `cat Dependencies/ReaddleLib/RDMath.h`
