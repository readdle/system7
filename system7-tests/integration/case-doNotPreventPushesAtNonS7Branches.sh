#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

git checkout -b pre-s7-branch

touch NewFeature.m
git add .
git commit -m"start new feature development"


git switch master

assert s7 init
assert git add .
assert git commit -m "\"init s7\""



git switch pre-s7-branch

echo WIP >> NewFeature.m
git add .
assert git commit -m'"WIP"'


assert git push -u origin pre-s7-branch
