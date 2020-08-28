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


cd "$S7_ROOT"

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'

git commit -m"add pdfkit subrepo"

assert git push



cd "$S7_ROOT"

git clone github/rd2 vasya/rd2

cd vasya/rd2

assert s7 init



cd "$S7_ROOT/pastey/rd2"
cd Dependencies/RDPDFKit

assert s7 init
assert s7 add --stage Dependencies/FormCalc '"$S7_ROOT/github/FormCalc"'
assert git commit -m '"add FormCalc subrepo"'

cd ../..
assert s7 rebind --stage
assert git commit -m '"up RDPDFKit subrepo"'

assert git push


cd "$S7_ROOT/vasya/rd2"

echo "vasya start 🎬"

git pull

assert test -d Dependencies/RDPDFKit/Dependencies/FormCalc
