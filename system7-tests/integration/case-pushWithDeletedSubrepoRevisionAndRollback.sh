#!/bin/sh

cd "$S7_ROOT"

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
git commit -m"add subrepos"

pushd Dependencies/ReaddleLib > /dev/null
  ORIGINAL_COMMIT_IN_READDLE_LIB=$(git rev-parse --short HEAD)

  echo "mult" > RDMath.h
  git add RDMath.h
  git commit -m"mult"
popd > /dev/null

assert s7 rebind --stage
git commit -m"up ReaddleLib"

assert git push

# by a coincidense, make some bad commit in a subrepo and rebind it

pushd Dependencies/ReaddleLib > /dev/null
  echo "ooops" > RDMath.h
  git add RDMath.h
  git commit -m"bad commit"
popd > /dev/null

assert s7 rebind --stage
git commit -m"up ReaddleLib (with bad commit)"

# decide to burry the bad commit and rollback to an even older state of subrepo

pushd Dependencies/ReaddleLib > /dev/null
  git checkout -B main $ORIGINAL_COMMIT_IN_READDLE_LIB
popd > /dev/null

assert s7 rebind --stage
git commit -m"up ReaddleLib (rollback)"

assert git push

