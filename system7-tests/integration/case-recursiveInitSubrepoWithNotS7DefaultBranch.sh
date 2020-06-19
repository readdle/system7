#!/bin/sh

git init -q --bare "$S7_ROOT/github/FormCalc"
git clone -q "$S7_ROOT/github/FormCalc" tmp
pushd tmp
    touch .gitignore
    git add .gitignore
    git commit -m"add .gitignore to make repo non-empty"
    git push
popd
rm -rf tmp


git clone github/rdpdfkit pastey/rdpdfkit

pushd pastey/rdpdfkit > /dev/null
    INITIAL_COMMIT=`git rev-parse HEAD`

    git checkout -b pirate-bay

    touch ship
    git add ship
    git commit -m"ar-ar"


    git switch master

    assert s7 init
    assert git add .
    assert git commit -m "\"init s7\""

    assert s7 add --stage Dependencies/FormCalc '"$S7_ROOT/github/FormCalc"'
    assert git commit -m '"add FormCalc subrepo"'

    assert git push --all
popd > /dev/null


pushd github/rdpdfkit > /dev/null
    assert git symbolic-ref HEAD refs/heads/pirate-bay
popd > /dev/null


git clone github/rdpdfkit test-rdpdfkit

pushd test-rdpdfkit > /dev/null
    assert test pirate-bay = `git rev-parse --abbrev-ref HEAD`
popd > /dev/null

git clone github/rd2 pastey/rd2

pushd pastey/rd2 > /dev/null
    assert s7 init
    assert git add .
    assert git commit -m "\"init s7\""

    assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"' master

    assert test -d Dependencies/RDPDFKit/Dependencies/FormCalc

    git commit -m"add PDFKit subrepo"

    assert git push
popd > /dev/null


git clone github/rd2 vasya/rd2
pushd vasya/rd2 > /dev/null
    assert s7 init

    assert test -d Dependencies/RDPDFKit/Dependencies/FormCalc
popd > /dev/null
