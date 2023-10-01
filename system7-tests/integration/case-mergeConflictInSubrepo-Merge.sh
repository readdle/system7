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

# test how s7 works with more modern command 'switch'
if isGitVersionGreaterThan2_23
then
    echo "modern Git"
    git switch -c experiment
else
    echo "old Git"
    git checkout -b experiment
fi

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

# first try non-interactive merge "via GUI app"
echo "emulating GUI Git client that doesn't support interactive stdin" |
    git merge --no-edit experiment
assert test 0 -ne $?

echo
echo "resulting .s7substate:"
cat .s7substate
echo

assert grep '"<<<"' .s7substate > /dev/null

assert git merge --abort


echo
echo
S7_MERGE_DRIVER_RESPONSE="m" git merge --no-edit experiment
assert test 0 -ne $?

echo
echo "resulting .s7substate:"
cat .s7substate
echo

assert grep '"<<<"' Dependencies/ReaddleLib/RDMath.h > /dev/null
assert grep '"<<<"' .s7substate > /dev/null


pushd Dependencies/ReaddleLib > /dev/null
  echo "experiment+master" > RDMath.h
  git commit -am"merge"
popd > /dev/null

assert s7 rebind --stage

echo
echo "resulting .s7substate:"
cat .s7substate
echo

assert test "experiment+master" = `cat Dependencies/ReaddleLib/RDMath.h`

grep "Dependencies/ReaddleLib" .s7substate > /dev/null
assert test 0 -eq $? # config must contain 'Dependencies/ReaddleLib'

grep "<<<" .s7substate > /dev/null
assert test 0 -ne $? # must be no conflict marker in .s7substate

assert git commit --no-edit
