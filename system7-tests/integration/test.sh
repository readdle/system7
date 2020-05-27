#!/bin/sh

ORIGINAL_PWD=$PWD
PATH=$PATH:$PWD
export S7_ROOT=$PWD/root
export S7_TESTS_DIR=$ORIGINAL_PWD

#set -x

TESTS_TO_RUN="$@"
if [ -z "$TESTS_TO_RUN" ]
then
    TESTS_TO_RUN=`ls case*.sh`
fi

function setUp {
    cd "$ORIGINAL_PWD"

    if [ -d root ]
    then
        rm -rf root
    fi

    mkdir root

    git init -q --bare root/github/rd2
    git init -q --bare root/github/ReaddleLib

    mkdir -p root/pastey
    mkdir -p root/nik

    cd root
}

function tearDown {
    cd "$ORIGINAL_PWD"
    rm -Rf root 2>/dev/null
}

trap tearDown EXIT

source assertions

ANY_TEST_FAILED=0

for CASE in $TESTS_TO_RUN
do
    setUp

    echo "🎬 running $CASE..."
    echo

    sh "$ORIGINAL_PWD/$CASE"

    echo
    if [ -f "${S7_ROOT}/FAIL" ]
    then
        echo "[❌ FAIL]"
        ANY_TEST_FAILED=1
    else
        echo "[✅ OK]"
    fi

    tearDown

    echo
done

echo
if [ $ANY_TEST_FAILED -eq 1 ]
then
    echo "[❌ TESTS FAILED]"
else
    echo "[✅ SUCCESS]"
fi
