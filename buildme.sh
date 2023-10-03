#!/bin/sh

which xcodebuild > /dev/null
if [ 0 -ne $? ]
then
    echo "error: failed to locate 'xcodebuild' command. Do you have Xcode? "
         "Run 'xcode-select -switch-path <path to Xcode.app>' "
         "(most common path to Xcode.app is '/Applications/Xcode.app'."
    exit 1
fi

# If you are like me, and didn't know how DSTROOT and INSTALL_PATH options work, then here's what Xcode help says
# about them:
#
# DSTROOT:
#  "The path at which all products will be rooted when performing an install build. For instance, to install
#   your products on the system proper, set this path to `/`. Defaults to `/tmp/$(PROJECT_NAME).dst` to prevent
#   a *test* install build from accidentally overwriting valid and needed data in the ultimate install path.
#   Typically this path is not set per target, but is provided as an option on the command line when performing an
#   `xcodebuild install`. It may also be set in a build configuration in special circumstances."
#
# INSTALL_PATH:
#  "The directory in which to install the build products. This path is prepended by the DSTROOT."
#
# Starting with Sonoma, xcodebuild install (without clean) stopped replacing existing binary in the DSTROOT.

xcodebuild_cmd() {
    # when executed as part of xcode run script phase, env is populated with settings of current project
    # these headers are unwanted and may cause module import conflicts  
    unset USER_HEADER_SEARCH_PATHS
    unset HEADER_SEARCH_PATHS
    xcodebuild -target system7 -configuration Release DSTROOT="$HOME" clean install
}

if ! xcodebuild_cmd
then
    rm -rf build
    if ! xcodebuild_cmd
    then
        echo "error: s7 build failed. Please contact s7 developers."
        exit 1
    fi
fi

mkdir -p "$HOME/bin"

# copy the latest version of install and update scripts to $HOME/bin/
# so that:
#  1. we can use them even if ~/.system7 folder gets removed
#  2. we update the update system itself
#
cp install.sh "$HOME/bin/install-s7.sh"
cp uninstall.sh "$HOME/bin/uninstall-s7.sh"
cp update.sh "$HOME/bin/update-s7.sh"

# register s7 filter smudge that is used to bootstrap (automatically init) s7 repos on clone
#
git config --global filter.s7.smudge "/usr/local/bin/s7 bootstrap"
