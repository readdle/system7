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
  git commit -am"experiment in ReaddleLib"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'


echo
git checkout master

pushd Dependencies/ReaddleLib > /dev/null
  echo master > RDMath.h
  git commit -am"changes at master in ReaddleLib"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

echo
echo
echo R | git merge experiment
assert test 0 -eq $?

echo
echo "resulting .s7substate:"
cat .s7substate
echo

assert test experiment = `cat Dependencies/ReaddleLib/RDMath.h`
grep '"<<<"' .s7substate > /dev/null
assert test 0 -ne $? # must be no conflict marker in .s7substate
