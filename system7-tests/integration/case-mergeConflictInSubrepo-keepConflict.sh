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

# Update existing ReaddleLib subrepo
assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

# Add new subrepo
assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'
assert test -d Dependencies/RDPDFKit
assert git commit -m '"add RDPDFKit subrepo"'

echo
git checkout main

pushd Dependencies/ReaddleLib > /dev/null
  echo main > RDMath.h
  git commit -am"changes at main in ReaddleLib"
popd > /dev/null

# Update existing ReaddleLib subrepo in another branch
# to trigger a merge conflict in .s7substate
assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

echo
echo
S7_MERGE_DRIVER_RESPONSE="m" git merge --no-edit experiment
assert test 1 -eq $?

echo
echo "resulting .s7substate:"
cat .s7substate
echo

assert grep '"<<<"' .s7substate > /dev/null # must be a conflict marker in .s7substate
assert test -d Dependencies/ReaddleLib # subrepo must be present in conflict state
assert test -d Dependencies/RDPDFKit # new subrepo must be checked out
