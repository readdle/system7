# System 7

System 7 is the Git submodules system for mere mortals.

You use System 7 via a CLI tool named `s7`.

Read [Why custom submodules system] to understand why we created this.

---

## Installation

Download the file https://github.com/readdle/system7/blob/master/install.sh and run it.
It will clone system7 repo to “${HOME}/.system7”, build `s7` and install to `/usr/local/bin/`.

To update s7, run `/usr/local/bin/update-s7.sh`.

---

## Using S7 by Example

Imagine we have a team of developers working on… PDF Viewer application :)
They have versions of their app for Mac and iOS. These projects live in separate repositories. Both use a cross-platform core library, named PDFKit.
Let's see how to set this up with the help of System 7.

> further through this text we will use the term subrepo to talk about submodule. We just like subrepo better than submodule


### Set up

Say Alice is setting up the environment.

First thing to do is to “install” s7 into the main repo. To do this, Alice calls `s7 init`:

```
[alice @ main-repo] $ s7 init
initialized s7 repo in '/Users/alice/projects/main-repo'
```

`s7 init` installs git-hooks necessary for s7 to automate all necessary tasks. For example: push subrepo changes when the main repo is pushed; switch subrepos to the proper revision and branches once the main repo is switched between revisions/branches, etc.

The main thing `s7 init` does, is that it creates an `.s7substate` file – the config that will contain the list of subrepos and their state.

> `s7 init` creates and changes some other files too. If you want to learn more, please, read `s7 help init`

Next, let’s add a subrepo!


### Add a subrepo

```
[alice @ main-repo] $ s7 add Dependencies/PDFKit git@github.com:example/pdfkit.git
Cloning into ‘Dependencies/PDFKit’...
remote: Enumerating objects: 62, done.
remote: Counting objects: 100% (62/62), done.
remote: …
please, don't forget to commit the .s7substate and .gitignore
```

If you look into .s7substate now, you will find our first subrepo record there:

```
Dependencies/PDFKit = { git@github.com:example/pdfkit.git, 57e14e93de8af59c29ba021d7a4a0f3bb2700a02, master }
```

You can see that `s7` has recorded:
  - relative path to the subrepo directory
  - the URL to subrepo’s remote
  - the revision of the subrepo
  - and the branch of the subrepo.

If Alice checks `git status` now, she will find that `s7` has created serveral .s7* files (.s7substate, etc.) and updated (or created) some Git config files (.gitignore, .gitattributes).
She’s ready to share her work with the team:

```
[alice @ main-repo] $ git add .s7* .gitignore .gitattributes
[alice @ main-repo] $ git commit -m”add PDFKit subrepo”
[alice @ main-repo] $ git push
```

### Starting work on an existing s7 repo

Alice has done the great work setting up the project. Now her fellow developers can start their work. Let’s see Bob do this.
Bob pulls in the latest changes from Alice.

```
[bob @ main-repo] $ git pull
```

Or, if he wants to get a fresh copy of the main-repo:

```
[bob @ projects] $ git clone git@github.com:example/main-repo.git ...
```

That's it. Bob is ready to go. He should have main-repo and PDFKit subrepo now.

> In some rare cases `s7` might not be able to automatically init s7 in a repo after clone.
> In such case you would have to run `s7 init` the first time you get a fresh clone of s7 repo.
> `s7 init` must be run just once in the lifetime of the repository copy – it will install git hooks, and create some 'system' files.


### status

### rebind

### push/pull

### merge

### Getting help

`s7 help` and `s7 help <command>`


# Здесь рыбу заворачивали


Adding subrepos
To add a subrepo, use `s7 add` command.
`s7 add [--stage] PATH [URL [BRANCH]]`
The only required argument for `s7 add` is the path where subrepo will live.
If you’ve already cloned the subrepo to that PATH, you can run just `s7 add <path>` and s7 will deduce URL and BRANCH from the subrepo Git status.
If you haven’t clone subrepo, then you must pass at least <path> and <url> parameters. s7 will clone subrepo from <url> to the <path>.
`s7 add` registers the new subrepo in `.s7substate` and `.gitignore`. These two files must be committed to share the new subrepo and its recorded state with fellow developers. `--stage` option may be used to automatically prepare these file commit with the next `git commit`.

Example:

Bob add a new subrepo:
	[main-repo] $ s7 add --stage /Dependencies/YAMLParser git@.../yaml-parser.git
	[main-repo] $ git commit -m”add yaml parser subrepo”

Alice gets Bob’s code that uses the new subrepo:
	[main-repo] $ git pull

that’s it! No need to run any special commands. s7 will checkout subrepos automatically. (NOTE: there arecases when s7 cannot do this automatically, we’ll discuss them later).


Borista suggests to draw diagrams that explain submodules to the newbys

---

## Why custom submodules system?

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
3. I looked for some plugin system in git – didn't find one
4. considered forking git itself. First, I had pre-vomit hiccups at the very thought of it.
   Second, too many GUIs I know, are bundling their own version of git, so my fork will be useless.
5. thus I stopped at separate command + few git hooks

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
   * 6667738 (HEAD -> master) merge octopus (`git merge test test2`)
   * 7ff4dca me too
   * 7221d84 up subrepos
   | * 4a9db5b (test2) up file (changed a different file at branch test2)
   |/
   | * edd53c0 (test) up subrepos
   |/
   * 4ebe9c8 <doesn't matter>
   ~

A note about `git reset`. This beast doesn't call any hooks, so there's no chance for s7 to update
subrepos automatically. The only way to help user I came up with is to save a copy of .s7substate into
not tracked file .s7control. If actual config is not equal to the one saved in .s7control, then
we can throw a build error from our project (like cocoapods do when pods are not in sync).
