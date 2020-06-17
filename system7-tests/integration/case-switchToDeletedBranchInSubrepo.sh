#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib "$S7_ROOT/github/ReaddleLib"
assert git commit -m '"add ReaddleLib subrepo"'


pushd Dependencies/ReaddleLib > /dev/null
  git checkout -b test
  echo "test" > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.hs"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib to test branch"'

INTERESTING_COMMIT=`git rev-parse HEAD`

pushd Dependencies/ReaddleLib > /dev/null
  git switch master

  echo "master" > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h (master)"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"switch ReaddleLib back to master branch"'

pushd Dependencies/ReaddleLib > /dev/null
  git branch -D test
popd > /dev/null

git checkout $INTERESTING_COMMIT

pushd Dependencies/ReaddleLib > /dev/null
  assert test "test" = `git rev-parse --abbrev-ref HEAD`
popd > /dev/null

git switch master

git push

pushd "$S7_ROOT/github/ReaddleLib" > /dev/null
  echo
  echo "branches at remote (1):"
# it's OK to push 'test' branch in this scenario. It's been mentioned in .s7substate,
# so it must be pushed.
# User can make kaka then – remove a branch and s7 will suck the dick...
  git branch --list | grep "test"
  assert test 0 -eq $?
  echo
  echo
popd > /dev/null


pushd Dependencies/ReaddleLib > /dev/null
  echo "master 2" >> RDMath.h
  git add RDMath.h
  git commit -m"up RDMath.h"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

pushd Dependencies/ReaddleLib > /dev/null
  git branch -D test
  assert git push origin --delete test
popd > /dev/null


assert false


pushd "$S7_ROOT/github/ReaddleLib" > /dev/null
  echo
  echo "branches at remote (2):"
# I've just deleted 'test' branch everywhere
  git branch --list | grep "test"
  assert test 0 -ne $?
  echo
  echo
popd > /dev/null


# this resurrects 'test' branch locally
git checkout $INTERESTING_COMMIT

git switch master

assert git push

pushd "$S7_ROOT/github/ReaddleLib" > /dev/null
  echo
  echo "branches at remote (3):"
# we deleted 'test' branch before: both locally and remotely
# then it was resurrected locally by checkout of an old revision where it existed
# user made some real changes at 'master' branch and ment to push just it.
  git branch --list | grep "test"
  assert test 0 -ne $?
  echo
  echo
popd > /dev/null
