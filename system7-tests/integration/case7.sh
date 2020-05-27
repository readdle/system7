#!/bin/sh

mkdir -p "$S7_TESTS_DIR/case7"

function s7status {
    local ACTUAL="$S7_TESTS_DIR/case7/$1.actual"
    local ETALON="$S7_TESTS_DIR/case7/$1.etalon"

    echo
    echo "status $1:"
    echo "#"
    assert s7 stat | tee $ACTUAL
    echo "#"

    if [ ! -f "$ETALON" ]
    then
        mv "$ACTUAL" "$ETALON"
    else
        cmp "$ACTUAL" "$ETALON"
        if [ $? -ne 0 ]
        then
            echo "🚨 unexpected status output"
            echo
            echo "etalon output:"
            cat "$ETALON"
            echo
            echo "actual output:"
            cat "$ACTUAL"
            echo
            echo "diff:"
            diff "$ACTUAL" "$ETALON"
            echo

            touch "${S7_ROOT}/FAIL"
            exit 1
        fi
    fi
}

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

s7status initial

assert s7 add --stage Dependencies/ReaddleLib "$S7_ROOT/github/ReaddleLib"

s7status after_add

assert git commit -m '"add ReaddleLib subrepo"'

s7status subrepo_add_committed

assert test -d Dependencies/ReaddleLib

pushd Dependencies/ReaddleLib > /dev/null
  echo "sqrt" > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
  FIRST_READDLE_LIB_COMMIT=`git rev-parse HEAD`
popd > /dev/null

s7status commit_in_subrepo

assert s7 rebind --stage

cat .s7substate

pushd Dependencies/ReaddleLib > /dev/null
  echo "matrix" >> RDMath.h
  git commit -am"the matrix"

  echo "matrix II" >> RDMath.h
popd > /dev/null

s7status rebind_another_commit_and_uncommitted_changes

assert git commit -m '"up ReaddleLib"'

s7status commit_rebound_changes

pushd Dependencies/ReaddleLib > /dev/null
  git checkout -- .
  git checkout "$FIRST_READDLE_LIB_COMMIT"
popd > /dev/null

s7status detached_head

s7 rm Dependencies/ReaddleLib

s7status remove_subrepo
