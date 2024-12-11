#!/bin/sh

assert git init -q --bare '"$S7_ROOT/github/RDGeometry"'
git clone -q "$S7_ROOT/github/RDGeometry" tmp
pushd tmp
    touch .gitignore
    git add .gitignore
    git commit -m"add .gitignore to make repo non-empty"
    git push
popd
rm -rf tmp

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

assert s7 add --stage Dependencies/RDGeometry '"$S7_ROOT/github/RDGeometry"'

pushd Dependencies/RDGeometry > /dev/null
  echo RDPoint > RDPoint.h
  git add RDPoint.h
  git commit -m"add RDPoint.h"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"add RDGeometry subrepo"'

echo
git checkout -b experiment

# Update existing ReaddleLib subrepo
pushd Dependencies/ReaddleLib > /dev/null
  echo experiment > RDMath.h
  git commit -am"experiment in ReaddleLib"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

# Update existing RDGeometry subrepo
pushd Dependencies/RDGeometry > /dev/null
  echo experiment > RDPoint.h
  git commit -am"experiment in RDGeometry"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up RDGeometry"'

RDGEOMETRY_REVISION=$(git -C Dependencies/RDGeometry rev-parse HEAD)

# Add new subrepo
assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'
assert test -d Dependencies/RDPDFKit
assert git commit -m '"add RDPDFKit subrepo"'

RDPDFKIT_REVISION=$(git -C Dependencies/RDPDFKit rev-parse HEAD)

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

# ReaddleLib subrepo must exist and be in a conflict state
assert test -d Dependencies/ReaddleLib
assert test -f Dependencies/ReaddleLib/.git/MERGE_HEAD
assert grep '"<<<"' Dependencies/ReaddleLib/RDMath.h > /dev/null

# RDGeometry must be updated to the latest revision
assert test $(git -C Dependencies/RDGeometry rev-parse HEAD) = $RDGEOMETRY_REVISION

# RDPDFKit subrepo must exist and been checked out to the latest revision
assert test -d Dependencies/RDPDFKit
assert test $(git -C Dependencies/RDPDFKit rev-parse HEAD) = $RDPDFKIT_REVISION
