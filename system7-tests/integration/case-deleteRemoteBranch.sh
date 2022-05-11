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

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'
pushd Dependencies/RDPDFKit > /dev/null
  echo annotations > RDPDFAnnotation.h
  git add RDPDFAnnotation.h
  git commit -m"annotations"
popd > /dev/null

assert s7 rebind --stage

assert git commit -am '"add subrepos"'

assert git push


echo
echo

git checkout -b experiment

pushd Dependencies/ReaddleLib > /dev/null
  echo matrix >> RDMath.h
  git commit -am"matrices"
popd > /dev/null

assert s7 rebind --stage

git commit -m"up ReaddleLib 1"

assert git push -u origin experiment

pushd Dependencies/ReaddleLib > /dev/null
  echo cosine >> RDMath.h
  git commit -am"cosine"
popd > /dev/null

assert s7 rebind --stage

git commit -m"up ReaddleLib 2"


pushd Dependencies/RDPDFKit > /dev/null
  echo rendering >> RDPDFAnnotation.h
  git commit -am"rendering"
popd > /dev/null


assert git push origin --delete experiment



assert git checkout master

echo asdf > file
git add file
git commit -m"add file"

assert git push

# check that main repo branch delete didn't push any subrepo changes,
# neither rebound and committed, nor not rebound
#
pushd "$S7_ROOT/github/ReaddleLib" > /dev/null
  git log --oneline | grep "cosine"
  assert test 0 -ne $?
popd > /dev/null

pushd "$S7_ROOT/github/RDPDFKit" > /dev/null
  git log --oneline | grep "rendering"
  assert test 0 -ne $?
popd > /dev/null
