#!/bin/sh

assert git init -q --bare '"$S7_ROOT/github/FormCalc"'
git clone -q "$S7_ROOT/github/FormCalc" tmp
pushd tmp
    touch .gitignore
    git add .gitignore
    git commit -m"add .gitignore to make repo non-empty"
    git push
popd
rm -rf tmp


assert git clone github/rdpdfkit pastey/rdpdfkit

cd pastey/rdpdfkit

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/FormCalc '"$S7_ROOT/github/FormCalc"'
assert git commit -m '"add FormCalc subrepo"'

pushd Dependencies/FormCalc > /dev/null
  echo AST > Parser.c
  git add Parser.c
  git commit -m"parser"
popd > /dev/null

assert s7 rebind --stage

assert git commit -m '"up FormCalc"'

assert git push --all

echo
echo
echo

cd "$S7_ROOT"

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'

assert test -d Dependencies/RDPDFKit/Dependencies/FormCalc
assert test AST = `cat Dependencies/RDPDFKit/Dependencies/FormCalc/Parser.c`

git commit -m"add pdfkit subrepo"
git push


cd "$S7_ROOT"

git clone github/rd2 nik/rd2

cd nik/rd2

assert test ! -d Dependencies

assert s7 init

assert test -d Dependencies/RDPDFKit/Dependencies/FormCalc
assert test AST = `cat Dependencies/RDPDFKit/Dependencies/FormCalc/Parser.c`

pushd Dependencies/RDPDFKit/Dependencies/FormCalc > /dev/null
  echo xUnit > Tests.c
  git add Tests.c
  git commit -m"tests"
popd > /dev/null

pushd Dependencies/RDPDFKit > /dev/null
  assert s7 rebind --stage
  git commit -m"up FormCalc"
popd > /dev/null

assert s7 rebind --stage
git commit -m"up RDPDFKit"

git push


echo
echo
echo

cd "$S7_ROOT/pastey/rd2"

git pull

assert test xUnit = `cat Dependencies/RDPDFKit/Dependencies/FormCalc/Tests.c`
