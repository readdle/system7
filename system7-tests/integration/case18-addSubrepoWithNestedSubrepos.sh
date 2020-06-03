#!/bin/sh

assert git init -q --bare "$S7_ROOT/github/FormCalc"
assert git init -q --bare "$S7_ROOT/github/RDPDFKit"

assert git clone github/rdpdfkit pastey/rdpdfkit

cd pastey/rdpdfkit

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/FormCalc "$S7_ROOT/github/FormCalc"
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

assert s7 add --stage Dependencies/RDPDFKit "$S7_ROOT/github/RDPDFKit"

assert test -d Dependencies/RDPDFKit/Dependencies/FormCalc
assert test AST = `cat Dependencies/RDPDFKit/Dependencies/FormCalc/Parser.c`
