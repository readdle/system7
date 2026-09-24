#!/bin/sh

# When pushing a brand new branch, git tells the pre-push hook nothing about the remote
# revision to compare against. Historically we fell back to inspecting *all* subrepos
# referenced in .s7substate. Since Git 2.47 the hook uses git's `is-base` heuristic to
# detect the branch this one starts from, so only the subrepos actually changed on the
# new branch are checked.
#
# `is-base` is not available before Git 2.47. On older git the hook silently falls back
# to the broad check (still correct, just less precise), so there's nothing to assert –
# we simply pass.
if ! isGitVersionAtLeast 2.47
then
    echo "git is older than 2.47 – 'is-base' is not available, nothing to test here"
    exit 0
fi

cd "$S7_ROOT"

PUSH_LOG="$S7_ROOT/push-output.txt"

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

# add two subrepos on 'main' and push everything
assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
pushd Dependencies/ReaddleLib > /dev/null
  echo sqrt > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
popd > /dev/null

assert s7 add --stage Dependencies/RDPDFKit '"$S7_ROOT/github/RDPDFKit"'
pushd Dependencies/RDPDFKit > /dev/null
  echo annotations > RDPDFAnnotation.h
  git add RDPDFAnnotation.h
  git commit -m"annotations"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"add subrepos"'
assert git push


# create a new branch and change ONLY ReaddleLib
git checkout -b experiment

pushd Dependencies/ReaddleLib > /dev/null
  echo "matrix" >> RDMath.h
  git commit -am"matrices"
popd > /dev/null

assert s7 rebind --stage
assert git commit -m '"up ReaddleLib"'

# an unrelated, NOT rebound change in RDPDFKit – it must never be pushed
pushd Dependencies/RDPDFKit > /dev/null
  echo "unrelated" >> RDPDFAnnotation.h
  git commit -am"unrelated bugfix"
popd > /dev/null


# push the new branch, capturing the pre-push hook output
git push origin -u HEAD > "$PUSH_LOG" 2>&1
assert test 0 -eq $?

echo "--- pre-push hook output ---"
cat "$PUSH_LOG"
echo "----------------------------"

# 1. the hook must have detected the branch start point via `is-base`
grep -q "detected branch start point" "$PUSH_LOG"
assert test 0 -eq $?

# 2. having found the start point, the hook must have narrowed the check down to the only
#    subrepo changed on 'experiment' (ReaddleLib), and must not even look at RDPDFKit
grep -q "checking 'Dependencies/ReaddleLib'" "$PUSH_LOG"
assert test 0 -eq $?

grep -q "checking 'Dependencies/RDPDFKit'" "$PUSH_LOG"
assert test 0 -ne $?

# 3. and, naturally, the unrelated not-rebound RDPDFKit commit must not have been pushed
pushd "$S7_ROOT/github/RDPDFKit" > /dev/null
  git log --oneline | grep "unrelated bugfix"
  assert test 0 -ne $?
popd > /dev/null

rm -f "$PUSH_LOG"
