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
git checkout -b experiment

pushd Dependencies/ReaddleLib > /dev/null
  echo experiment > RDMath.h
  git commit -am"one more commit at master in ReaddleLib"
popd > /dev/null

s7 rebind --stage Dependencies/ReaddleLib

git commit -m"experiment"

echo

git checkout master 2>&1 | tee checkout-output

grep "not connected" < checkout-output > /dev/null
if [ 0 -ne $? ]; then
    echo "s7 didn't warn user about detached commits in subrepo"
    assert false
fi
rm checkout-output

grep "ReaddleLib" < .s7bak > /dev/null
if [ 0 -ne $? ]; then
    echo "s7 didn't save detached commits to .s7bak"
    assert false
fi

assert test sqrt = `cat Dependencies/ReaddleLib/RDMath.h`
