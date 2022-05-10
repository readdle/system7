#!/bin/sh

git init -q --bare "$S7_ROOT/github/FormCalc"
git clone -q "$S7_ROOT/github/FormCalc" tmp
pushd tmp
    echo "AST" > AST.m
    git add AST.m
    git commit -m"AST"
    git push
popd
rm -rf tmp


git clone github/rdpdfkit pastey/rdpdfkit

pushd pastey/rdpdfkit > /dev/null
    assert s7 init
    assert git add .
    assert git commit -m "\"init s7\""

    assert s7 add --stage Dependencies/FormCalc '"$S7_ROOT/github/FormCalc"'
    assert git commit -m '"add FormCalc subrepo"'

    assert git push --all
popd > /dev/null


git clone github/rd2 pastey/rd2

pushd pastey/rd2 > /dev/null
    assert s7 init
    assert git add .
    assert git commit -m "\"init s7\""

    assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"' master

    assert test -d Dependencies/RDPDFKit/Dependencies/FormCalc

    git commit -m"add PDFKit subrepo"

    git checkout -b feature/ast-optimization

    pushd Dependencies/RDPDFKit > /dev/null
        git checkout -b feature/ast-optimization

        pushd Dependencies/FormCalc > /dev/null
            git checkout -b feature/ast-optimization

            echo "optimization" >> AST.m
            git add AST.m
            git commit -m"AST optimization"
        popd > /dev/null

        s7 rebind --stage
        git commit -m"up FormCalc"
    popd > /dev/null

    s7 rebind --stage
    git commit -m"up PDFKit"


    git switch master

    pushd Dependencies/RDPDFKit > /dev/null
        pushd Dependencies/FormCalc > /dev/null
            echo "bugfix" >> AST.m
            git add AST.m
            git commit -m"AST bugfix"
        popd > /dev/null

        s7 rebind --stage
        git commit -m"up FormCalc"
    popd > /dev/null

    s7 rebind --stage
    git commit -m"up PDFKit"

    # Not asserting anything here
    # just checking that this doesn't hang.
    # See comment in Git.m -mergeWith: for more info
    export S7_MERGE_DRIVER_RESPONSE="m"
    git merge feature/ast-optimization
popd > /dev/null
