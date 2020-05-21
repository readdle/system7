#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

# test double init
assert s7 init
assert s7 init
