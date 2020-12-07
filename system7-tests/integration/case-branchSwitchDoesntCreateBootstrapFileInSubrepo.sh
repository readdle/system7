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

assert s7 init --no-bootstrap # immitate an old behaviour when there was no bootstrap
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

assert git push

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

pushd Dependencies/RDPDFKit > /dev/null
  assert test ! -f .s7bootstrap
  assert test -z $(git status --porcelain)
popd > /dev/null


echo
echo
echo

git checkout -b experiment

s7 co

pushd Dependencies/RDPDFKit > /dev/null
  assert test ! -f .s7bootstrap
  assert test -z $(git status --porcelain)
popd > /dev/null

# immitate bootstrap infection
pushd Dependencies/RDPDFKit > /dev/null
  s7 init # decide to install bootstrap in RDPDFKit
  git add .
  git commit -m"add bootstrap"
  assert test -f .s7bootstrap
popd > /dev/null

s7 rebind --stage
git commit -m"up PDFKit"


echo
echo
echo


git switch master

pushd Dependencies/RDPDFKit > /dev/null
  assert test ! -f .s7bootstrap
  assert test -z $(git status --porcelain)
popd > /dev/null


git switch experiment

pushd Dependencies/RDPDFKit > /dev/null
  assert test -f .s7bootstrap
  assert test -z $(git status --porcelain)
  grep "s7 init" < .git/hooks/post-checkout
  assert test 0 -ne $? # post-checkout must not contain 's7 init'
popd > /dev/null


git switch master

pushd Dependencies/RDPDFKit > /dev/null
  assert test ! -f .s7bootstrap
  assert test -z $(git status --porcelain)
popd > /dev/null
