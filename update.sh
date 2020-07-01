#!/bin/sh

which git > /dev/null
if [ 0 -ne $? ]
then
    echo "error: failed to locate 'git' command."
    exit 1
fi

# remove from the deprecated install path at ${HOME}/bin/
rm -f "${HOME}/bin/s7" > /dev/null
rm -f "${HOME}/bin/install-s7.sh" > /dev/null
rm -f "${HOME}/bin/update-s7.sh" > /dev/null

FORCE="no"
if [ \( "$1" = "-f" \) -o \( "$1" = "--force" \) ]
then
    FORCE="yes"
fi

SYSTEM7_DIR="${HOME}/.system7"

function re_install() {
    INSTALL_SCRIPT="/usr/local/bin/install-s7.sh"
    if [ -f "$INSTALL_SCRIPT" ]
    then
        sh "$INSTALL_SCRIPT"
    else
        echo "error: failed to update s7. Please re-install it."
        exit 1
    fi
}

function update() {
    if [ ! -d "${SYSTEM7_DIR}" ]
    then
        re_install
        return
    fi

    pushd "${SYSTEM7_DIR}" > /dev/null
        PREVIOUS_REVISION=$(git rev-parse HEAD)

        git checkout master && git pull

        if [ 0 -ne $? ]
        then
            echo "warning: failed to check for s7 updates. The tool is installed, so don't fail the build. But we'll keep trying to check for updates"
            exit 1
        fi

        CURRENT_REVISION=$(git rev-parse HEAD)

        if [ \( "no" = $FORCE \) -a \( "$CURRENT_REVISION" = "$PREVIOUS_REVISION" \) ]
        then
            # avoid heavy buildme.sh if 'git pull' didn't change the revision
            # this script is run during rd2 build, so better for it to be as quick as possible
            return
        fi

        ./buildme.sh
    popd > /dev/null
}

TODAY=$(date "+%Y-%m-%d")
LAST_CHECK_DATE_FILE_PATH="${SYSTEM7_DIR}/.last-s7-update-check-date"

SHOULD_UPDATE="no"
if [ ! -f "/usr/local/bin/s7" ]
then
    echo "failed to locate s7 at your machine. Will install it"

    SHOULD_UPDATE="yes"
    FORCE="yes"
else
    LAST_CHECK_DATE=$(cat "${LAST_CHECK_DATE_FILE_PATH}" 2>/dev/null)
    if [ "$TODAY" != "$LAST_CHECK_DATE" ]
    then
        echo "will check for s7 updates. Last check was performed ${LAST_CHECK_DATE:-NEVER}"

        SHOULD_UPDATE="yes"
    fi
fi

if [ \( "$SHOULD_UPDATE" = "yes" \) -o \( "$FORCE" = "yes" \) ]
then
    update

    echo "$TODAY" > "${LAST_CHECK_DATE_FILE_PATH}"
fi
