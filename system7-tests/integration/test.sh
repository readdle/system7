#!/bin/sh

if [ -n "${BASH_VERSION}" ]; then
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION}" ]; then
    SCRIPT_SOURCE="${(%):-%N}"
else
    echo >&2 "failed to deduce the shell you are using"
    exit $LINENO
fi

SCRIPT_SOURCE_DIR="$( cd "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"

# make sure we do everything in the proper directory
cd "$SCRIPT_SOURCE_DIR"


PARALLELIZE=1
if [ ! -z "$1" ]
then
    if [ $1 = "--no-parallel" ]
    then
        shift
        PARALLELIZE=0
    fi
fi

export S7_TESTS_DIR="$SCRIPT_SOURCE_DIR"

TESTS_TO_RUN="$@"
if [ -z "$TESTS_TO_RUN" ]
then
    TESTS_TO_RUN=`ls case*.sh`
fi

prepareTemplateRepos() {
    git init -q --bare templates/rd2
    git init -q --bare templates/ReaddleLib
    git init -q --bare templates/RDPDFKit

    for d in templates/*
    do
        git clone -q $d tmp
        pushd tmp
            touch .gitignore
            git add .gitignore
            git commit -m"add .gitignore to make repo non-empty"
            git push
        popd
        rm -rf tmp
    done > /dev/null 2>&1
}

cleanup() {
    rm -f "${SANDBOX_DIR}/failed-cases"
    rm -rf "${SCRIPT_SOURCE_DIR}/templates"
}

prepareSandboxDirectory() {
    SANDBOX_DIR="${SCRIPT_SOURCE_DIR}/sandbox"
    rm -rf "$SANDBOX_DIR"
    mkdir "$SANDBOX_DIR"
}

trap cleanup EXIT

cleanup
prepareTemplateRepos
prepareSandboxDirectory

source assertions
source utils

red=$(tput setaf 1)
green=$(tput setaf 2)
normal=$(tput sgr0)

setupAndRunCase() {
    local CASE=$1

    local TEST_ROOT="$SANDBOX_DIR/$CASE"

    mkdir -p "$TEST_ROOT"
    mkdir -p "$TEST_ROOT/github"
    mkdir -p "$TEST_ROOT/pastey"
    mkdir -p "$TEST_ROOT/nik"

    cp -Rc "$SCRIPT_SOURCE_DIR/templates/rd2" "$TEST_ROOT/github"
    cp -Rc "$SCRIPT_SOURCE_DIR/templates/ReaddleLib" "$TEST_ROOT/github"
    cp -Rc "$SCRIPT_SOURCE_DIR/templates/RDPDFKit" "$TEST_ROOT/github"

    cd "$TEST_ROOT"

    if [ 1 -eq $PARALLELIZE ]; then
        S7_ROOT="$TEST_ROOT" sh -x "$SCRIPT_SOURCE_DIR/$CASE" >"$TEST_ROOT/log.txt" 2>&1
    else
        S7_ROOT="$TEST_ROOT" sh -x "$SCRIPT_SOURCE_DIR/$CASE" 2>&1
    fi

    if [ -f "$TEST_ROOT/FAIL" ]; then
        printf "${red}x${normal}"
    else
        printf "${green}v${normal}"
    fi
}

for CASE in $TESTS_TO_RUN; do
    printf "="
done

echo

for CASE in $TESTS_TO_RUN
do
    if [ 1 -eq $PARALLELIZE ]; then
        setupAndRunCase $CASE &
    else
        setupAndRunCase $CASE
    fi
done

if [ 1 -eq $PARALLELIZE ]; then
    wait

    echo
    echo
fi

ANY_TEST_FAILED=0

for CASE in $TESTS_TO_RUN
do
    if [ -f "$SANDBOX_DIR/$CASE/FAIL" ]; then
        echo "$CASE" >> "${SANDBOX_DIR}/failed-cases"
        ANY_TEST_FAILED=1
    fi
done

if [ $ANY_TEST_FAILED -eq 1 ]
then
    echo "[🚨🚨🚨]"
    echo
    echo "The following tests failed:"
    cat "${SANDBOX_DIR}/failed-cases" | sed 's/^/    /'
    echo
    echo "[❌ TESTS FAILED]"

    exit 1
else
    echo "[✅ SUCCESS]"
fi
