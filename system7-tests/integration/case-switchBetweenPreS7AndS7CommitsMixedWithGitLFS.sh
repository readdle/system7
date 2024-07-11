#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

COMMIT_WITHOUT_S7="$(git rev-parse HEAD)"

cat <<EOT > .git/hooks/post-checkout
#!/bin/sh
echo "Git LFS was here"
EOT

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'

git commit -m"add pdfkit subrepo"

COMMIT_WITH_S7="$(git rev-parse HEAD)"

# switch back to pre-s7 times
git checkout "$COMMIT_WITHOUT_S7"

assert test -z "$(git status --porcelain)"
grep -q "s7" .gitignore
assert test 1 -eq $?
grep -q -i "lfs" .git/hooks/post-checkout
assert test 0 -eq $?
grep "s7" .git/hooks/post-checkout
assert test 1 -eq $?

# to s7 again
git checkout "$COMMIT_WITH_S7"

assert test -z "$(git status --porcelain)"
grep -q "s7" .gitignore
assert test 0 -eq $?
grep -q -i "lfs" .git/hooks/post-checkout
assert test 0 -eq $?
grep "s7" .git/hooks/post-checkout
assert test 0 -eq $?
# bootstrap init must not get stuck on back and forth switches
grep "init" .git/hooks/post-checkout
assert test 1 -eq $?

# and to pre-s7 one more time
git checkout "$COMMIT_WITHOUT_S7"

assert test -z "$(git status --porcelain)"
grep -q "s7" .gitignore
assert test 1 -eq $?
grep -q -i "lfs" .git/hooks/post-checkout
assert test 0 -eq $?
grep "s7" .git/hooks/post-checkout
assert test 1 -eq $?
