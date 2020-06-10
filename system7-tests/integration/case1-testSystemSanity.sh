#!/bin/sh

# just a sanity check of test system itself
assert test -d pastey
assert test -d nik
assert test -d github
assert test -d github/rd2
assert test -d github/ReaddleLib

assert git clone github/rd2 pastey/rd2
