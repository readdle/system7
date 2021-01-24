#!/bin/sh

which xcodebuild > /dev/null
if [ 0 -ne $? ]
then
    echo "error: failed to locate 'xcodebuild' command. Do you have Xcode? Run 'xcode-select -switch-path <path to Xcode.app>' (most common path to Xcode.app is '/Applications/Xcode.app'."
    exit 1
fi


#    The sad state of PATH at Mac OS
#
#    s7 was intended to be used as the CLI tool, but from the day one it became obvious that the majority of people prefer GUI tools to work with Git. This means that all s7 hooks must work from under those GUI apps. My first naive approach as the console-addicted person was,– "just add ~/bin to your PATH" (will add on why ~/bin was chosen below). Turned out that "just adding something to the PATH" is not an easy task at modern Mac OS.
#
#    .bash_profile/.zshrc – obviously don't work for GUI apps started from Finder, Dock, Spotlight or by launch services. But I personally was sometimes fooled by my love to launch Xcode using xed, or SourceTree using stree.
#
#    /etc/paths, /etc/paths.d/* – I had a vague hope this would work. No it won't. This one IS used by Terminal, but GUI doesn't consult it.
#
#    launchctl setenv PATH VALUE – doesn't work particularly for the PATH variable. Haven't found it in the documentation, but my tests tell so. It works for custom variables, like MY_TEST – launchctl setenv MY_TEST VALUE works, PATH – nah. Doesn't work even if set from ~/Library/LaunchAgents/*.plist. (NOTE: Haven't checked this, but people at Stack Overflow write that LaunchAgents-set variables don't work for apps started by reopen last open windows and for Preferencies > Users & Groups > Login Items. Might be worth checking if we need a different environment variable some day).
#
#    The only way, my teammates found, that works is to run `sudo launchctl config user path VALUE`.
#
#    I don't want users to trust me with super user rights (even just for installation) to work with s7.
#
#    Now, back to ~/bin. This is the dir where most of developer utils at Readdle would install, so I just followed the tradition. Now, I want to break this tradition.
#
#    Xcode offers to install CLI tools to /usr/local/bin by default. This gives a small hope that this directory will stay writable for common mortals in the near future, so I would definitely prefer it instead of non-canonical ~/bin. The use of /usr/local/bin doesn't free me from the need to do something about PATH and GUI apps; however, the default /etc/paths contains /usr/local/bin, so at least there's no need to modify user's PATH to make work from Terminal possible.
#
#    If you are like me, and didn't know how DSTROOT option works, then here's what Xcode help says about it:
#
#    "The path at which all products will be rooted when performing an install build. For instance, to install your products on the system proper, set this path to `/`. Defaults to `/tmp/$(PROJECT_NAME).dst` to prevent a *test* install build from accidentally overwriting valid and needed data in the ultimate install path. Typically this path is not set per target, but is provided as an option on the command line when performing an `xcodebuild install`. It may also be set in a build configuration in special circumstances."
#
#    So, to install s7 to /usr/local/bin, I would run xcodebuild this way:
#
#       xcodebuild -target system7 -configuration Release DSTROOT="/" install
#
#    Back to the original problem. s7 is 'used' by GUI apps indirectly through Git hooks, so not to fight with the PATH problem, I decided I would hardcode /usr/local/bin/s7 in the s7 hooks, so there would be no need to modify user's PATH. :tada:
#
#    If you were curious, the default PATH for GUI apps looks like this /usr/bin:/bin:/usr/sbin:/sbin. Many apps add some stuff to the PATH once they launch, for example, SourceTree adds the paths to its custom git/git-lfs, etc., Xcode adds SDK bins to the PATH. This is why, we couldn't use Hg from Xcode Run Scripts without explicitly adding /usr/local/bin to the PATH in the beginning of a script.
#

xcodebuild_cmd() {
    # when executed as part of xcode run script phase, env is populated with settings of current project
    # these headers are unwanted and may cause module import conflicts  
    unset USER_HEADER_SEARCH_PATHS
    unset HEADER_SEARCH_PATHS
    xcodebuild -target system7 -configuration Release DSTROOT="/" install
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

# copy the latest version of install and update scripts to /usr/local/bin/
# so that:
#  1. we can use them even if ~/.system7 folder gets removed
#  2. we update the update system itself
#
cp install.sh "/usr/local/bin/install-s7.sh"
cp uninstall.sh "/usr/local/bin/uninstall-s7.sh"
cp update.sh "/usr/local/bin/update-s7.sh"

# register s7 filter smudge that is used to bootstrap (automatically init) s7 repos on clone
#
git config --global filter.s7.smudge "s7 bootstrap"
