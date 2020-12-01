#!/bin/sh

git clone github/rd2 pastey/rd2

cd "$S7_ROOT/pastey/rd2"

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
  echo "parsing" > RDPDFAnnotation.h
  git add RDPDFAnnotation.h
  git commit -m"parsing"
popd > /dev/null

assert s7 rebind --stage

assert git commit -m '"add subrepos"'

assert git push

echo



cd "$S7_ROOT/nik"

assert git clone '"$S7_ROOT/github/rd2"'

cd rd2

assert test -d Dependencies/RDPDFKit

assert s7 rm Dependencies/RDPDFKit

assert test ! -d Dependencies/RDPDFKit
git add .
git commit -m"drop RDPDFKit subrepo"

git push




cd "$S7_ROOT/pastey/rd2"

git pull

assert test ! -d Dependencies/RDPDFKit
