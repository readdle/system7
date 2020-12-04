# Why custom submodules system?

We are the people of Mercurial. We would happily continue using Mercurial if Bitbucket didn’t “sunset” its support.
Unfortunately, Hg community doesn’t have any alternative hosting with the proper code review support that we need. Thus we were forced to migrate to GitHub (and Git of course).

As Hg users, we got used to the seamless and painless work with subrepos.

### How do they do it in Hg
There’re two files in the main repository – .hgsub and .hgsubstate. You add the subrepo by adding a line to the .hgsub, like this:
```
Dependencies/RDPDFKit = ssh://hg@bitbucket.org/readdle/rdpdfkit
```
When you make changes to the subrepo and want to link the main repository to the revision of a subrepo, you just make a commit in the main repository – it records all changed subrepos to the .hgsubstate. For example:
```
  dec5aae9e22cd0a07cfba3ba02fdb0e1f243e07e Dependencies/RDPDFKit
```
As each commit is bound to a branch in Hg, this also implies the branch information.
When you checkout any commit of the main repository, Hg takes care of checking out all subrepos to the state saved in .hgsubstate.

Git has the following analogs to Hg subrepos:

### Git submodules
Also known as “sobmodules”. We had had experience with this beast and had no desire to use it again.
Detached HEADs. No clue about the branch that was used by the developer who checked in the revision. No thank you. (yeah-yeah, there’s an alternative - use the latest version of a branch, but that doesn’t always work well with our set of subrepos).
Ton of manual work – subrepos are not checked out automatically.
And the cherry on top of this pie – an awful CLI interface. Constant juggling with update/init/recursive --omg-what-the-hell-does-this-key-mean. And the worst thing is – if you don’t update submodules, there’s no hint about that – project may even build. Do you know how to get the latest version of subrepos in Hg – you just checkout the necessary revision/branch of the main repository.

### Git-subrepos and git-subtree
We don’t have experience with these two, but the fact that both of them keep the full history of subrepos’ files in the main repository seems… odd… very odd…

### System 7

Neither submodules, nor subrepos/subtree appealed to us. So, inspired by the Hg subrepos, we came up with System 7.

An ideal subrepositories system we would like to use, meets the following requirements:
 - seamless checkout of subrepos when a revision/branch of the main repo is checked out
 - human-friendly CLI interface
 - no detached HEADs. The system we want must remember the branch where the subrepo commit belongs.

System 7 was born in a rush – we had like a month left for mirgation deadline.

Here're some ideas an assumptions we made, while building it.

Why separate command? What alternatives did I consider? Why Objective-C?
1. no bash scripts – bash script for such tasks is always a big pain in the ass
2. no python – I could have written in python, but I just know C better. If we have to port System 7 to other platforms, I would most likely rewrite it in python.
3. no swift. I don't like it. I don't want to rewrite this app every year. 
4. I looked for some plugin system in git – didn't find one
5. considered forking git itself. First, I had pre-vomit hiccups at the very thought of it.
   Second, too many GUIs I know, are bundling their own version of git, so my fork will be useless.
6. thus I stopped at separate command + few git hooks

I was thinking of the way to do all subrepos managing stuff almost automatic as it's done in HG.
I can automate pull, push, merge and checkout.
Hg updates subrepos automatically if one performs `hg commit` without specifying particular paths. That's not the best part of Hg subrepos. Decided that an explicit command is much easier to understand and control.

First assumption. We use s7 for de-facto centralized commercial repos that use single (GitHub) server and branch-based pull requests. We are not using forks, we are not using other kinds of remotes except 'origin'.
Thus: s7 always assumes that there's just one remote and it's named 'origin'

Second assumption: we do not play the game of naming local branches differently from remote branches, so s7 always assumes that `origin/branch-name` is tracked by local branch `branch-name`

Third assumption: there's such thing as octopus merge (one can merge more than two heads at a time).
I haven't found a way to detect and prohibit this stuff.
Custom merge driver isn't called in case of octopus (did I say I strongly hate git?).
All merge hooks can be bypassed with --no-verify, so I don't rely on them;
The only option was pre-commit hook, but I think you know the result.
One more note on octopus – I tried to merge two branches into master. Two of three brances changed
the same file (.s7substate in my experiment, but I think it doesn't really matter) – octopus strategy
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

A note about `git reset`. This beast doesn't call any hooks, so there's no chance for s7 to update
subrepos automatically. The only way to help user I came up with is to save a copy of .s7substate into
not tracked file .s7control. If actual config is not equal to the one saved in .s7control, then
we can throw a build error from our project (like cocoapods do when pods are not in sync).