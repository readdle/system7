#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib "$S7_ROOT/github/ReaddleLib"
pushd Dependencies/ReaddleLib > /dev/null
  echo sqrt > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"add ReaddleLib subrepo"'


pushd Dependencies/ReaddleLib > /dev/null
  echo matrix > RDMath.h
  git commit -am"add RDMath.h"
popd > /dev/null

assert s7 rebind

assert git checkout -- .s7substate
assert test sqrt = `cat Dependencies/ReaddleLib/RDMath.h`

if isGitVersionGreaterThan2_23
then
    echo
    echo
    echo "modern git"
    pushd Dependencies/ReaddleLib > /dev/null
      echo matrix > RDMath.h
      git commit -am"add RDMath.h"
    popd > /dev/null

    assert s7 rebind

    assert git restore -- .s7substate
    assert test sqrt = `cat Dependencies/ReaddleLib/RDMath.h`
fi
