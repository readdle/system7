#!/bin/sh

assert git clone github/rd2 rd2
cd rd2

assert s7 init
assert git add .
assert git commit -m \"init s7\"
ROOT_REVISION=$(git rev-parse HEAD)

MASTER_READDLE_LIB_DIR="Dependencies/ReaddleLib"
assert s7 add --stage "$MASTER_READDLE_LIB_DIR" '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'
assert test -d Dependencies/ReaddleLib

assert git checkout $ROOT_REVISION
git checkout -b feature

FEATURE_READDLE_LIB_DIR="Libraries/ReaddleLib"
assert s7 add --stage "$FEATURE_READDLE_LIB_DIR" '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'
assert test -d Libraries/ReaddleLib

STILL_ALIVE_ATTRIBUTE=still_alive
STILL_ALIVE_VALUE=$(uuidgen)
xattr -w $STILL_ALIVE_ATTRIBUTE $STILL_ALIVE_VALUE "$FEATURE_READDLE_LIB_DIR"

git checkout master
assert test $(xattr -p $STILL_ALIVE_ATTRIBUTE "$MASTER_READDLE_LIB_DIR") = $STILL_ALIVE_VALUE

git checkout feature
assert test $(xattr -p $STILL_ALIVE_ATTRIBUTE "$FEATURE_READDLE_LIB_DIR") = $STILL_ALIVE_VALUE
