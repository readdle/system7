#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

LARGE_FILE_CONTENT="MEGA-LONG-FILE-CONTENT"
echo "$LARGE_FILE_CONTENT" > large-file
assert git lfs track large-file

assert git add large-file .gitattributes

git commit -m"\"track large file with Git LFS\""

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'
git commit -m"add pdfkit subrepo"

grep "s7" .git/hooks/pre-push
assert test 0 -eq $?

grep "lfs" .git/hooks/pre-push
assert test 0 -eq $?

assert test "2" = "$(grep -c '<"$REFS"' .git/hooks/pre-push)"

git push

cd "$S7_ROOT/nik"

git clone "$S7_ROOT/github/rd2"
assert test $? -eq 0

cd rd2

grep "s7" .git/hooks/post-checkout
assert test 0 -eq $?

grep -q "lfs" .git/hooks/post-checkout
assert test 0 -eq $?

assert test "$(cat large-file)" = "$LARGE_FILE_CONTENT"
assert test -f Dependencies/RDPDFKit/.gitignore


mkdir etalon-lfs-repo
pushd etalon-lfs-repo > /dev/null
    git init
    git lfs install
popd > /dev/null

for ETALON_HOOK in etalon-lfs-repo/.git/hooks/*; do
    if grep -i "lfs" $ETALON_HOOK; then
        HOOK_NAME="$(basename $ETALON_HOOK)"
        NIKS_HOOK=".git/hooks/$HOOK_NAME"
        if [ "$(sed -n 's/ <&0//; s/ <"$REFS"//; /lfs/p;1p' $NIKS_HOOK)" != "$(cat $ETALON_HOOK)" ]; then
            echo "LFS hooks hardcoded in S7 code are outdated!"
            echo "Expected format:"
            echo
            cat $ETALON_HOOK
            echo
            echo "Actual format:"
            echo
            sed -n '/lfs/p' $NIKS_HOOK
            echo

            assert false
        fi
    fi
done
