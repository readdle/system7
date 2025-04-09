#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

LARGE_FILE_CONTENT="MEGA-LONG-FILE-CONTENT"
echo "$LARGE_FILE_CONTENT" > large-file
assert git lfs track large-file

assert git add large-file .gitattributes
git commit -m"\"track large file with Git LFS\""

git push


cd "$S7_ROOT/nik/rd2"

assert git pull

assert test -f large-file
assert test "$(cat large-file)" = "$LARGE_FILE_CONTENT"
