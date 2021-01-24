# Why custom submodules system?

We are the people of Mercurial. We would happily continue using Mercurial if Bitbucket didn’t _“sunset”_ its support.
Unfortunately, `hg` community doesn’t have any alternative hosting with the proper code review support that we need. Thus we were forced to migrate to GitHub (and Git of course).

As `hg` users, we got used to the seamless and painless work with subrepos.

### How do they do it in Hg
There’re two files in the main repository – `.hgsub` and `.hgsubstate`. You add the subrepo by adding a line to the `.hgsub`, like this:
```
Dependencies/RDPDFKit = ssh://hg@bitbucket.org/readdle/rdpdfkit
```
When you make changes to the subrepo and want to link the main repository to the revision of a subrepo, you just make a commit in the main repository – it records all changed subrepos to the `.hgsubstate`. For example:
```
dec5aae9e22cd0a07cfba3ba02fdb0e1f243e07e Dependencies/RDPDFKit
```
As each commit is bound to a branch in `hg`, this also implies the branch information.
When you checkout any commit of the main repository, `hg` takes care of checking out all subrepos to the state saved in `.hgsubstate`.

Git has the following analogs of Mercurial subrepos:

### Git submodules
Also known as “sobmodules”. We had had experience with this beast and had no desire to use it again.
Detached HEADs. No clue about the branch that was used by the developer who checked in the revision. No thank you. (yeah-yeah, there’s an alternative - use the latest version of a branch, but that doesn’t always work well with our set of subrepos).
Ton of manual work – subrepos are not checked out automatically.
And the cherry on top of this pie – an awful CLI interface. Constant juggling with update/init/recursive --omg-what-the-hell-does-this-key-mean. And the worst thing is – if you don’t update submodules, there’s no hint about that – project may even build.

### Git-subrepos and git-subtree
We don’t have experience with these two, but the fact that both of them keep the full history of subrepos’ files in the main repository seems… odd… very odd…

### System 7

Neither submodules, nor subrepos/subtree appealed to us. So, inspired by the Hg subrepos, we came up with System 7.

An ideal subrepositories system we would like to use, meets the following requirements:
 - seamless checkout of subrepos when a revision/branch of the main repo is checked out
 - human-friendly CLI interface
 - no detached HEADs. The system we want must remember the branch where the subrepo commit belongs.

System 7 was born in a rush – we had like a month left for migration deadline.

Here're some ideas an assumptions we made, while building it.

Why separate command? What alternatives did I consider? Why Objective-C?
1. No shell scripts – shell script for such tasks is always a big pain in the ass
2. No Python – I could have written in python, but I just know C better. If we have to port System 7 to other platforms, I would most likely rewrite it in python.
3. No Swift. I don't like it. I don't want to rewrite this app every year as the language "evaluates".
4. I looked for some plugin system in Git – didn't find one.
5. Considered forking Git itself. Too many GUIs I know, are bundling their own version of `git`, so my fork will be useless.
6. Thus I stopped at separate command + few Git hooks.

I was thinking of the way to do all subrepos managing stuff almost automatic as it's done in `hg`.
I can automate pull, push, merge and checkout.
Hg updates subrepos automatically if one performs `hg commit` without specifying particular paths. That's not the best part of Mercurial subrepos. Decided that an explicit command is much easier to understand and control.

#### Some assumptions we made while building System 7

System 7 follows the philosophy of subrepos/submodules. We do not claim that this is the only possible way to organize your project dependencies. Some people like monorepo, some like Carthage, some Cocoapods, etc. One can actually use all of the above in a single project. Everyone chooses what's best for them and every approach has its pros and cons.

We use `s7` for de-facto centralized commercial repos that use single (GitHub) server and branch-based pull requests. We are not using forks for our private repos, we are not using other kinds of remotes except `origin`.
Thus: `s7` always assumes that there's just one remote and it's named `origin`

We do not play the game of naming local branches differently from remote branches, so `s7` always assumes that `origin/branch-name` is tracked by local branch `branch-name`

As `s7` had been developed under the pressure of the deadline, we had no time to make it cross-platform. To be honest, I don't think we would ever develop `s7` if there was no pressure of an urgent migration to Git. As our team develops at Mac OS, `s7` is the Mac-only. 

There's such thing as octopus merge (one can merge more than two heads at a time).
I haven't found a way to detect and prohibit this stuff.
Custom merge driver isn't called in case of octopus.
All merge hooks can be bypassed with `--no-verify`, so I don't rely on them;
The only option was pre-commit hook, but I think you know the result.
One more note on octopus – I tried to merge two branches into master. Two of three branches changed
the same file (`.s7substate` in my experiment, but I think it doesn't really matter) – octopus strategy
failed and fell back to the default merge of... I don't know what – the result was like I didn't merge
anything, but the file had a conflict :joy:
The result looked like this:
```
   * 6667738 (HEAD -> master) merge octopus (`git merge test test2`)
   * 7ff4dca me too
   * 7221d84 up subrepos
   | * 4a9db5b (test2) up file (changed a different file at branch test2)
   |/
   | * edd53c0 (test) up subrepos
   |/
   * 4ebe9c8 <doesn't matter>
   ~
```

A note about `git reset`. This beast doesn't call any hooks, so there's no chance for `s7` to update
subrepos automatically. The only way to help user I came up with is to save a copy of `.s7substate` into
not tracked file `.s7control`. If actual config is not equal to the one saved in `.s7control`, then
we can throw a build error from our project (like cocoapods do when pods are not in sync).
