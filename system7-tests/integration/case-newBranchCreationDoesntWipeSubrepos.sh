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

pushd Dependencies/ReaddleLib > /dev/null
  git checkout -b experiment
  echo experiment >> RDMath.h
  git commit -am"experiment"
  SUBREPO_EXPERIMENT_REVISION=$(git rev-parse HEAD)
popd > /dev/null

# made an experiment in subrepo and remembered that you forgot to create a new branch in the main repo
echo
git checkout -b experiment

pushd Dependencies/ReaddleLib > /dev/null
  assert test experiment = $(git branch --show-current)
  assert test $SUBREPO_EXPERIMENT_REVISION = $(git rev-parse HEAD)
popd > /dev/null
