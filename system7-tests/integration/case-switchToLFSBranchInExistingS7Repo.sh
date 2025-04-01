#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

#COMMIT_WITHOUT_S7="$(git rev-parse HEAD)"

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'
git commit -m"add pdfkit subrepo"

git push

#COMMIT_WITH_S7="$(git rev-parse HEAD)"

cd "$S7_ROOT/nik"

assert git clone "$S7_ROOT/github/rd2"

cd rd2

grep "s7" .git/hooks/post-checkout
assert test 0 -eq $?
assert test -f Dependencies/RDPDFKit/.gitignore


cd "$S7_ROOT/pastey/rd2"

assert git checkout -b git-lfs

assert git lfs install --force
assert s7 init

LARGE_FILE_CONTENT="MEGA-LONG-FILE-CONTENT"
echo "$LARGE_FILE_CONTENT" > large-file
assert git lfs track large-file
assert git add large-file

git add .
git commit -m"\"track large file with Git LFS\""

grep "s7" .git/hooks/post-checkout
assert test 0 -eq $?
grep -i "lfs" .git/hooks/post-checkout
assert test 0 -eq $?

git push origin -u HEAD


cd "$S7_ROOT/nik/rd2"

PRE_LFS_COMMIT="$(git rev-parse HEAD)"

assert git fetch

assert git switch git-lfs

grep "s7" .git/hooks/post-checkout
assert test 0 -eq $?
grep -i "lfs" .git/hooks/post-checkout
assert test 0 -eq $?

assert test -f large-file
assert test "$(cat large-file)" = "$LARGE_FILE_CONTENT"

git checkout "$PRE_LFS_COMMIT"

grep "s7" .git/hooks/post-checkout
assert test 0 -eq $?
grep -i "lfs" .git/hooks/post-checkout
assert test 0 -eq $?

git switch -

grep "s7" .git/hooks/post-checkout
assert test 0 -eq $?
grep -i "lfs" .git/hooks/post-checkout
assert test 0 -eq $?

assert test -f large-file
assert test "$(cat large-file)" = "$LARGE_FILE_CONTENT"
