#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m "\"init s7\""

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'

pushd Dependencies/ReaddleLib > /dev/null
  echo sqrt > RDMath.h
  git add RDMath.h
  git commit -m"add RDMath.h"
popd > /dev/null

assert s7 rebind --stage

echo main > main.m
git add main.m

assert git commit -am '"add ReaddleLib subrepo"'


echo
git checkout -b experiment

echo experiment > main.m

pushd Dependencies/ReaddleLib > /dev/null
  echo experiment >> RDMath.h
  git commit -am"experiment in ReaddleLib"
popd > /dev/null

assert s7 rebind --stage
assert git commit -am '"up ReaddleLib"'


echo
git checkout main

echo other > main.m

assert git commit -am '"change main.m logic"'

echo
echo
git merge experiment
assert test 0 -ne $?

cat Dependencies/ReaddleLib/RDMath.h

# this merge ended up with conflict in main.m
# as no hooks were run, subrepos were not updated properly

cmp .s7substate .s7control
assert test 0 -ne $? # subrepos not in sync
assert test sqrt = `cat Dependencies/ReaddleLib/RDMath.h`

grep '"experiment"' Dependencies/ReaddleLib/RDMath.h > /dev/null
assert test 0 -ne $? # subrepo was not updated, thus doesn't contain 'experiment'

echo
echo "resolve conflict in favour of our changes"

echo other > main.m
git add main.m
assert git commit -am'"finalize merge"'

# now ReaddleLib must be up-to-date
assert cmp .s7substate .s7control # now, must be in sync
assert grep '"experiment"' Dependencies/ReaddleLib/RDMath.h > /dev/null
