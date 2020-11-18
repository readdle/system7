#!/bin/sh

git clone github/rd2 pastey/rd2

cd pastey/rd2

echo kaka > .git/hooks/pre-push
if s7 init
then
    echo "s7 init must have failed"
    assert false
fi

for COMMAND in stat rebind checkout reset add remove; do
    echo
    echo "try to run 's7 $COMMAND'..."

    if s7 $COMMAND
    then
        echo "s7 stat must have failed"
        assert false
    fi
done
