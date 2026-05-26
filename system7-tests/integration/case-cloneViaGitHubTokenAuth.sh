#!/bin/sh

# Integration test for the GH_USER/GH_TOKEN PAT auth mode.
#
# What the production change does: when GH_USER and GH_TOKEN are both set,
# s7 prepends `-c url.https://USER:TOKEN@github.com/.insteadOf=git@github.com:`
# (and the ssh:// variant) to every git invocation. This rewrites SSH GitHub
# URLs to HTTPS-with-token at network-resolution time, without touching
# .s7substate or persisting the token to any cloned subrepo's .git/config.
#
# Verified here, end-to-end:
#   A. Without the env vars: no `-c url…insteadOf…` flags are injected.
#   B. With the env vars: the flags appear on every git call, and the
#      token is masked (`***`) in S7_TRACE_GIT output.
#   C. The token does not leak to any file under the cloned subrepo's .git/.
#   D. Real subrepo URLs (non-github.com) are untouched — the clone still
#      succeeds and the original URL is stored verbatim in .git/config.
#
# Note: we don't drive a real `git@github.com:` clone to a fake remote here
# because git applies `insteadOf` rules with longest-prefix matching, not
# recursively, so a two-level rewrite chain can't be expressed cleanly.
# Trace inspection plus credential-leak guards prove the s7-layer behaves
# correctly; real github.com use is exercised in CI against the real PAT.

GH_TEST_USER=testuser
GH_TEST_TOKEN=mySecretToken_xyz123


# --- Set up pastey/rd2 with one subrepo (real local URL) ---

git clone github/rd2 pastey/rd2

cd pastey/rd2

assert s7 init
assert git add .
assert git commit -m '"init s7"'

assert s7 add --stage Dependencies/ReaddleLib '"$S7_ROOT/github/ReaddleLib"'
assert git commit -m '"add ReaddleLib subrepo"'
assert git push


# --- Scenario A: env unset → no insteadOf injection ---

cd "$S7_ROOT/nik"

unset GH_USER
unset GH_TOKEN

S7_TRACE_GIT=1 git clone "$S7_ROOT/github/rd2" rd2-noauth 2> traceA.log

assert test -d rd2-noauth/Dependencies/ReaddleLib
assert ! grep -q insteadOf= traceA.log
assert ! grep -q 'url\.https://' traceA.log


# --- Scenario B: env set → flags injected, token masked ---

cd "$S7_ROOT/nik"

export GH_USER="$GH_TEST_USER"
export GH_TOKEN="$GH_TEST_TOKEN"

S7_TRACE_GIT=1 git clone "$S7_ROOT/github/rd2" rd2-auth 2> traceB.log

# Subrepo clone must still succeed — local URLs in .s7substate are unaffected
# by the github.com-only insteadOf rule.
assert test -d rd2-auth/Dependencies/ReaddleLib

# Both rewrite pairs must appear (covers `git@github.com:` and `ssh://git@github.com/`).
assert grep -q 'insteadOf=git@github.com:' traceB.log
assert grep -q 'insteadOf=ssh://git@github.com/' traceB.log

# The HTTPS-with-userinfo URL must appear with the user but with the token
# replaced by `***`.
assert grep -qF 'url.https://testuser:***@github.com/' traceB.log

# Raw token must NEVER appear in trace output.
assert ! grep -qF "$GH_TEST_TOKEN" traceB.log


# --- Scenario C: token does not land in any .git/config or .git/ file ---

assert ! grep -rq "$GH_TEST_TOKEN" rd2-auth/.git/
assert ! grep -rq "$GH_TEST_TOKEN" rd2-auth/Dependencies/ReaddleLib/.git/


# --- Scenario D: subrepo's stored origin URL is the original local path ---

SUBREPO_URL=$(git -C rd2-auth/Dependencies/ReaddleLib config remote.origin.url)
EXPECTED_URL="$S7_ROOT/github/ReaddleLib"
assert test "$SUBREPO_URL" = "$EXPECTED_URL"
