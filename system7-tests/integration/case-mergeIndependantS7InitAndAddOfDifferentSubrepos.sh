#!/bin/sh

cd "$S7_ROOT/nik"

assert git clone '"$S7_ROOT/github/rd2"'

cd rd2

echo asdf > file
git add file
git commit -m"add some stuff"
git push


cd "$S7_ROOT"

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

assert s7 rebind --stage

assert git commit -m '"add ReaddleLib subrepo"'

assert git push

echo



cd "$S7_ROOT/nik/rd2"

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'

pushd Dependencies/RDPDFKit > /dev/null
  echo "parsing" > RDPDFAnnotation.h
  git add RDPDFAnnotation.h
  git commit -m"parsing"
popd > /dev/null

assert s7 rebind --stage

assert git commit -m '"add RDPDFKit subrepo"'

git pull
# git pull fails to merge .gitignore, .s7substate must be OK
assert test 0 -ne $?

grep "<<<" .s7substate > /dev/null
assert test 0 -ne $? # must be no conflict marker in .s7substate

# .gitignore conflicts
assert grep '"<<<"' .gitignore > /dev/null

assert test -d Dependencies/ReaddleLib
assert test sqrt = `cat Dependencies/ReaddleLib/RDMath.h`

assert test -d Dependencies/RDPDFKit
assert test parsing = `cat Dependencies/RDPDFKit/RDPDFAnnotation.h`
