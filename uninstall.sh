#!/bin/sh

rm /usr/local/bin/s7 2>/dev/null
rm /usr/local/bin/update-s7.sh 2>/dev/null
rm /usr/local/bin/install-s7.sh 2>/dev/null
rm /usr/local/bin/uninstall-s7.sh 2>/dev/null

rm "${HOME}/bin/s7" 2>/dev/null
rm "${HOME}/bin/update-s7.sh" 2>/dev/null
rm "${HOME}/bin/install-s7.sh" 2>/dev/null
rm "${HOME}/bin/uninstall-s7.sh" 2>/dev/null

rm -rf "${HOME}/.system7" 2>/dev/null
