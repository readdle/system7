#!/bin/sh

ORIGINAL_PWD=$PWD
PATH=$PATH:$PWD
export S7_ROOT=$PWD/root
export S7_TESTS_DIR=$ORIGINAL_PWD

#set -x

LEAVE_TEST_REPOS_AFTER_FAIL=0
if [ ! -z $1 ]
then
    if [ $1 = "--leave-repos-on-fail" ]
    then
        shift
        LEAVE_TEST_REPOS_AFTER_FAIL=1
    fi
fi

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
    if [ $ANY_TEST_FAILED -eq 1  -a  1 -eq $LEAVE_TEST_REPOS_AFTER_FAIL ]
    then
        exit 1
    fi

    cd "$ORIGINAL_PWD"
    rm -Rf root 2>/dev/null
}

function globalCleanUp {
    rm "${ORIGINAL_PWD}/failed-cases" 2>/dev/null
    tearDown
}

trap globalCleanUp EXIT

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
        echo "$CASE" >> "${ORIGINAL_PWD}/failed-cases"
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
    echo "[🚨🚨🚨]"
    echo
    echo "The following tests failed:"
    cat "${ORIGINAL_PWD}/failed-cases" | sed 's/^/    /'
    echo
    echo "[❌ TESTS FAILED]"
else
    echo "[✅ SUCCESS]"
fi
