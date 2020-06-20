#!/bin/sh

set -xg

#
# for future desperado programmers:
# do not source any other scripts to this file
# this script is downloaded as a single file, that will
# checkout and rollout s7 in the system, thus it cannot
# rely on any surrounding scripts.
# (that's why it contains a tiny bit of copy-paste)

which git > /dev/null
if [ 0 -ne $? ]
then
    echo "error: failed to locate 'git' command."
    exit 1
fi

SYSTEM7_DIR="${HOME}/.system7"

function bootstrap() {
    rm -rf "${SYSTEM7_DIR}" > /dev/null

    git clone -b dev git@github.com:readdle/system7.git "${SYSTEM7_DIR}"
    if [ 0 -ne $? ]
    then
        echo "error: failed to clone System 7 repo. Check connection or VPN setup. Check if SSH is configured properly."
        exit 1
    fi

    pushd "${SYSTEM7_DIR}" > /dev/null
        mkdir -p "${HOME}/bin"
        cp bootstrap.sh "${HOME}/bin/install-s7.sh"
        cp update.sh "${HOME}/bin/update-s7.sh"

        sh "${HOME}/bin/update-s7.sh"
    popd > /dev/null
}

bootstrap
