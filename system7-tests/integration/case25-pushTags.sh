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
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

assert git push

pushd Dependencies/ReaddleLib > /dev/null
  echo "matrix" >> RDMath.h
  git commit -am"matrices"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

git tag v1

assert git push origin v1



cd "$S7_ROOT/nik"

assert git clone '"$S7_ROOT/github/rd2"'

cd rd2

# just a tag v1 was pushed, so no 'matrix' should be available at the moment
grep '"matrix"' Dependencies/ReaddleLib/RDMath.h > /dev/null
assert test 0 -ne $?


pushd "$S7_ROOT/pastey/rd2" > /dev/null
    git push
popd > /dev/null



pushd "$S7_ROOT/nik/rd2" > /dev/null
    git pull

    # now, subrepo must contain 'matrix'
    assert grep '"matrix"' Dependencies/ReaddleLib/RDMath.h > /dev/null
popd > /dev/null
