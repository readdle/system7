#!/bin/sh

cd "$S7_ROOT"

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'
git commit -m"add subrepos"

git push


# nik switches RDPDFKit to a different branch
cd "$S7_ROOT/nik"

git clone "$S7_ROOT/github/rd2"

cd rd2

pushd Dependencies/RDPDFKit > /dev/null
  git checkout -b experiment
  echo "experiment" >> RDPDFAnnotation.h
  git add RDPDFAnnotation.h
  git commit -m"annotation"
popd > /dev/null

assert s7 rebind --stage
git commit -m"up RDPDFKit"

git push


# pastey gets these changes, and thus gets an "annotation" commit in RDPDFKit. Currently known only
# at "experiment" branch
cd "$S7_ROOT/pastey/rd2"
git pull


cd "$S7_ROOT/nik/rd2"

pushd Dependencies/RDPDFKit > /dev/null
  git switch master
  git merge --ff --no-edit experiment
popd > /dev/null

assert s7 rebind --stage
git commit -m"up RDPDFKit"

assert git push



# someone makes some upstream changes in RDPDFKit (maybe even me, but from a different clone)
cd "$S7_ROOT/pastey"
git clone "$S7_ROOT/github/RDPDFKit"
cd RDPDFKit
echo "AP/N" >> RDPDFAnnotation.h
git add RDPDFAnnotation.h
git commit -m"appearance streams"
git push


cd "$S7_ROOT/pastey/rd2"

git pull
git checkout -b new-branch

pushd Dependencies/ReaddleLib > /dev/null
  echo "mult" > RDMath.h
  git add RDMath.h
  git commit -m"mult"
popd > /dev/null

assert s7 rebind --stage
git commit -m"up ReaddleLib"

assert git push origin -u HEAD
